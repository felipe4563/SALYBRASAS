# Diseño: pantalla única de venta (productos + mesa + cobro)

Fecha: 2026-07-11

> Este documento **reemplaza** a
> `2026-07-11-flujo-venta-productos-primero-design.md`. Ese diseño anterior
> (flujo en 3 pantallas: productos → mesa → cobro, con un estado intermedio
> `'armando'` en el backend) fue implementado parcialmente pero se descarta
> a favor de este enfoque más simple, pedido explícitamente por el negocio
> para agilizar los pasos de venta. El trabajo de esa sesión anterior se
> revierte (ver sección "Reversión" más abajo).

## Contexto y problema

El negocio quiere agilizar la venta al máximo: **una sola pantalla** donde
se eligen productos, se elige la mesa (o "para llevar"), y se cobra —
sin navegar entre pantallas ni pasos intermedios. No hay pantalla de cocina
en uso por ahora, así que no hace falta que el pedido pase por un estado
intermedio de "pendiente esperando cocina": se cobra y queda cerrado en el
mismo momento.

## Flujo resultante

```
[Ventas] -> Grid de productos (carrito local, sin llamadas al backend)
         -> Elegir mesa disponible O "Para llevar" (selección local)
         -> "Cobrar" (habilitado con >=1 producto y mesa/llevar elegidos)
            -> 1 sola llamada atómica al backend:
               valida stock, crea el pedido YA completado y pagado,
               descuenta stock, registra caja, imprime ticket(s)
```

Las mesas ocupadas (con un pedido en curso de antes de este cambio, o
reservadas) se muestran pero no se pueden elegir para un pedido nuevo.

## Backend (`backend/src/modules/ventas`)

### Endpoint nuevo: `POST /ventas/completa`

Body:
```json
{
  "tipo": "mesa | llevar",
  "mesa_id": 10,
  "nombre_cliente": "Público General",
  "items": [{ "producto_id": 1, "cantidad": 2, "nota": null }],
  "metodo_pago": "efectivo | qr",
  "monto_recibido": 20,
  "sesion_caja_id": 20
}
```

Función `crearCompleta(datos)` en `ventas.service.js`, en una sola
`sequelize.transaction`:

1. Valida `sesion_caja_id` presente y con `estado: 'abierta'` (mismo check
   que ya existe en `crear()`).
2. Valida `items` no vacío (409 "El pedido no tiene productos").
3. Cada `producto_id` existe, está `activo` y `es_vendible` (404/409 igual
   que `agregarItem` hoy).
