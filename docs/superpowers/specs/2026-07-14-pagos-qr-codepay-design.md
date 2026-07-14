# Diseño: Integración de pagos QR con CodePay

## Contexto

Hoy `metodo_pago='qr'` en una venta es solo una etiqueta manual: el cajero
marca que cobró por QR/transferencia externa y el pedido se completa al
instante, sin ninguna verificación real de que el cliente pagó. Esta fase
reemplaza eso por una integración real con la pasarela CodePay (API
directa, sin redirigir al comprador): el backend pide un QR a CodePay, lo
muestra en el POS, y la venta solo se da por completada cuando CodePay
confirma el pago (webhook o polling).

Una sola cuenta CodePay cubre todo el negocio (no hay credenciales por
sucursal).

## Credenciales y entorno

```bash
# backend/.env (gitignored)
CODEPAY_SANDBOX=true                 # true en desarrollo, false en producción
CODEPAY_API_URL=https://payapi.codewave.com.bo/api

CODEPAY_PUBLIC_KEY=pk_salybrasas_zjj1fepma3
CODEPAY_SECRET_KEY=sk_salybrasas_4rohnjfliwhi1gtnwqyv
CODEPAY_NOTIFICATION_SECRET=whsec_76if6m0x3lm4aisl8gku8

CODEPAY_SANDBOX_PUBLIC_KEY=pk_test_salybrasas_ugciydd
CODEPAY_SANDBOX_SECRET_KEY=sk_test_salybrasas_7vmabl8csbrn1qelbmk
```

El cliente CodePay resuelve en tiempo de ejecución qué par de llaves usar
según `CODEPAY_SANDBOX`. `CODEPAY_NOTIFICATION_SECRET` se usa para verificar
el webhook en ambos entornos (la doc no da un secreto de notificación
distinto para sandbox).

**Nota de seguridad no resuelta:** la doc entregada no incluye el algoritmo
exacto de la sección "6. Recibir y verificar el webhook" del checkout web
(cómo se calcula `X-Codepay-Signature`). Se implementa el estándar del
mercado (ver sección "Verificación del webhook" abajo), aislado en una sola
función (`verificarFirmaWebhook`) para poder corregirlo sin tocar el resto
del flujo si la doc real de CodePay especifica algo distinto (p. ej.
base64 en vez de hex, o un timestamp incluido en el mensaje firmado) antes
de salir a producción.

## Modelo de datos

### Migración `015_pagos_qr.sql` (schema-only, sin datos)

```sql
CREATE TABLE IF NOT EXISTS pagos_qr (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  pedido_id INT UNSIGNED NOT NULL,
  sucursal_id INT UNSIGNED NOT NULL,
  order_id VARCHAR(25) NOT NULL UNIQUE,
  tx_id VARCHAR(100) NULL,
  estado ENUM('pendiente','completado','fallido','expirado','cancelado') NOT NULL DEFAULT 'pendiente',
  estado_previo VARCHAR(20) NOT NULL,
  moneda VARCHAR(3) NOT NULL DEFAULT 'BOB',
  monto_neto DECIMAL(10,2) NOT NULL,
  comision DECIMAL(10,2) NULL,
  monto_total DECIMAL(10,2) NULL,
  qr_code MEDIUMTEXT NULL,
  expires_at DATETIME NOT NULL,
  datos_webhook JSON NULL,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (pedido_id) REFERENCES pedidos(id),
  FOREIGN KEY (sucursal_id) REFERENCES sucursales(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE pedidos
  MODIFY COLUMN estado ENUM('pendiente','listo','pendiente_pago','completado','cancelado') NOT NULL DEFAULT 'pendiente';
```

Un pedido puede tener varias filas en `pagos_qr` a lo largo del tiempo (un
intento fallido/expirado + un reintento posterior); solo una fila puede
estar `estado='pendiente'` a la vez para un mismo pedido (se valida en el
servicio, no con constraint de DB — mismo patrón usado para la exclusividad
de sesión de caja en la fase anterior).

### Modelo `PagoQr` (`backend/src/models/PagoQr.js`)

Campos como en la migración. Asociaciones en `models/index.js`:

```javascript
Pedido.hasMany(PagoQr, { foreignKey: 'pedido_id', as: 'pagosQr' });
PagoQr.belongsTo(Pedido, { foreignKey: 'pedido_id', as: 'pedido' });
```

### `Pedido.estado`

Se agrega `'pendiente_pago'` al ENUM (modelo `backend/src/models/Pedido.js`
y la migración de arriba). Significa "cobro QR en curso, aún no
confirmado" — no cuenta como venta consumada: no descuenta stock, no
genera asiento en `libro_caja`, no libera/ocupa mesa.

