# Task 2 — Reporte: Cliente CodePay (firma JWT, generar QR, consultar estado, verificar webhook)

## Estado: DONE

## Resumen

Se implementó el cliente HTTP aislado para integración con CodePay, que centraliza todos los puntos de contacto con la pasarela QR. Incluye firma JWT HS256, generación de códigos QR, consulta de estado de transacciones, y verificación de firmas de webhooks. Cero dependencias externas (usa `crypto` y `fetch` global), cero acoplamientos con Express, Sequelize, u otros módulos backend.

## Archivos creados

- `backend/src/integrations/codepay/codepay.client.js` — Cliente con 4 funciones exportadas:
  - `firmarToken(payload, secretKey)` — Firma JWT manual (HS256) con header, payload y signature en base64url.
  - `generarQr({ order_id, amount, description, expires_at, currency })` — POST a `/v1/payments/qr` de CodePay; retorna `{ qr_code, tx_id, amount, net_amount, commission_amount, expires_at, order_id }`.
  - `consultarEstado(tx_id)` — GET a `/checkout/status/{tx_id}`; retorna estado actual `{ status, tx_id, order_id }`.
  - `verificarFirmaWebhook(rawBody, signatureHeader)` — HMAC-SHA256 timing-safe verificación de firmas de webhook usando `CODEPAY_NOTIFICATION_SECRET`.
  - Función privada `_credenciales()` — Selecciona claves sandbox o producción según `CODEPAY_SANDBOX`.

- `backend/tests/codepay.client.test.js` — Test suite con mock de `global.fetch`:
  - 2 tests de `firmarToken`: JWT de 3 segmentos determinístico, y cambio de firma con secreto distinto.
  - 3 tests de `generarQr`: respuesta exitosa, fallo con `!ok`, y excepción de red.
  - 2 tests de `consultarEstado`: respuesta exitosa y fallo con `!ok`.
  - 3 tests de `verificarFirmaWebhook`: firma válida, firma inválida, y ausencia de header.
  - Total: 10 tests, todos pasan. Cero llamadas reales a CodePay.

## Variables de entorno consumidas

Definidas en Task 1, presentes en `backend/.env`:
- `CODEPAY_SANDBOX` — Booleano (string 'true'/'false') para seleccionar sandbox.
- `CODEPAY_API_URL` — URL base de API (ej: `https://payapi.codewave.com.bo/api`).
- `CODEPAY_SANDBOX_PUBLIC_KEY`, `CODEPAY_SANDBOX_SECRET_KEY` — Credenciales sandbox.
- `CODEPAY_PUBLIC_KEY`, `CODEPAY_SECRET_KEY` — Credenciales producción.
- `CODEPAY_NOTIFICATION_SECRET` — Secreto para verificación de webhooks.

## Tests

```bash
$ cd backend && npm test -- codepay.client.test.js

Test Suites: 1 passed, 1 total
Tests:       10 passed, 10 total
Snapshots:   0 total
Time:        0.415 s
```

Todos los tests pasan. No hay llamadas reales a la red — `global.fetch` está completamente mockeado con `jest.fn()` y `mockResolvedValue`/`mockRejectedValue`.

## Commit

```
62991f8 feat(pagos-qr): cliente HTTP de CodePay (firma JWT, generar QR, consultar estado, verificar webhook)
```

Incluye 2 archivos nuevos:
- `backend/src/integrations/codepay/codepay.client.js`
- `backend/tests/codepay.client.test.js`

## Interfaz pública (tal como se usa desde Task 3 y Task 4)

```javascript
const { firmarToken, generarQr, consultarEstado, verificarFirmaWebhook } = require('../integrations/codepay/codepay.client');

// Generación de QR para pedido
const qr = await generarQr({
  order_id: 'pedido_1_1',
  amount: 150.50,
  description: 'Comida Restaurant X',
  expires_at: new Date(Date.now() + 15 * 60 * 1000).toISOString(),
  currency: 'BOB'
});
// { qr_code: '...', tx_id: 'tx_123', amount: 150.50, net_amount: 149.20, ... }

// Consulta de estado (polling)
const estado = await consultarEstado('tx_123');
// { status: 'completed' | 'pending', tx_id: 'tx_123', order_id: 'pedido_1_1' }

// Verificación de webhook en Task 4
const esValido = verificarFirmaWebhook(rawBody, req.get('x-signature'));
```

## Verificaciones

- [x] Cliente puro: sin `require('express')`, `Sequelize`, ni modelos.
- [x] Sin dependencias externas: usa `crypto` (Node core) y `fetch` (global).
- [x] Centralizado: único lugar que hace `fetch` o HMAC para CodePay.
- [x] Manejo de errores: excepciones con `.status` adjunto (502 para fallos de red/API).
- [x] Tests sin red: `global.fetch` mockeado; no hay llamadas a CodePay real.
- [x] Firma JWT manual: implementada verbatim del brief, HS256 correcto.
- [x] Webhook verification: timing-safe `timingSafeEqual`, no vulnerable a timing attacks.

## Notas

- El cliente está listo para ser consumido por Task 3 (servicio de ventas) y Task 4 (webhooks).
- No hay API Express, no hay rutas HTTP expuestas en este módulo — es pura lógica de cliente.
- El `_credenciales()` interno selecciona automáticamente sandbox vs producción según env, centralizando esa lógica.