4. Si `tipo === 'mesa'`: la mesa existe y está `disponible` (409 "Mesa ya
   ocupada" si no). Si `tipo === 'llevar'`: genera `numero_llevar` con
   `_siguienteNumeroLlevar()` (ya existe, sin cambios).
5. Calcula el total sumando `cantidad * precio` de cada item (precio tomado
   del producto en ese momento, igual que `agregarItem`).
6. Valida stock suficiente para cada producto (mismo criterio que ya se
   agregó a `cobrar()`: `producto.stock >= cantidad`, si no 409 "Stock
   insuficiente: <nombre>").
7. Valida `monto_recibido` si `metodo_pago === 'efectivo'` (igual que
   `cobrar()` hoy: debe alcanzar el total).
8. Dentro de la transacción:
   - Crea el `Pedido` con `estado: 'completado'`, `tipo`, `mesa_id` (o
     `numero_llevar` si es llevar), `metodo_pago`, `monto_recibido`,
     `cambio`, `nombre_cliente`, `sesion_caja_id`, `usuario_id`.
   - Crea un `DetallePedido` por cada item.
   - La mesa **no se marca `ocupada` en ningún momento** — el pedido queda
     asociado a `mesa_id` para historial/reportes, pero la mesa sigue
     `disponible` todo el tiempo (se libera "al instante", según lo pedido).
   - Decrementa `producto.stock` y crea `RegistroInventario` (`tipo:
     'venta'`) por cada item.
   - Crea `LibroCaja` (`tipo: 'ingreso'`, concepto `Venta #<id>`).
   - Incrementa `SesionCaja.total_ventas`.
9. Fuera de la transacción (igual que hoy en `cobrar()`): arma `cfg` desde
   `Configuracion` (incluye `flujo_cocina`), calcula `numero_orden_diario`,
   emite `print:caja` siempre y `print:cocina` solo si
   `cfg.flujo_cocina === 'fisico'`.
10. Devuelve el pedido completo (mismo shape que `obtener()`).

Ruta: `router.post('/completa', verificarPermiso('ventas', 'crear'),
ctrl.crearCompleta);`

### Sin cambios

- `listarCocina`, `marcarListo`, `cancelar` (para pedidos existentes con
  `estado: 'pendiente'`), `crear`, `agregarItem`, `actualizarItem`,
  `eliminarItem`, `cobrar` — se dejan tal cual quedaron después de la
  sesión anterior (con la validación de stock y el gating de
  `flujo_cocina` que ya se agregaron a `cobrar()`, porque ese endpoint
  sigue existiendo para el caso de `PedidoPage.jsx`).
- El orden `mas_vendido` en `productos.service.js` no se toca.

### Reversión del trabajo de la sesión anterior

1. **Migración inversa** (nuevo archivo SQL en `bd/`, ej.
   `bd/reversion_flujo_armando.sql`):
   ```sql
   ALTER TABLE `pedidos`
     MODIFY COLUMN `estado` ENUM('pendiente','listo','completado','cancelado') NOT NULL DEFAULT 'pendiente',
     MODIFY COLUMN `tipo` ENUM('mesa','llevar') NOT NULL DEFAULT 'mesa';
   ```
   (Antes de correrla, verificar que no quede ningún pedido en
   `estado='armando'` o `tipo IS NULL` — si existiera alguno huérfano de
   pruebas, borrarlo primero.)
2. Revertir `backend/src/models/Pedido.js`: `tipo` vuelve a
   `allowNull` por defecto (sin `allowNull: true` explícito) con
   `defaultValue: 'mesa'`, `estado` vuelve al ENUM de 4 valores.
3. Quitar de `ventas.service.js`: `iniciarBorrador`, `asignar`,
   `cancelarBorrador`, y los cambios en `agregarItem`/`eliminarItem` que
   aceptaban `'armando'` (vuelven a exigir `'pendiente'` únicamente).
4. Quitar de `ventas.controller.js`: `iniciarBorrador`, `asignar`,
   `eliminarBorrador`.
5. Quitar de `ventas.routes.js`: las rutas `POST /borrador`, `PATCH
   /:id/asignar`, `DELETE /:id`.
6. Quitar de `backend/tests/ventas.test.js` los tests 401 de esas tres
   rutas.

## Frontend (`frontend/src/pages/ventas`)

### `VentasPage.jsx` (reescritura completa)

- Estado local: `carrito` (array de `{producto_id, nombre, precio, cantidad, nota}`),
  `mesaSeleccionada` (id o null), `modoLlevar` (bool + nombre cliente),
  `modalCobrar` (bool).
- Grid de productos (reutiliza el patrón de `PedidoPage.jsx`: categorías +
  `order_by: 'mas_vendido'`, imágenes). Tocar un producto
  suma/incrementa en `carrito` (estado local, sin llamadas al backend).
- Panel de mesas (reutiliza `TarjetaMesa`): mesas `disponible` son
  clicables y seleccionan `mesaSeleccionada` (deseleccionando "para
  llevar" si estaba activo, y viceversa); mesas `ocupada`/`reservada` se
  muestran pero no son clicables para este flujo.
- Botón "Para llevar" (reutiliza `ModalLlevar`) activa `modoLlevar` con el
  nombre del cliente (deseleccionando `mesaSeleccionada`).
- Botón "Cobrar" habilitado cuando `carrito.length > 0` y
  (`mesaSeleccionada` o `modoLlevar`). Abre `ModalCobrar` (adaptado del de
  `PedidoPage.jsx`) que arma el body de `POST /ventas/completa` con el
  carrito completo + mesa/llevar + método de pago, y al confirmar limpia
  todo el estado local y refresca `mesas`/`ventas`.

### Páginas y rutas que se eliminan

- `frontend/src/pages/ventas/SeleccionProductosPage.jsx`
- `frontend/src/pages/ventas/SeleccionMesaPage.jsx`
- Rutas `/ventas/nuevo` y `/ventas/nuevo/:pedidoId/mesa` en
  `frontend/src/router/index.jsx`.

### Sin cambios

- `PedidoPage.jsx` (ruta `/ventas/pedido/:id`) queda igual, para los casos
  en que se necesite ver/cancelar un pedido puntual por su id directo (ya
  no se llega ahí desde el grid de mesas para pedidos nuevos, porque las
  mesas ya no quedan "ocupadas").
- En `frontend/src/api/ventas.js` se eliminan `iniciarBorrador`,
  `asignarPedido`, `eliminarPedido` (correspondían a los endpoints
  revertidos) y se agrega `crearVentaCompleta(datos)`.

## Manejo de errores / casos borde

- Mesa tomada justo antes de cobrar → 409 desde `crearCompleta`, el
  frontend muestra el error sin perder el carrito local (el cajero puede
  elegir otra mesa y reintentar).
- Stock insuficiente al cobrar → 409 con el nombre del producto; no se
  pierde el carrito, se puede ajustar cantidades y reintentar.
- Sin caja abierta → el botón "Cobrar" ni siquiera se muestra (mismo
  patrón que ya existe hoy en `VentasPage`).
- Cerrar/recargar la pestaña con productos en el carrito sin cobrar: se
  pierde el carrito local (aceptado, es el trade-off de un carrito 100%
  cliente; no se persiste nada hasta cobrar).

## Testing

- Backend: test 401 (patrón existente) para `POST /ventas/completa`.
  Los tests 401 de `/borrador`, `/asignar`, `DELETE /:id` se eliminan.
- Verificación manual del flujo completo, con mucho cuidado porque la
  base de datos usada en desarrollo es la que opera el restaurante en
  vivo: usar cantidades/mesas de prueba mínimas y revertir cualquier
  mutación de prueba inmediatamente después (como se hizo en la sesión
  anterior), o —mejor— pedir al usuario que verifique él mismo en un
  momento de baja actividad.
