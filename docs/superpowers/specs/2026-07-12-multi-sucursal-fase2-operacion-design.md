# Multi-sucursal — Fase 2: Operación diaria por sucursal (mesas, caja, ventas, inventario)

## Contexto

La Fase 1 (`docs/superpowers/specs/2026-07-11-multi-sucursal-fase1-nucleo-design.md`)
dejó el núcleo listo: tabla `sucursales`, usuarios asociados a una o varias,
y la sesión (JWT) sabe en qué sucursal está operando cada quien
(`req.usuario.sucursal_id` / `req.usuario.acceso_todas`). Ningún módulo
operativo filtraba todavía por sucursal.

Esta fase hace que cada sucursal maneje de forma independiente sus mesas,
su caja, sus ventas y su inventario — como si fuera una cadena real de
restaurantes, cada local con su propio salón y su propio stock.

Quedan fuera de esta fase:
- Reportes consolidados/comparativos entre sucursales (eso es la Fase 4;
  aquí solo se garantiza que los reportes existentes no filtren datos de
  otras sucursales).
- Catálogo de productos por sucursal (precios/menú distintos por local) —
  el menú sigue siendo compartido; solo el stock se separa.
- Un selector de sucursal "en caliente" para el modo consolidado — ya
  decidido en la Fase 1 que no existe.

## Decisiones de alcance

- **Filtrado por denormalización**: se agrega `sucursal_id` directamente a
  las tablas operativas (`areas`, `sesiones_caja`, `pedidos`, `compras`,
  `registros_inventario`) en vez de derivarlo por joins en cada consulta.
  Las `mesas` heredan la sucursal de su `area_id` (sin columna propia).
- **Modo "Todas las sucursales" es de solo lectura para lo operativo**: un
  usuario con `acceso_todas_sucursales` que eligió "Todas" al iniciar
  sesión (`sucursal_id: null`) puede **ver** todo sin filtrar, pero
  cualquier acción de escritura operativa (crear/editar mesa o área, abrir
  caja, crear o cobrar un pedido, registrar una compra, mover inventario
  manualmente) responde `403` pidiendo que inicie sesión en una sucursal
  específica. No hay selector de sucursal en los formularios de estas
  acciones.
- **El catálogo de productos sigue siendo compartido** entre todas las
  sucursales (mismo nombre, precio, categoría, foto). Únicamente la
  **cantidad en stock** se separa por sucursal.
- **Las compras son por sucursal**: cada compra registrada pertenece a la
  sucursal del usuario que la crea, y al recibirla el stock entra
  únicamente al inventario de esa sucursal.
- **Socket.io por sucursal**: los eventos en tiempo real (actualización de
  pedidos, impresión de caja/cocina) se emiten solo a la sala de la
  sucursal correspondiente, para que el agente de impresión de una
  sucursal no reciba ni imprima tickets de otra.

## Modelo de datos

Nueva migración `backend/database/migrations/013_sucursal_operativa.sql`
(solo esquema, sin datos — igual que la Fase 1; los datos van en
`seed.js`):