## Cliente CodePay

`backend/src/integrations/codepay/codepay.client.js`:

- `firmarToken(payload)` — HMAC-SHA256 sobre `${header}.${payload}` en
  base64url, arma el JWT igual que el ejemplo Node.js de la doc.
- `generarQr({ order_id, amount, description, expires_at })` — firma el
  token, hace `POST {CODEPAY_API_URL}/v1/payments/qr` con
  `{ token, pk: <public_key activa> }`, devuelve
  `{ qr_code, tx_id, amount, net_amount, commission_amount, expires_at }`.
- `consultarEstado(tx_id)` — `GET {CODEPAY_API_URL}/checkout/status/{tx_id}`,
  devuelve `{ status, tx_id, order_id }`.
- `verificarFirmaWebhook(rawBody, signatureHeader)` — HMAC-SHA256 de
  `rawBody` con `CODEPAY_NOTIFICATION_SECRET`, comparación en hex con
  `crypto.timingSafeEqual` contra el header `X-Codepay-Signature`.

Ningún otro módulo llama a `fetch`/HMAC directamente — todo pasa por este
cliente, que es el único punto a ajustar si la doc real difiere en algo.

## Flujo de cobro con QR

### Generación (`iniciarPagoQr`)

Se agrega como rama nueva dentro de `ventas.service.js`, reutilizada tanto
por `cobrar` (pedido de mesa/llevar ya existente) como por `crearCompleta`
(venta rápida) cuando `metodo_pago === 'qr'`:

1. Valida sesión de caja abierta (igual que hoy).
2. Arma `order_id = pedido_<pedido.id>_<intento>` (intento = cantidad de
   filas previas en `pagos_qr` para ese pedido + 1; alfanumérico + guión
   bajo, cabe en 25 chars para IDs de pedido de hasta 12 dígitos).
3. Arma `description` sanitizada a alfanumérico, recortada a 20 chars
   (p. ej. `nombre_negocio` de `Configuracion`).
4. `expires_at = now + 30 min`.
5. Llama `codepayClient.generarQr(...)`.
6. En una transacción: crea la fila `pagos_qr` (`estado='pendiente'`,
   `estado_previo = pedido.estado` actual — `'pendiente'` o `'listo'`), y
   pasa `pedido.estado` a `'pendiente_pago'`, persistiendo
   `descuento`/`propina`/`metodo_pago='qr'` en el pedido (para que la
   finalización posterior los tenga disponibles sin recibirlos de nuevo).
7. Para `crearCompleta`: primero crea el pedido y sus `detalles` (sin
   stock/libro/mesa), luego sigue los mismos pasos 2-6.
8. Devuelve `{ pedido, pago_qr: { qr_code, tx_id, expires_at, monto_neto, comision, monto_total } }`.

### Finalización compartida (`_finalizarVenta`)

Se extrae de la lógica que hoy vive al final de `cobrar` (todo lo que
ocurre dentro de la `sequelize.transaction`: `pedido.update({estado:
'completado', ...})`, descuento de stock por `detalle`, creación de
`LibroCaja`, incremento de `SesionCaja.total_ventas`, liberar mesa si
corresponde). Pasa a ser una función interna reutilizada por:
- el camino síncrono actual (`metodo_pago === 'efectivo'`, sin cambios de
  comportamiento);
- la confirmación de un pago QR (llamada desde el polling o el webhook).

### Confirmación (polling)

`GET /api/v1/ventas/:id/pago-qr/estado`:

1. Busca la fila `pagos_qr` vigente (`estado='pendiente'`) del pedido; si
   no hay ninguna, 404.
2. Si `now > expires_at`: marca la fila `expirado`, revierte
   `pedido.estado` al valor guardado en `PagoQr.estado_previo` (columna
   `estado_previo VARCHAR(20) NOT NULL` agregada a la tabla `pagos_qr` en
   la migración de arriba, poblada al crear la fila con el `pedido.estado`
   que tenía justo antes de pasar a `'pendiente_pago'` — `'pendiente'` o
   `'listo'`).
3. Si no expiró, llama `codepayClient.consultarEstado(tx_id)`.
   - `completed` → llama `_finalizarVenta(...)` con los datos guardados en
     el pedido, marca la fila `pagos_qr` como `completado`.
   - `failed` → marca la fila `fallido`, revierte `pedido.estado` a
     `estado_previo`.
   - `pending` → no hace nada, responde el estado actual.
4. Responde `{ estado, pedido (actualizado si cambió) }`.

### Confirmación (webhook)

`POST /webhooks/codepay` (montado en `app.js`, **fuera** de
`/api/v1`, sin middleware de auth de sesión):

