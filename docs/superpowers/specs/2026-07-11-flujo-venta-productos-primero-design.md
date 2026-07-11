# Diseño: nuevo flujo de venta (productos → mesa → cobro)

Fecha: 2026-07-11

## Contexto y problema

Hoy el flujo de venta en el POS es: **elegir mesa → agregar productos → cobrar**.
Al tocar una mesa disponible se crea el pedido inmediatamente con `mesa_id` asignado
y la mesa pasa a `ocupada`, antes de que exista ningún producto en el carrito.

El negocio quiere invertir el orden: **elegir productos → elegir mesa (o "para
llevar") → cobrar (efectivo o QR)**. Además:

- El orden de productos por más vendido (`order_by: 'mas_vendido'`) ya existe y
  debe seguir funcionando igual, sin tocarlo.
- Al cobrar, la mesa debe liberarse de inmediato (volver a `disponible`), no se
  espera a que los clientes terminen de comer.
- Se aprovecha para cerrar dos gaps detectados al revisar la base de datos de
  producción:
  - El stock puede quedar negativo hoy porque `cobrar()` no valida existencias.
  - La configuración `configuraciones.flujo_cocina` (`fisico`/`digital`) existe
    en la base y en el frontend de Configuración, pero no cambia ningún
    comportamiento real: hoy siempre se emite `print:cocina` al cobrar. Debe
    imprimir ticket físico en cocina solo cuando el modo es `fisico`.

## Flujo resultante

```
[Nuevo pedido] -> Paso 1: elegir productos (sin mesa aún)
                -> Paso 2: elegir mesa o "Para llevar"
                -> Paso 3: revisar carrito y cobrar (efectivo/QR)
                   -> al cobrar: valida stock, decrementa stock,
                      libera la mesa, imprime ticket de caja,
                      imprime ticket de cocina solo si flujo_cocina='fisico'
```

La pantalla de mesas ya no crea pedidos al tocar una mesa disponible; solo se
usa para retomar pedidos ya en curso (mesa `ocupada`).

## Backend (`backend/src/modules/ventas`)

### Migración de esquema (nuevo archivo SQL en `bd/`, mismo estilo que `migracion_llevar.sql`)

- `pedidos.estado` ENUM gana el valor `'armando'`:
  `('armando','pendiente','listo','completado','cancelado')`.
- `pedidos.tipo` pasa a ser NULLABLE (hoy `NOT NULL DEFAULT 'mesa'`), porque
  durante el armado del carrito todavía no se sabe si es mesa o para llevar.

### Endpoints nuevos / modificados

**`POST /ventas/borrador`** (nuevo)
- Body: `{ producto_id, cantidad, nota? }` (primer producto del carrito).
- Crea un `Pedido` con `estado: 'armando'`, `tipo: null`, `mesa_id: null`, y su
  primer `DetallePedido`.
- Devuelve el pedido con el mismo shape que `obtener()`.
- Permiso: `ventas.crear` (igual que hoy).

**`POST /ventas/:id/items`, `PUT/DELETE /ventas/:id/items/:item_id`** (sin cambios)
- Se reutilizan tal cual para agregar/editar/quitar productos mientras el
  pedido está en `armando` (no validan mesa/tipo hoy, así que funcionan sin
  modificación).

**`PATCH /ventas/:id/asignar`** (nuevo)
- Body: `{ tipo: 'mesa', mesa_id }` o `{ tipo: 'llevar', nombre_cliente }`.
- Valida:
  - `pedido.estado === 'armando'` (409 si no).
  - El pedido tiene al menos un `detalle_pedido` (409 "El pedido no tiene
    productos").
  - Si `tipo === 'mesa'`: la mesa sigue `disponible` (409 "Mesa ya ocupada" si
    no — protege contra dos cajeros tocando la misma mesa a la vez); la marca
    `ocupada`.
  - Si `tipo === 'llevar'`: asigna `numero_llevar` autoincremental y
    `nombre_cliente`, igual que hoy en `crear()`.
- Efecto: `pedido.tipo`/`mesa_id` (o `numero_llevar`) quedan asignados y
  `pedido.estado` pasa a `'pendiente'` — con esto el pedido se vuelve visible
  en la pantalla de cocina (`listarCocina` ya filtra por
  `estado IN ('pendiente','listo')`, no se toca esa función).
- Emite `restaurante:actualizar` para refrescar mesas y cocina en tiempo real.

**`POST /ventas/:id/cobrar`** (existente, se modifica)
- **Nuevo:** antes de decrementar stock, valida por cada `detalle_pedido` que
  `producto.stock >= detalle.cantidad`; si algún producto no alcanza, aborta
  la transacción con 409 `"Stock insuficiente: <nombre_producto>"` (mismo
  patrón que ya usa `inventario.service.js` para salidas manuales).
- **Nuevo:** si `pedido.tipo === 'mesa'`, dentro de la misma transacción libera
  la mesa (`mesa.estado = 'disponible'`).
- **Nuevo:** lee `configuraciones` (clave `flujo_cocina`) y solo emite
  `print:cocina` si el valor es `'fisico'`. `print:caja` se sigue emitiendo
  siempre.
- El resto del comportamiento (marca `estado: 'completado'`, guarda
  `metodo_pago`, `monto_recibido`, `cambio`) no cambia.

**`DELETE /ventas/:id`** (nuevo)
- Permitido solo si `pedido.estado === 'armando'`.
- Borra el pedido y sus detalles (cascade ya existe por FK). Usado por el
  botón "Cancelar" en los pasos 1 y 2 del frontend, para no dejar pedidos
  huérfanos en `armando` si el cajero se arrepiente antes de asignar mesa.

### Fuera de alcance (no se toca)

- `listarCocina()`, `marcarListo()`, `cancelar()` (para pedidos ya
  `pendiente`/`listo`) siguen igual.
- El orden `mas_vendido` en `productos.service.js` no se modifica.

## Frontend (`frontend/src/pages/ventas`)

**`VentasPage.jsx`** (pantalla de inicio, se simplifica)
- Botón grande "Nuevo pedido" arriba → navega a `/ventas/nuevo`.
- Debajo, el grid de mesas: las `disponible` quedan deshabilitadas/atenuadas
  (ya no crean pedido al tocarlas); solo las `ocupada` son clicables y abren
  `PedidoPage` para seguir un pedido ya asignado a mesa.
- Se quita de esta pantalla el botón viejo "Para llevar" (ahora vive en el
  paso 2) y el flujo de creación de pedido al tocar una mesa disponible.

**`SeleccionProductosPage.jsx`** (nueva, ruta `/ventas/nuevo`) — Paso 1
- Reutiliza el grid de productos que ya existe en `PedidoPage.jsx` (con el
  orden `mas_vendido` intacto).
- Estado local `pedidoId` (null hasta el primer producto tocado).
- Primer producto tocado → `POST /ventas/borrador`, guarda el `pedidoId`
  devuelto.
- Productos siguientes → reutilizan las mutations existentes
  `agregarItem`/`actualizarItem`. Esta lógica se extrae de `PedidoPage.jsx` a
  un hook compartido `useCarritoPedido(pedidoId)` para no duplicar código.
- Resumen del carrito (cantidad de items, total) y botón "Continuar"
  (deshabilitado si el carrito está vacío) → navega a
  `/ventas/nuevo/:pedidoId/mesa`.
- Botón "Cancelar" → si `pedidoId` existe, llama `DELETE /ventas/:id` y
  vuelve a `VentasPage`.

**`SeleccionMesaPage.jsx`** (nueva, ruta `/ventas/nuevo/:pedidoId/mesa`) — Paso 2
- Reutiliza `TarjetaMesa` y el grid de mesas (aquí las `disponible` son las
  clicables).
- Botón "Para llevar" arriba, reutiliza `ModalLlevar` (pide nombre de
  cliente).
- Al elegir mesa o confirmar "para llevar" → `PATCH /ventas/:pedidoId/asignar`
  → navega a `PedidoPage` (paso 3, sin cambios).
- Botón "Cancelar" (mismo `DELETE /ventas/:id`).

**`PedidoPage.jsx`** (paso 3) — sin cambios funcionales. Sigue siendo la
pantalla de carrito + cobro (`ModalCobrar`) que ya funciona hoy; ahora se
llega a ella con el pedido ya teniendo items y mesa/tipo asignados.

## Manejo de errores / casos borde

- Mesa tomada entre que se muestra el grid y se confirma → 409 desde
  `asignar`, el frontend muestra el error y refresca el grid de mesas.
- Stock insuficiente al cobrar → 409 con el nombre del producto, el frontend
  lo muestra como toast/error y no permite cerrar la venta.
- Pedido `armando` abandonado (el cajero cierra la pestaña sin cancelar)
  queda huérfano en la base en estado `armando`; no se implementa limpieza
  automática en este trabajo (fuera de alcance, se puede resolver después con
  un job si se vuelve un problema real).
- Cancelar en paso 1 antes de tocar ningún producto no llama a la API (no
  existe `pedidoId` aún).

## Testing

- Backend: tests con Jest/Supertest (ya existen para `ventas`) cubriendo:
  `POST /ventas/borrador`, `PATCH /ventas/:id/asignar` (casos mesa ocupada,
  pedido vacío, tipo llevar), `POST /ventas/:id/cobrar` (stock insuficiente,
  libera mesa, respeta `flujo_cocina`), `DELETE /ventas/:id` (solo en
  `armando`).
- Frontend: verificación manual del flujo completo en el navegador (crear
  pedido → elegir productos → elegir mesa → cobrar efectivo y QR) más
  revisión de que la pantalla de cocina siga recibiendo los pedidos en el
  momento correcto.