```sql
ALTER TABLE areas
  ADD COLUMN sucursal_id INT UNSIGNED NOT NULL AFTER id,
  ADD FOREIGN KEY (sucursal_id) REFERENCES sucursales(id);

ALTER TABLE sesiones_caja
  ADD COLUMN sucursal_id INT UNSIGNED NOT NULL AFTER usuario_id,
  ADD FOREIGN KEY (sucursal_id) REFERENCES sucursales(id);

ALTER TABLE pedidos
  ADD COLUMN sucursal_id INT UNSIGNED NOT NULL AFTER id,
  ADD FOREIGN KEY (sucursal_id) REFERENCES sucursales(id);

ALTER TABLE compras
  ADD COLUMN sucursal_id INT UNSIGNED NOT NULL AFTER id,
  ADD FOREIGN KEY (sucursal_id) REFERENCES sucursales(id);

ALTER TABLE registros_inventario
  ADD COLUMN sucursal_id INT UNSIGNED NOT NULL AFTER producto_id,
  ADD FOREIGN KEY (sucursal_id) REFERENCES sucursales(id);

CREATE TABLE IF NOT EXISTS producto_stock_sucursal (
  producto_id INT UNSIGNED NOT NULL,
  sucursal_id INT UNSIGNED NOT NULL,
  stock INT NOT NULL DEFAULT 0,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (producto_id, sucursal_id),
  FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE CASCADE,
  FOREIGN KEY (sucursal_id) REFERENCES sucursales(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

`productos.stock` no se elimina: para productos que trackean inventario
(`stock IS NOT NULL`) pasa a representar el **total sumado entre todas las
sucursales**, recalculado automáticamente cada vez que cambia una fila de
`producto_stock_sucursal`. Para productos que no trackean inventario sigue
siendo `NULL`, igual que hoy.

### Backfill en `seed.js` (idempotente, mismo patrón que la Fase 1)

- Todas las `areas` existentes → `sucursal_id` de "Sucursal Principal".
- Todas las `sesiones_caja` y `pedidos` existentes → `sucursal_id` de
  "Sucursal Principal".
- Todas las `compras` existentes → `sucursal_id` de "Sucursal Principal".
- Todos los `registros_inventario` existentes → `sucursal_id` de
  "Sucursal Principal".
- Para cada producto con `stock IS NOT NULL`: crear una fila en
  `producto_stock_sucursal` con `sucursal_id` de "Sucursal Principal" y
  `stock` igual al valor actual de `productos.stock`. Nadie pierde
  inventario al desplegar este cambio.

## Backend — scoping y validación

### Patrón general

Los controllers ya extraen datos de `req.usuario` para pasarlos a los
services (como ya hacen con `usuario_id`); se agrega lo mismo con
`sucursal_id` y `acceso_todas`:

- **Lecturas** (listados de mesas, áreas, sesiones de caja, pedidos,
  compras, movimientos de inventario): si `acceso_todas` es `false`, se
  agrega `WHERE sucursal_id = req.usuario.sucursal_id`. Si es `true`, no
  se filtra.
- **Escrituras** (crear/editar mesa o área, abrir caja, crear o cobrar un
  pedido, registrar/recibir una compra, mover inventario manualmente):
  si `req.usuario.sucursal_id` es `null` (modo "Todas"), la petición
  responde `403` con `{ ok: false, mensaje: 'Debes iniciar sesión en una
  sucursal específica para realizar esta acción' }` antes de tocar la
  base de datos.

### Módulo por módulo

- **`areas`/`mesas`**: `crearArea` toma `sucursal_id` de
  `req.usuario.sucursal_id` (nunca del body — no se puede crear un área
  "para otra sucursal"). `crearMesa` valida que el `area_id` recibido
  pertenezca a la sucursal del usuario (404 si no).
- **`caja`**: `abrir()` graba `sucursal_id` en la sesión. `obtenerActiva`
  (la validación de "ya tienes una caja abierta") pasa a ser por
  `usuario_id` **y** `sucursal_id` — un usuario con varias sucursales
  puede tener como máximo una caja abierta por sucursal.
- **`ventas`**: `crear()`/`crearCompleta()` copian `sucursal_id` desde la
  sesión de caja activa (`sesion_caja_id`) al crear el pedido — nunca del
  body. `listar()`/`listarCocina()` filtran por sucursal salvo modo
  "Todas". El descuento de stock al vender usa `ajustarStockSucursal`
  (ver más abajo) contra la sucursal del pedido.
- **`compras`**: `crearCompra` toma `sucursal_id` de
  `req.usuario.sucursal_id`. `listarCompras` filtra por sucursal salvo
  modo "Todas". `recibirCompra` aplica el ingreso de stock vía
  `ajustarStockSucursal` contra la sucursal de la compra.
- **`inventario`**: `entrada`/`salida`/`ajuste` toman `sucursal_id` de
  `req.usuario.sucursal_id` y operan vía `ajustarStockSucursal`.
  `listar`/`listarPorProducto` filtran por sucursal salvo modo "Todas".
- **`productos`**: el CRUD del catálogo (nombre, precio, categoría, foto)
  no cambia — sigue siendo compartido y **no** requiere una sucursal
  activa concreta (crear/editar un producto funciona igual en modo
  "Todas"). Si al crear un producto se especifica un stock inicial, ese
  stock se asigna a la sucursal del usuario que lo crea (vía
  `ajustarStockSucursal`) en vez de escribir directo en `productos.stock`;
  si el usuario está en modo "Todas" al crear el producto, el stock
  inicial se ignora (el producto queda creado con 0 en todas las
  sucursales) y debe cargarse después con una entrada de inventario desde
  una sucursal específica.
- **`reportes`**: el reporte `ventas` (consulta `Pedido`) y el reporte
  `inventario` (consulta `RegistroInventario`) se filtran por
  `sucursal_id` salvo modo "Todas" — para que un cajero de la Sucursal B
  no vea datos de la Sucursal A en sus propios reportes. Esto es
  únicamente evitar la fuga de datos entre sucursales; la vista
  comparativa/consolidada real es objetivo de la Fase 4.

### Lógica de stock centralizada

Hoy `ventas.service.js`, `compras.service.js` e `inventario.service.js`
duplican, cada uno por su cuenta, la lógica de sumar/restar
`productos.stock` y crear un `RegistroInventario`. Se centraliza en una
función nueva, `ajustarStockSucursal(producto_id, sucursal_id, tipo,
cantidad, usuario_id, nota)` (ubicación: `backend/src/modules/inventario/
stock.service.js`, reutilizada por los tres módulos):

1. `findOrCreate` de la fila `producto_stock_sucursal(producto_id,
   sucursal_id)` con `stock: 0` por defecto.
2. Aplica el movimiento (`entrada`/`compra` suman, `salida`/`venta`
   restan con validación de stock suficiente, `ajuste` fija el valor
   absoluto) — misma semántica que la función `_movimiento` actual de
   `inventario.service.js`.
3. Recalcula `productos.stock` = `SUM(stock)` de todas las filas de ese
   producto en `producto_stock_sucursal`, y actualiza la columna.
4. Crea el `RegistroInventario` con el nuevo campo `sucursal_id`.

## Socket.io por sucursal

- `backend/src/socket.js`: `emitir(evento, datos, sucursal_id)` — si se
  pasa `sucursal_id`, emite solo a la sala `sucursal:<id>`
  (`_io.to('sucursal:' + sucursal_id).emit(evento, datos)`); si se omite,
  mantiene el broadcast global (para eventos que no dependan de
  sucursal, si los hubiera). Nuevo handler de conexión:
  `socket.on('unirse_sucursal', (sucursal_id) => socket.join('sucursal:'
  + sucursal_id))`.
- Todos los `emitir(...)` de `ventas.service.js`
  (`restaurante:actualizar`, `print:caja`, `print:cocina`) pasan a
  incluir el `sucursal_id` del pedido correspondiente.
- **Frontend** (`frontend/src/socket.js`): tras el login (y al recargar
  con sesión ya activa), si `usuario.sucursal_activa.id` no es `null`, se
  emite `unirse_sucursal` con ese id. En modo "Todas" no se une a ninguna
  sala — no hay notificaciones en vivo de pedidos en este modo (es de
  solo lectura, consistente con el resto de esta fase).
- **`print-agent/config.json`**: se agrega un campo `sucursal_id` (una
  instalación física del agente por sucursal, cada una con su propio
  `config.json`). `print-agent/agent.js` emite `unirse_sucursal` al
  conectar. Así el agente de la Sucursal B deja de recibir tickets de la
  Sucursal A.

## Frontend

El filtrado ya lo hace el backend, así que la mayoría de páginas (mesas,
caja, ventas, productos, inventario, compras) no cambian su lógica de
datos — simplemente reciben menos filas porque la API ya viene filtrada.
Cambios puntuales:

- **`frontend/src/socket.js`**: une la sala de sucursal tras el login,
  como se describe arriba.
- **Páginas de mesas/áreas, caja, ventas, compras, inventario**: en modo
  "Todas las sucursales", las acciones de escritura muestran el mensaje
  de error `403` que ya devuelve el backend — no se construye UI nueva
  para bloquear proactivamente los botones (el error del backend ya
  cubre el caso; simplifica el frontend en esta fase).
- **`ProductosPage`/inventario**: donde hoy se muestra un solo "Stock:
  N", pasa a mostrar el stock de la sucursal activa del usuario. En modo
  "Todas las sucursales", se muestra el desglose por sucursal (tabla
  simple: sucursal → cantidad) en vez de un solo número.
- **Compras**: el formulario de nueva compra ya no pide elegir sucursal —
  se usa automáticamente la del usuario autenticado.

## Fuera de alcance (fases futuras)

- Reportes comparativos/consolidados de la cadena completa (Fase 4).
- Menú o precios distintos por sucursal.
- Selector de sucursal "en caliente" sin cerrar sesión.
- Transferencias de stock entre sucursales (por ahora, mover stock de una
  sucursal a otra requiere un ajuste manual de salida en una y entrada en
  la otra).