1. `express.json({ verify })` ya captura `req.rawBody` globalmente (cambio
   de una línea en `app.use(express.json(...))` en `app.js`, sin afectar
   ninguna otra ruta).
2. Verifica `verificarFirmaWebhook(req.rawBody, req.headers['x-codepay-signature'])`;
   si falla, 401 y no procesa nada.
3. Busca `pagos_qr` por `order_id` (del body). Si no existe o ya no está
   `pendiente` (webhook duplicado / ya finalizado por polling), responde
   200 sin hacer nada más (idempotente).
4. Si `event === 'payment.completed'` → mismo camino que el polling
   (`_finalizarVenta` + marcar fila `completado`).
5. Si `event` indica fallo → marcar `fallido` + revertir pedido.
6. Responde 2xx en todos los casos manejados (para no disparar reintentos
   de CodePay), incluso si el evento no aplica.

En local esta ruta no será alcanzable desde CodePay (URL pública distinta);
queda lista para cuando el backend esté desplegado en
`salybrasas.codewave.com.bo`. Las pruebas de este endpoint se hacen con
requests HTTP simulados directamente contra el backend local, no con
CodePay real.

### Cancelación manual

`POST /api/v1/ventas/:id/pago-qr/cancelar`: si hay una fila `pendiente`
vigente, la marca `cancelado` y revierte `pedido.estado` a
`estado_previo`. Permite al cajero abortar y elegir otro método de pago.

## Frontend

- `frontend/src/api/pagosQr.js` (nuevo): `iniciarPagoQr(pedidoId, datosCobro)`,
  `consultarEstadoPagoQr(pedidoId)`, `cancelarPagoQr(pedidoId)`.
- `VentasPage.jsx`: al elegir "QR" y confirmar cobro, en vez de llamar
  directo a `cobrar`/`crearCompleta` con finalización inmediata, se llama
  al flujo QR y se abre un modal (`ModalPagoQr`):
  - Muestra `<img src={qr_code}>`, monto total (con comisión) y neto,
    cuenta regresiva hasta `expires_at`.
  - Hace polling a `consultarEstadoPagoQr` cada 3s.
  - Estado `completado`: cierra el modal, muestra confirmación (igual
    experiencia que un cobro en efectivo hoy — imprime ticket, libera
    mesa vía el mismo evento de socket `restaurante:actualizar` que ya
    emite `_finalizarVenta`).
  - Estado `fallido`/`expirado`: muestra el motivo y dos botones,
    "Reintentar" (nuevo `iniciarPagoQr`) y "Cambiar método de pago"
    (`cancelarPagoQr` + vuelve al selector).
  - Botón "Cancelar" siempre visible mientras está `pendiente`.
- Responsivo: el modal reusa el patrón de modales ya existente en la app
  (mismo componente base que `ModalAbrirCaja`/`ModalMovimiento`), que ya es
  mobile-first.

## Permisos

No se agregan permisos nuevos: el cobro con QR sigue detrás de los mismos
permisos que ya protegen `cobrar`/`crearCompleta` (`ventas.crear` o
equivalente vigente). El webhook no lleva auth de sesión (no puede, es
CodePay llamando) — su única protección es la verificación de firma.

## Errores

- Falla de red/HTTP al llamar `generarQr` → 502 con mensaje "No se pudo
  generar el QR, intenta de nuevo o cobra en efectivo"; el pedido no
  cambia de estado (no se crea la fila `pagos_qr` si la llamada falla).
- `amount` enviado a CodePay es siempre `monto_neto` de la venta (el
  descuento/propina ya aplicados) — nunca se le sube la comisión a mano,
  eso lo calcula CodePay.
- Firma de webhook inválida → 401, no se toca ninguna fila.
- Webhook o polling para un `pedido_id`/`tx_id` que ya no está `pendiente`
  → no-op idempotente (200 en el webhook, estado actual en el polling).

## Testing

- `codepayClient` mockeado en todos los tests de `ventas`/`pagos_qr` (no se
  llama a la API real de CodePay en ningún test).
- Tests de `codepay.client.js`: firma de JWT determinística dado un
  payload fijo; verificación de firma de webhook válida/inválida.
- Tests de servicio: iniciar QR desde `cobrar` y desde `crearCompleta`
  (pedido pasa a `pendiente_pago`, no se toca stock/libro todavía);
  confirmación exitosa vía polling (stock baja, libro_caja recibe el
  asiento, mesa se libera, pedido `completado`); confirmación fallida
  (pedido vuelve a su estado previo); expiración por tiempo; cancelación
  manual; webhook duplicado / fuera de orden (no-op); firma de webhook
  inválida (401, sin cambios).
