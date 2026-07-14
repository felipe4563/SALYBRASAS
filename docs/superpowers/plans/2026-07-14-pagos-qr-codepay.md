# Integración de pagos QR con CodePay — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar el método de pago "QR" (hoy una etiqueta manual sin verificación) por una integración real con la pasarela CodePay: generar un QR de cobro vía API, y solo completar la venta (descuento de stock, asiento en libro de caja, liberar mesa) cuando CodePay confirma el pago, por webhook o por polling.

**Architecture:** Nuevo cliente HTTP aislado para CodePay (firma JWT HMAC-SHA256, generación de QR, consulta de estado, verificación de firma de webhook). Nueva tabla `pagos_qr` que registra cada intento de cobro QR. El pedido gana un estado transitorio `'pendiente_pago'` mientras el QR está activo. La lógica de "completar una venta" (antes solo dentro de `cobrar`) se extrae a una función compartida (`_finalizarVenta`) reutilizada por el pago en efectivo (síncrono, sin cambios de comportamiento) y por la confirmación de un pago QR (asíncrona, disparada por polling o webhook).

**Tech Stack:** Node.js 24 (usa el `fetch` global, sin dependencias nuevas), Express, Sequelize/MySQL, Jest+Supertest (contra la DB local real, `--runInBand`), React 18 + TanStack Query v5 en el frontend.

## Global Constraints

- Una sola cuenta CodePay para todo el negocio (no hay credenciales por sucursal).
- `CODEPAY_SANDBOX=true` en desarrollo usa `CODEPAY_SANDBOX_PUBLIC_KEY`/`CODEPAY_SANDBOX_SECRET_KEY`; `false` usa `CODEPAY_PUBLIC_KEY`/`CODEPAY_SECRET_KEY`. `CODEPAY_NOTIFICATION_SECRET` es el mismo en ambos casos.
- `amount` enviado a CodePay es siempre el `monto_neto` de la venta (después de descuento/propina) — nunca se le suma la comisión a mano.
- `order_id` = `pedido_<pedido.id>_<intento>` (alfanumérico + guión bajo, ≤25 chars). Un reintento tras fallo/expiración usa un `order_id` nuevo (nunca reutiliza uno fallido).
- `description` enviada a CodePay: solo alfanumérico, máx 20 caracteres.
- `expires_at` siempre `now + 30 minutos`, ISO 8601 UTC.
- Ningún módulo llama a `fetch`/HMAC directamente salvo `codepay.client.js` — es el único punto a tocar si la doc real de CodePay difiere en algo (en particular, el algoritmo de `X-Codepay-Signature` no está confirmado contra la doc real; se implementa el estándar HMAC-SHA256 hex sobre el body crudo).
- No se agregan permisos nuevos: todo el flujo QR queda detrás de los permisos ya existentes de `ventas` (`cobrar`, `crear`). El webhook no lleva auth de sesión — su única protección es la verificación de firma.
- Migraciones (`backend/database/migrations/*.sql`) son schema-only, nunca contienen INSERT/UPDATE de datos.
- Los tests de backend corren contra la base de datos local real (`--runInBand`, sin mocks de DB) — sí se mockea el cliente HTTP de CodePay (nunca se llama a la API real en un test).

---

### Task 1: Migración, modelo `PagoQr`, estado `pendiente_pago` en Pedido, credenciales

**Files:**
- Create: `backend/database/migrations/015_pagos_qr.sql`
- Create: `backend/src/models/PagoQr.js`
- Modify: `backend/src/models/Pedido.js`
- Modify: `backend/src/models/index.js`
- Modify: `backend/.env.example`
- Modify: `backend/.env` (no se commitea — está en `.gitignore`)
- Test: `backend/tests/pagos_qr.model.test.js`

**Interfaces:**
- Produces: modelo `PagoQr` exportado desde `backend/src/models/index.js` junto al resto (`{ ..., PagoQr }`), con asociaciones `Pedido.hasMany(PagoQr, { as: 'pagosQr' })` / `PagoQr.belongsTo(Pedido, { as: 'pedido' })` / `PagoQr.belongsTo(Sucursal, { as: 'sucursal' })`. `Pedido.estado` acepta `'pendiente_pago'`.

- [ ] **Step 1: Escribir la migración**

`backend/database/migrations/015_pagos_qr.sql`:

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

- [ ] **Step 2: Aplicar la migración a la base de datos local**

`backend/.env` tiene `DB_NAME=bd_restaurante`, `DB_USER=root`, `DB_PASS=` (vacío). Aplicar con:

```bash
cd backend
mysql -u root bd_restaurante < database/migrations/015_pagos_qr.sql
```

Verificar que no haya errores. Si `ALTER TABLE pedidos` falla por un `sql_mode` incompatible (ya ocurrió en una fase anterior con `NO_ZERO_DATE` sobre `sesiones_caja.cerrado_en`), bajar el `sql_mode` solo para esa sesión de `mysql`, sin tocar nada versionado, tal como se hizo entonces.

- [ ] **Step 3: Crear el modelo `PagoQr`**

`backend/src/models/PagoQr.js`:

```javascript
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const PagoQr = sequelize.define('PagoQr', {
  id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
  pedido_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
  sucursal_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
  order_id: { type: DataTypes.STRING(25), allowNull: false, unique: true },
  tx_id: { type: DataTypes.STRING(100) },
  estado: { type: DataTypes.ENUM('pendiente', 'completado', 'fallido', 'expirado', 'cancelado'), defaultValue: 'pendiente' },
  estado_previo: { type: DataTypes.STRING(20), allowNull: false },
  moneda: { type: DataTypes.STRING(3), defaultValue: 'BOB' },
  monto_neto: { type: DataTypes.DECIMAL(10, 2), allowNull: false },
  comision: { type: DataTypes.DECIMAL(10, 2) },
  monto_total: { type: DataTypes.DECIMAL(10, 2) },
  qr_code: { type: DataTypes.TEXT('medium') },
  expires_at: { type: DataTypes.DATE, allowNull: false },
  datos_webhook: { type: DataTypes.JSON },
}, {
  tableName: 'pagos_qr',
  createdAt: 'creado_en',
  updatedAt: 'actualizado_en',
});

module.exports = PagoQr;
```

- [ ] **Step 4: Agregar `'pendiente_pago'` al enum de `Pedido.estado`**

En `backend/src/models/Pedido.js`, cambiar la línea:

```javascript
  estado: { type: DataTypes.ENUM('pendiente','listo','completado','cancelado'), defaultValue: 'pendiente' },
```

por:

```javascript
  estado: { type: DataTypes.ENUM('pendiente','listo','pendiente_pago','completado','cancelado'), defaultValue: 'pendiente' },
```

- [ ] **Step 5: Registrar el modelo y sus asociaciones en `models/index.js`**

Agregar el require junto a los demás, después de `const Caja = require('./Caja');`:

```javascript
const PagoQr = require('./PagoQr');
```

Agregar las asociaciones al final del bloque `// Cajas físicas (Fase 6)` (antes de `module.exports`):

```javascript
// Pagos QR (CodePay)
Pedido.hasMany(PagoQr, { foreignKey: 'pedido_id', as: 'pagosQr' });
PagoQr.belongsTo(Pedido, { foreignKey: 'pedido_id', as: 'pedido' });
PagoQr.belongsTo(Sucursal, { foreignKey: 'sucursal_id', as: 'sucursal' });
```

Agregar `PagoQr` al `module.exports`:

```javascript
module.exports = {
  sequelize,
  Rol, Permiso, Usuario,
  Area, Mesa,
  Categoria, Producto,
  Cliente,
  SesionCaja, Pedido, DetallePedido,
  DetalleArqueo, Gasto, LibroCaja,
  Proveedor, Compra, DetalleCompra,
  RegistroInventario,
  Configuracion,
  Reservacion,
  Sucursal,
  ProductoStockSucursal,
  Caja,
  PagoQr,
};
```

- [ ] **Step 6: Agregar las variables de entorno**

En `backend/.env.example`, agregar al final:

```bash
CODEPAY_SANDBOX=true
CODEPAY_API_URL=https://payapi.codewave.com.bo/api
CODEPAY_PUBLIC_KEY=
CODEPAY_SECRET_KEY=
CODEPAY_NOTIFICATION_SECRET=
CODEPAY_SANDBOX_PUBLIC_KEY=
CODEPAY_SANDBOX_SECRET_KEY=
```

En `backend/.env` (real, no versionado — **no pegar las llaves reales en ningún archivo que se vaya a commitear**; el usuario ya las compartió por chat en la conversación de diseño de esta fase, tomarlas de ahí y pegarlas directo en `.env` local), agregar al final las mismas 7 variables con los valores reales (`CODEPAY_SANDBOX`, `CODEPAY_API_URL`, `CODEPAY_PUBLIC_KEY`, `CODEPAY_SECRET_KEY`, `CODEPAY_NOTIFICATION_SECRET`, `CODEPAY_SANDBOX_PUBLIC_KEY`, `CODEPAY_SANDBOX_SECRET_KEY`).

- [ ] **Step 7: Escribir el test del modelo**

`backend/tests/pagos_qr.model.test.js`:

```javascript
const request = require('supertest');
const app = require('../src/app');
const bcrypt = require('bcryptjs');
const {
  Sucursal, Area, Mesa, Rol, Usuario, Caja, SesionCaja, Pedido, PagoQr,
} = require('../src/models');

describe('Modelo PagoQr', () => {
  let sucursalId, areaId, mesaId, usuarioId, cajaId, sesionId, pedidoId;

  beforeAll(async () => {
    const sucursal = await Sucursal.create({ nombre: 'Sucursal PagoQr Test' });
    sucursalId = sucursal.id;
    const area = await Area.create({ nombre: 'Area PagoQr Test', sucursal_id: sucursalId });
    areaId = area.id;
    const mesa = await Mesa.create({ area_id: areaId, nombre: 'Mesa PagoQr Test' });
    mesaId = mesa.id;
    const rol = await Rol.findOne({ where: { nombre: 'Cajero' } });
    const hash = await bcrypt.hash('clave123', 10);
    const usuario = await Usuario.create({ rol_id: rol.id, nombre: 'PagoQr Test', email: 'pagoqr-model-test@restaurante.com', contrasena: hash });
    usuarioId = usuario.id;
    const caja = await Caja.create({ sucursal_id: sucursalId, nombre: 'Caja PagoQr Test' });
    cajaId = caja.id;
    const sesion = await SesionCaja.create({ usuario_id: usuarioId, sucursal_id: sucursalId, caja_id: cajaId, monto_apertura: 0 });
    sesionId = sesion.id;
    const pedido = await Pedido.create({
      sucursal_id: sucursalId, mesa_id: mesaId, usuario_id: usuarioId, sesion_caja_id: sesionId,
      tipo: 'mesa', estado: 'pendiente_pago', total: 10,
    });
    pedidoId = pedido.id;
  });

  afterAll(async () => {
    await PagoQr.destroy({ where: { pedido_id: pedidoId } });
    await Pedido.destroy({ where: { id: pedidoId } });
    await SesionCaja.destroy({ where: { id: sesionId } });
    await Caja.destroy({ where: { id: cajaId } });
    await Usuario.destroy({ where: { id: usuarioId } });
    await Mesa.destroy({ where: { id: mesaId } });
    await Area.destroy({ where: { id: areaId } });
    await Sucursal.destroy({ where: { id: sucursalId } });
  });

  it('el pedido acepta el estado pendiente_pago', async () => {
    const pedido = await Pedido.findByPk(pedidoId);
    expect(pedido.estado).toBe('pendiente_pago');
  });

  it('crea un pago_qr asociado al pedido y lo recupera vía la asociación', async () => {
    await PagoQr.create({
      pedido_id: pedidoId,
      sucursal_id: sucursalId,
      order_id: `pedido_${pedidoId}_1`,
      estado: 'pendiente',
      estado_previo: 'pendiente',
      monto_neto: 10,
      expires_at: new Date(Date.now() + 30 * 60000),
    });

    const pedido = await Pedido.findByPk(pedidoId, { include: [{ model: PagoQr, as: 'pagosQr' }] });
    expect(pedido.pagosQr).toHaveLength(1);
    expect(pedido.pagosQr[0].order_id).toBe(`pedido_${pedidoId}_1`);
  });

  it('sanidad: la app sigue arrancando con el modelo nuevo cargado', async () => {
    const res = await request(app).get('/api/v1/salud');
    expect(res.status).toBe(200);
  });
});
```

- [ ] **Step 8: Correr los tests**

Run: `cd backend && npm test -- pagos_qr.model.test.js`
Expected: 3/3 tests PASS.

- [ ] **Step 9: Commit**

```bash
git add backend/database/migrations/015_pagos_qr.sql backend/src/models/PagoQr.js backend/src/models/Pedido.js backend/src/models/index.js backend/.env.example backend/tests/pagos_qr.model.test.js
git commit -m "feat(pagos-qr): tabla pagos_qr, modelo PagoQr y estado pendiente_pago en Pedido"
```

(`backend/.env` no se commitea — está en `.gitignore`.)

---

### Task 2: Cliente CodePay (firma JWT, generar QR, consultar estado, verificar webhook)

**Files:**
- Create: `backend/src/integrations/codepay/codepay.client.js`
- Test: `backend/tests/codepay.client.test.js`

**Interfaces:**
- Consumes: variables de entorno `CODEPAY_SANDBOX`, `CODEPAY_API_URL`, `CODEPAY_PUBLIC_KEY`, `CODEPAY_SECRET_KEY`, `CODEPAY_SANDBOX_PUBLIC_KEY`, `CODEPAY_SANDBOX_SECRET_KEY`, `CODEPAY_NOTIFICATION_SECRET` (Task 1).
- Produces: `module.exports = { firmarToken, generarQr, consultarEstado, verificarFirmaWebhook }` — usado por `ventas.service.js` (Task 3) y el módulo de webhook (Task 4).
  - `generarQr({ order_id, amount, description, expires_at, currency })` → `Promise<{ qr_code, tx_id, amount, net_amount, commission_amount, expires_at, order_id }>`.
  - `consultarEstado(tx_id)` → `Promise<{ status, tx_id, order_id }>`.
  - `verificarFirmaWebhook(rawBody: Buffer, signatureHeader: string|undefined)` → `boolean`.

- [ ] **Step 1: Escribir el cliente**

`backend/src/integrations/codepay/codepay.client.js`:

```javascript
const { createHmac, timingSafeEqual } = require('crypto');

function _credenciales() {
  const sandbox = process.env.CODEPAY_SANDBOX === 'true';
  return {
    apiUrl: process.env.CODEPAY_API_URL,
    publicKey: sandbox ? process.env.CODEPAY_SANDBOX_PUBLIC_KEY : process.env.CODEPAY_PUBLIC_KEY,
    secretKey: sandbox ? process.env.CODEPAY_SANDBOX_SECRET_KEY : process.env.CODEPAY_SECRET_KEY,
  };
}

function firmarToken(payload, secretKey) {
  const header = { alg: 'HS256', typ: 'JWT' };
  const h = Buffer.from(JSON.stringify(header)).toString('base64url');
  const p = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const sig = createHmac('sha256', secretKey).update(`${h}.${p}`).digest('base64url');
  return `${h}.${p}.${sig}`;
}

async function generarQr({ order_id, amount, description, expires_at, currency = 'BOB' }) {
  const { apiUrl, publicKey, secretKey } = _credenciales();
  const payload = { app_key: publicKey, order_id, amount, currency, description, expires_at };
  const token = firmarToken(payload, secretKey);

  let res;
  try {
    res = await fetch(`${apiUrl}/v1/payments/qr`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token, pk: publicKey }),
    });
  } catch {
    throw Object.assign(new Error('No se pudo generar el QR, intenta de nuevo o cobra en efectivo'), { status: 502 });
  }

  if (!res.ok) {
    throw Object.assign(new Error('No se pudo generar el QR, intenta de nuevo o cobra en efectivo'), { status: 502 });
  }
  return res.json();
}

async function consultarEstado(tx_id) {
  const { apiUrl } = _credenciales();

  let res;
  try {
    res = await fetch(`${apiUrl}/checkout/status/${tx_id}`);
  } catch {
    throw Object.assign(new Error('No se pudo consultar el estado del pago en CodePay'), { status: 502 });
  }

  if (!res.ok) {
    throw Object.assign(new Error('No se pudo consultar el estado del pago en CodePay'), { status: 502 });
  }
  return res.json();
}

function verificarFirmaWebhook(rawBody, signatureHeader) {
  if (!signatureHeader || !rawBody) return false;

  const esperada = createHmac('sha256', process.env.CODEPAY_NOTIFICATION_SECRET).update(rawBody).digest('hex');

  let recibida;
  try {
    recibida = Buffer.from(signatureHeader, 'hex');
  } catch {
    return false;
  }
  const calculada = Buffer.from(esperada, 'hex');
  if (recibida.length !== calculada.length) return false;
  return timingSafeEqual(recibida, calculada);
}

module.exports = { firmarToken, generarQr, consultarEstado, verificarFirmaWebhook };
```

- [ ] **Step 2: Escribir los tests (con `fetch` mockeado — nunca se llama a CodePay real)**

`backend/tests/codepay.client.test.js`:

```javascript
process.env.CODEPAY_SANDBOX = 'true';
process.env.CODEPAY_API_URL = 'https://payapi.codewave.com.bo/api';
process.env.CODEPAY_SANDBOX_PUBLIC_KEY = 'pk_test_x';
process.env.CODEPAY_SANDBOX_SECRET_KEY = 'sk_test_x';
process.env.CODEPAY_NOTIFICATION_SECRET = 'whsec_test_x';

const { createHmac } = require('crypto');
const {
  firmarToken, generarQr, consultarEstado, verificarFirmaWebhook,
} = require('../src/integrations/codepay/codepay.client');

describe('codepayClient.firmarToken', () => {
  it('genera un JWT con 3 segmentos y firma determinística para el mismo payload', () => {
    const payload = { app_key: 'pk_test_x', order_id: 'pedido_1_1', amount: 10, currency: 'BOB' };
    const token1 = firmarToken(payload, 'sk_test_x');
    const token2 = firmarToken(payload, 'sk_test_x');
    expect(token1.split('.')).toHaveLength(3);
    expect(token1).toBe(token2);
  });

  it('cambia la firma si cambia el secreto', () => {
    const payload = { app_key: 'pk_test_x', order_id: 'pedido_1_1', amount: 10, currency: 'BOB' };
    const tokenA = firmarToken(payload, 'sk_test_x');
    const tokenB = firmarToken(payload, 'otro_secreto');
    expect(tokenA).not.toBe(tokenB);
  });
});

describe('codepayClient.generarQr', () => {
  const originalFetch = global.fetch;
  afterEach(() => { global.fetch = originalFetch; });

  it('devuelve el JSON de CodePay cuando la respuesta es ok', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ qr_code: 'data:image/png;base64,abc', tx_id: 'tx_1', amount: 10.35, net_amount: 10, commission_amount: 0.35 }),
    });

    const res = await generarQr({ order_id: 'pedido_1_1', amount: 10, description: 'VentaTest', expires_at: new Date().toISOString() });
    expect(res.tx_id).toBe('tx_1');
    expect(global.fetch).toHaveBeenCalledWith(
      'https://payapi.codewave.com.bo/api/v1/payments/qr',
      expect.objectContaining({ method: 'POST' }),
    );
  });

  it('lanza 502 si CodePay responde !ok', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: false, json: async () => ({}) });
    await expect(generarQr({ order_id: 'pedido_1_1', amount: 10, description: 'x', expires_at: new Date().toISOString() }))
      .rejects.toMatchObject({ status: 502 });
  });

  it('lanza 502 si falla la red', async () => {
    global.fetch = jest.fn().mockRejectedValue(new Error('network down'));
    await expect(generarQr({ order_id: 'pedido_1_1', amount: 10, description: 'x', expires_at: new Date().toISOString() }))
      .rejects.toMatchObject({ status: 502 });
  });
});

describe('codepayClient.consultarEstado', () => {
  const originalFetch = global.fetch;
  afterEach(() => { global.fetch = originalFetch; });

  it('devuelve el estado reportado por CodePay', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ status: 'completed', tx_id: 'tx_1', order_id: 'pedido_1_1' }) });
    const res = await consultarEstado('tx_1');
    expect(res.status).toBe('completed');
  });

  it('lanza 502 si CodePay responde !ok', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: false, json: async () => ({}) });
    await expect(consultarEstado('tx_1')).rejects.toMatchObject({ status: 502 });
  });
});

describe('codepayClient.verificarFirmaWebhook', () => {
  it('acepta una firma válida', () => {
    const body = Buffer.from(JSON.stringify({ event: 'payment.completed', order_id: 'pedido_1_1' }));
    const firma = createHmac('sha256', 'whsec_test_x').update(body).digest('hex');
    expect(verificarFirmaWebhook(body, firma)).toBe(true);
  });

  it('rechaza una firma inválida', () => {
    const body = Buffer.from(JSON.stringify({ event: 'payment.completed', order_id: 'pedido_1_1' }));
    expect(verificarFirmaWebhook(body, 'firma_incorrecta_pero_hex_00112233')).toBe(false);
  });

  it('rechaza si no hay header de firma', () => {
    const body = Buffer.from(JSON.stringify({ event: 'payment.completed' }));
    expect(verificarFirmaWebhook(body, undefined)).toBe(false);
  });
});
```

- [ ] **Step 3: Correr los tests**

Run: `cd backend && npm test -- codepay.client.test.js`
Expected: 9/9 tests PASS. Ninguna llamada de red real (todo mockeado).

- [ ] **Step 4: Commit**

```bash
git add backend/src/integrations/codepay/codepay.client.js backend/tests/codepay.client.test.js
git commit -m "feat(pagos-qr): cliente HTTP de CodePay (firma JWT, generar QR, consultar estado, verificar webhook)"
```

---

### Task 3: `ventas.service.js` — flujo de cobro con QR (iniciar, confirmar, cancelar)

**Files:**
- Modify: `backend/src/modules/ventas/ventas.service.js`
- Modify: `backend/src/modules/ventas/ventas.controller.js`
- Modify: `backend/src/modules/ventas/ventas.routes.js`
- Modify: `backend/tests/ventas.test.js`

**Interfaces:**
- Consumes: `codepayClient.generarQr`/`consultarEstado` (Task 2), modelo `PagoQr` (Task 1).
- Produces: `ventas.service.js` exporta además `consultarEstadoPagoQr(pedido_id, alcance)`, `cancelarPagoQr(pedido_id, alcance)` y `procesarWebhookPagoQr({ event, order_id, tx_id })` (esta última la usará el módulo de webhook en Task 4 — no la llama nada más en este task).
  Cuando `metodo_pago === 'qr'`, `cobrar(...)` y `crearCompleta(...)` devuelven `{ pedido, pago_qr: { qr_code, tx_id, expires_at, monto_neto, comision, monto_total } }` en vez del pedido completado directamente (comportamiento sin cambios para `metodo_pago === 'efectivo'`).
  Nuevas rutas: `GET /api/v1/ventas/:id/pago-qr/estado`, `POST /api/v1/ventas/:id/pago-qr/cancelar` (mismos permisos que `/:id/cobrar`: `verificarPermiso('ventas', 'cobrar')`).

**IMPORTANTE — este task reemplaza el archivo completo `ventas.service.js`.** El archivo actual tiene 352 líneas; el contenido de abajo es el reemplazo completo, no un diff. Reescribir el archivo entero con este contenido.

- [ ] **Step 1: Reescribir `backend/src/modules/ventas/ventas.service.js` completo**

```javascript
const { Op } = require('sequelize');
const {
  Pedido, DetallePedido, Mesa, Producto, Cliente, SesionCaja, LibroCaja, Configuracion, PagoQr, sequelize,
} = require('../../models');
const { emitir } = require('../../socket');
const { ajustarStockSucursal } = require('../inventario/stock.service');
const codepayClient = require('../../integrations/codepay/codepay.client');

const INCLUDE_PEDIDO_COMPLETO = [
  { model: Mesa, as: 'mesa', attributes: ['id', 'nombre', 'estado'] },
  { model: Cliente, as: 'cliente', attributes: ['id', 'nombre', 'numero_documento'] },
  {
    model: DetallePedido, as: 'detalles',
    include: [{ model: Producto, as: 'producto', attributes: ['id', 'nombre', 'precio'] }],
  },
];

async function listar({ estado, mesa_id, sucursal_id, acceso_todas } = {}) {
  const where = {};
  if (estado) {
    where.estado = estado.includes(',') ? { [Op.in]: estado.split(',') } : estado;
  }
  if (mesa_id) where.mesa_id = mesa_id;
  if (!acceso_todas) where.sucursal_id = sucursal_id;
  return Pedido.findAll({ where, include: INCLUDE_PEDIDO_COMPLETO, order: [['creado_en', 'DESC']] });
}

async function listarCocina({ sucursal_id, acceso_todas } = {}) {
  const where = { estado: { [Op.in]: ['pendiente', 'listo'] } };
  if (!acceso_todas) where.sucursal_id = sucursal_id;
  return Pedido.findAll({
    where,
    include: INCLUDE_PEDIDO_COMPLETO,
    order: [['creado_en', 'ASC']],
  });
}

function _verificarAlcance(pedido, alcance) {
  if (alcance && !alcance.acceso_todas && pedido.sucursal_id !== alcance.sucursal_id) {
    throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  }
}

async function obtener(id, alcance) {
  const p = await Pedido.findByPk(id, { include: INCLUDE_PEDIDO_COMPLETO });
  if (!p) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  _verificarAlcance(p, alcance);
  return p;
}

async function _siguienteNumeroLlevar() {
  const inicio = new Date();
  inicio.setHours(0, 0, 0, 0);
  const fin = new Date();
  fin.setHours(23, 59, 59, 999);
  const count = await Pedido.count({
    where: {
      tipo: 'llevar',
      creado_en: { [Op.between]: [inicio, fin] },
    },
  });
  return count + 1;
}

async function crear({ mesa_id, tipo = 'mesa', usuario_id, cliente_id, sesion_caja_id, notas, nombre_cliente, documento_cliente, tipo_documento }) {
  if (!sesion_caja_id) {
    throw Object.assign(new Error('No hay caja abierta. Abre la caja antes de crear una orden.'), { status: 409 });
  }
  const sesionActiva = await SesionCaja.findByPk(sesion_caja_id);
  if (!sesionActiva || sesionActiva.estado !== 'abierta') {
    throw Object.assign(new Error('La sesión de caja no está abierta.'), { status: 409 });
  }
  const sucursal_id = sesionActiva.sucursal_id;

  if (tipo === 'mesa') {
    const mesa = await Mesa.findByPk(mesa_id);
    if (!mesa) throw Object.assign(new Error('Mesa no encontrada'), { status: 404 });

    const pedido = await Pedido.create({
      mesa_id, tipo: 'mesa', usuario_id, cliente_id, sesion_caja_id, sucursal_id, notas,
      nombre_cliente: nombre_cliente || 'Público General',
      documento_cliente,
      tipo_documento: tipo_documento || 'Ticket',
    });
    await mesa.update({ estado: 'ocupada' });
    const resultado = await obtener(pedido.id);
    emitir('restaurante:actualizar', { tipo: 'pedido_nuevo' }, sucursal_id);
    return resultado;
  }

  // tipo === 'llevar'
  const numero_llevar = await _siguienteNumeroLlevar();
  const pedido = await Pedido.create({
    mesa_id: null, tipo: 'llevar', numero_llevar, usuario_id, cliente_id, sesion_caja_id, sucursal_id, notas,
    nombre_cliente: nombre_cliente || 'Cliente',
    documento_cliente,
    tipo_documento: tipo_documento || 'Ticket',
  });
  const resultado = await obtener(pedido.id);
  emitir('restaurante:actualizar', { tipo: 'pedido_nuevo' }, sucursal_id);
  return resultado;
}

/**
 * Completa una venta ya decidida (efectivo, o confirmación de un pago QR):
 * marca el pedido completado, descuenta stock, registra el ingreso en el
 * libro de caja y libera la mesa si corresponde. Debe correr dentro de una
 * transacción activa.
 */
async function _finalizarVenta({ pedido, detalles, metodo_pago, monto_recibido, descuento = 0, propina = 0, usuario_id }, transaction) {
  const monto_neto = parseFloat(pedido.total) - parseFloat(descuento) + parseFloat(propina);
  const cambio = metodo_pago === 'efectivo' ? parseFloat(monto_recibido) - monto_neto : 0;

  await pedido.update({
    estado: 'completado', metodo_pago, monto_recibido: monto_recibido || monto_neto, cambio, descuento, propina,
  }, { transaction });

  if (pedido.tipo !== 'llevar' && pedido.mesa_id) {
    const pendientes = await Pedido.count({ where: { mesa_id: pedido.mesa_id, estado: 'pendiente' }, transaction });
    if (pendientes === 0) {
      await Mesa.update({ estado: 'disponible' }, { where: { id: pedido.mesa_id }, transaction });
    }
  }

  await LibroCaja.create({
    sesion_caja_id: pedido.sesion_caja_id, usuario_id, tipo: 'ingreso', concepto: `Venta #${pedido.id}`, monto: monto_neto, metodo_pago, referencia_id: pedido.id,
  }, { transaction });

  await SesionCaja.increment('total_ventas', { by: monto_neto, where: { id: pedido.sesion_caja_id }, transaction });

  for (const detalle of detalles) {
    const producto = await Producto.findByPk(detalle.producto_id, { transaction });
    if (producto && producto.stock !== null) {
      await ajustarStockSucursal({
        producto_id: detalle.producto_id, sucursal_id: pedido.sucursal_id, tipo: 'venta', cantidad: detalle.cantidad,
        usuario_id, nota: `Venta #${pedido.id}`, transaction,
      });
    }
  }

  return monto_neto;
}

async function _emitirImpresion(pedido, metodo_pago, cambio, sucursal_id) {
  const cfgRows = await Configuracion.findAll({ where: { clave: ['nombre_negocio', 'simbolo_moneda', 'direccion', 'telefono', 'flujo_cocina'] } });
  const cfg = cfgRows.reduce((o, r) => { o[r.clave] = r.valor; return o; }, {});

  const inicioDia = new Date(); inicioDia.setHours(0, 0, 0, 0);
  const finDia    = new Date(); finDia.setHours(23, 59, 59, 999);
  const numero_orden_diario = await Pedido.count({
    where: { creado_en: { [Op.between]: [inicioDia, finDia] }, estado: { [Op.ne]: 'cancelado' } },
  });

  emitir('print:caja', { pedido: pedido.toJSON(), metodo_pago, cambio, config: cfg, numero_orden_diario }, sucursal_id);
  if (cfg.flujo_cocina === 'fisico') {
    emitir('print:cocina', { pedido: pedido.toJSON(), config: cfg, numero_orden_diario }, sucursal_id);
  }
}

/**
 * Genera un QR de cobro con CodePay para un pedido ya persistido (con su
 * total ya calculado) y deja el pedido en 'pendiente_pago' hasta que se
 * confirme (ver consultarEstadoPagoQr / procesarWebhookPagoQr).
 */
async function iniciarPagoQr(pedido, { descuento = 0, propina = 0 } = {}) {
  const estadoPrevio = pedido.estado;
  const monto_neto = parseFloat(pedido.total) - parseFloat(descuento) + parseFloat(propina);
  const intentosPrevios = await PagoQr.count({ where: { pedido_id: pedido.id } });
  const order_id = `pedido_${pedido.id}_${intentosPrevios + 1}`;
  const expires_at = new Date(Date.now() + 30 * 60 * 1000);

  const cfg = await Configuracion.findOne({ where: { clave: 'nombre_negocio' } });
  const description = ((cfg && cfg.valor) || 'Venta').replace(/[^a-zA-Z0-9]/g, '').slice(0, 20) || 'Venta';

  const respuesta = await codepayClient.generarQr({
    order_id, amount: monto_neto, description, expires_at: expires_at.toISOString(),
  });

  await sequelize.transaction(async (t) => {
    await PagoQr.create({
      pedido_id: pedido.id, sucursal_id: pedido.sucursal_id, order_id,
      tx_id: respuesta.tx_id, estado: 'pendiente', estado_previo: estadoPrevio,
      monto_neto, comision: respuesta.commission_amount, monto_total: respuesta.amount,
      qr_code: respuesta.qr_code, expires_at,
    }, { transaction: t });

    await pedido.update({ estado: 'pendiente_pago', metodo_pago: 'qr', descuento, propina }, { transaction: t });
  });

  return {
    qr_code: respuesta.qr_code, tx_id: respuesta.tx_id, expires_at,
    monto_neto, comision: respuesta.commission_amount, monto_total: respuesta.amount,
  };
}

async function _revertirPagoQr(pagoQr, nuevoEstado) {
  await sequelize.transaction(async (t) => {
    await pagoQr.update({ estado: nuevoEstado }, { transaction: t });
    await Pedido.update({ estado: pagoQr.estado_previo }, { where: { id: pagoQr.pedido_id }, transaction: t });
  });
}

async function _confirmarPagoQr(pagoQr) {
  const pedido = await Pedido.findByPk(pagoQr.pedido_id, { include: INCLUDE_PEDIDO_COMPLETO });
  const detalles = pedido.detalles.map((d) => ({ producto_id: d.producto_id, cantidad: d.cantidad }));

  await sequelize.transaction(async (t) => {
    await _finalizarVenta({
      pedido, detalles, metodo_pago: 'qr', monto_recibido: pagoQr.monto_neto,
      descuento: pedido.descuento, propina: pedido.propina, usuario_id: pedido.usuario_id,
    }, t);
    await pagoQr.update({ estado: 'completado' }, { transaction: t });
  });

  const completado = await obtener(pedido.id);
  emitir('restaurante:actualizar', { tipo: 'pedido_cobrado' }, pedido.sucursal_id);
  await _emitirImpresion(completado, 'qr', 0, pedido.sucursal_id);
  return completado;
}

async function consultarEstadoPagoQr(pedido_id, alcance) {
  const pedido = await Pedido.findByPk(pedido_id);
  if (!pedido) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  _verificarAlcance(pedido, alcance);

  const pagoQr = await PagoQr.findOne({ where: { pedido_id, estado: 'pendiente' }, order: [['id', 'DESC']] });
  if (!pagoQr) throw Object.assign(new Error('No hay un pago QR pendiente para este pedido'), { status: 404 });

  if (new Date() > pagoQr.expires_at) {
    await _revertirPagoQr(pagoQr, 'expirado');
    return { estado: 'expirado', pedido: await obtener(pedido_id) };
  }

  const estadoCodepay = await codepayClient.consultarEstado(pagoQr.tx_id);

  if (estadoCodepay.status === 'completed') {
    await _confirmarPagoQr(pagoQr);
    return { estado: 'completado', pedido: await obtener(pedido_id) };
  }
  if (estadoCodepay.status === 'failed') {
    await _revertirPagoQr(pagoQr, 'fallido');
    return { estado: 'fallido', pedido: await obtener(pedido_id) };
  }
  return { estado: 'pendiente', pedido: await obtener(pedido_id) };
}

async function cancelarPagoQr(pedido_id, alcance) {
  const pedido = await Pedido.findByPk(pedido_id);
  if (!pedido) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  _verificarAlcance(pedido, alcance);

  const pagoQr = await PagoQr.findOne({ where: { pedido_id, estado: 'pendiente' }, order: [['id', 'DESC']] });
  if (!pagoQr) throw Object.assign(new Error('No hay un pago QR pendiente para este pedido'), { status: 404 });

  await _revertirPagoQr(pagoQr, 'cancelado');
  return obtener(pedido_id);
}

/** Usado por el endpoint de webhook (Task 4). Idempotente. */
async function procesarWebhookPagoQr({ event, order_id }) {
  const pagoQr = await PagoQr.findOne({ where: { order_id } });
  if (!pagoQr || pagoQr.estado !== 'pendiente') return;

  if (event === 'payment.completed') {
    await _confirmarPagoQr(pagoQr);
  } else if (event === 'payment.failed') {
    await _revertirPagoQr(pagoQr, 'fallido');
  }
}

async function crearCompleta({ tipo, mesa_id, nombre_cliente, documento_cliente, tipo_documento, items, metodo_pago, monto_recibido, descuento = 0, propina = 0, sesion_caja_id, usuario_id }) {
  if (!sesion_caja_id) {
    throw Object.assign(new Error('No hay caja abierta. Abre la caja antes de crear una orden.'), { status: 409 });
  }
  const sesionActiva = await SesionCaja.findByPk(sesion_caja_id);
  if (!sesionActiva || sesionActiva.estado !== 'abierta') {
    throw Object.assign(new Error('La sesión de caja no está abierta.'), { status: 409 });
  }
  const sucursal_id = sesionActiva.sucursal_id;

  if (!items || items.length === 0) {
    throw Object.assign(new Error('El pedido no tiene productos'), { status: 409 });
  }

  const productos = [];
  for (const item of items) {
    const producto = await Producto.findByPk(item.producto_id);
    if (!producto) throw Object.assign(new Error('Producto no encontrado'), { status: 404 });
    if (!producto.activo || !producto.es_vendible) throw Object.assign(new Error('Producto no disponible'), { status: 409 });
    productos.push({ item, producto });
  }

  let mesa = null;
  if (tipo === 'mesa') {
    if (!mesa_id) throw Object.assign(new Error('mesa_id es requerido'), { status: 400 });
    mesa = await Mesa.findByPk(mesa_id);
    if (!mesa) throw Object.assign(new Error('Mesa no encontrada'), { status: 404 });
    if (mesa.estado !== 'disponible') throw Object.assign(new Error('Mesa ya ocupada'), { status: 409 });
  } else if (tipo !== 'llevar') {
    throw Object.assign(new Error("tipo debe ser 'mesa' o 'llevar'"), { status: 400 });
  }

  const total = productos.reduce((sum, { item, producto }) => sum + item.cantidad * parseFloat(producto.precio), 0);
  const monto_neto = total - parseFloat(descuento) + parseFloat(propina);

  if (metodo_pago === 'efectivo') {
    if (!monto_recibido || parseFloat(monto_recibido) < monto_neto) {
      throw Object.assign(new Error('Monto recibido insuficiente'), { status: 400 });
    }
  }

  const numero_llevar = tipo === 'llevar' ? await _siguienteNumeroLlevar() : null;
  const estadoInicial = metodo_pago === 'qr' ? 'pendiente' : 'completado';

  const pedidoId = await sequelize.transaction(async (t) => {
    const pedido = await Pedido.create({
      mesa_id: tipo === 'mesa' ? mesa_id : null,
      tipo, numero_llevar, usuario_id, sesion_caja_id, sucursal_id,
      estado: estadoInicial, total, descuento, propina, metodo_pago: 'efectivo',
      nombre_cliente: nombre_cliente || (tipo === 'llevar' ? 'Cliente' : 'Público General'),
      documento_cliente,
      tipo_documento: tipo_documento || 'Ticket',
    }, { transaction: t });

    const detalles = [];
    for (const { item, producto } of productos) {
      await DetallePedido.create({
        pedido_id: pedido.id, producto_id: item.producto_id, cantidad: item.cantidad, precio: producto.precio, nota: item.nota,
      }, { transaction: t });
      detalles.push({ producto_id: item.producto_id, cantidad: item.cantidad });
    }

    if (metodo_pago !== 'qr') {
      await _finalizarVenta({ pedido, detalles, metodo_pago, monto_recibido, descuento, propina, usuario_id }, t);
    }

    return pedido.id;
  });

  if (metodo_pago === 'qr') {
    const pedidoPendiente = await Pedido.findByPk(pedidoId);
    const pago_qr = await iniciarPagoQr(pedidoPendiente, { descuento, propina });
    emitir('restaurante:actualizar', { tipo: 'pedido_nuevo' }, sucursal_id);
    return { pedido: await obtener(pedidoId), pago_qr };
  }

  const creado = await obtener(pedidoId);
  emitir('restaurante:actualizar', { tipo: 'pedido_cobrado' }, sucursal_id);
  await _emitirImpresion(creado, metodo_pago, parseFloat(monto_recibido || monto_neto) - monto_neto, sucursal_id);
  return creado;
}

async function agregarItem(pedido_id, { producto_id, cantidad = 1, nota }, alcance) {
  const pedido = await Pedido.findByPk(pedido_id);
  if (!pedido) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  _verificarAlcance(pedido, alcance);
  if (pedido.estado !== 'pendiente') throw Object.assign(new Error('El pedido no está pendiente'), { status: 409 });

  const producto = await Producto.findByPk(producto_id);
  if (!producto) throw Object.assign(new Error('Producto no encontrado'), { status: 404 });
  if (!producto.activo || !producto.es_vendible) throw Object.assign(new Error('Producto no disponible'), { status: 409 });

  const item = await DetallePedido.create({
    pedido_id,
    producto_id,
    cantidad,
    precio: producto.precio,
    nota,
  });

  await _recalcularTotal(pedido_id);
  emitir('restaurante:actualizar', { tipo: 'pedido_items' });
  return item;
}

async function actualizarItem(pedido_id, item_id, { cantidad, nota, estado }, alcance) {
  const pedido = await Pedido.findByPk(pedido_id);
  if (!pedido) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  _verificarAlcance(pedido, alcance);
  const item = await DetallePedido.findOne({ where: { id: item_id, pedido_id } });
  if (!item) throw Object.assign(new Error('Item no encontrado'), { status: 404 });
  await item.update({ cantidad, nota, estado });
  await _recalcularTotal(pedido_id);
  emitir('restaurante:actualizar', { tipo: 'pedido_items' });
  return item;
}

async function eliminarItem(pedido_id, item_id, alcance) {
  const pedido = await Pedido.findByPk(pedido_id);
  if (!pedido) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  _verificarAlcance(pedido, alcance);
  if (pedido.estado !== 'pendiente') throw Object.assign(new Error('Pedido no modificable'), { status: 409 });
  const item = await DetallePedido.findOne({ where: { id: item_id, pedido_id } });
  if (!item) throw Object.assign(new Error('Item no encontrado'), { status: 404 });
  await item.destroy();
  await _recalcularTotal(pedido_id);
  emitir('restaurante:actualizar', { tipo: 'pedido_items' });
}

async function cobrar(pedido_id, usuario_id, { metodo_pago, monto_recibido, descuento = 0, propina = 0 }, alcance) {
  const pedido = await Pedido.findByPk(pedido_id, { include: INCLUDE_PEDIDO_COMPLETO });
  if (!pedido) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  _verificarAlcance(pedido, alcance);
  if (!['pendiente', 'listo'].includes(pedido.estado)) throw Object.assign(new Error('El pedido no puede cobrarse'), { status: 409 });
  if (!pedido.sesion_caja_id) throw Object.assign(new Error('No hay sesión de caja activa en este pedido'), { status: 409 });

  const sesion = await SesionCaja.findByPk(pedido.sesion_caja_id);
  if (!sesion || sesion.estado !== 'abierta') throw Object.assign(new Error('La sesión de caja está cerrada'), { status: 409 });

  const monto_neto = parseFloat(pedido.total) - parseFloat(descuento) + parseFloat(propina);

  if (metodo_pago === 'efectivo' && (!monto_recibido || parseFloat(monto_recibido) < monto_neto)) {
    throw Object.assign(new Error('Monto recibido insuficiente'), { status: 400 });
  }

  if (metodo_pago === 'qr') {
    const pago_qr = await iniciarPagoQr(pedido, { descuento, propina });
    return { pedido: await obtener(pedido_id), pago_qr };
  }

  const detalles = pedido.detalles.map((d) => ({ producto_id: d.producto_id, cantidad: d.cantidad }));
  await sequelize.transaction((t) => _finalizarVenta({ pedido, detalles, metodo_pago, monto_recibido, descuento, propina, usuario_id }, t));

  const cobrado = await obtener(pedido_id);
  emitir('restaurante:actualizar', { tipo: 'pedido_cobrado' }, pedido.sucursal_id);
  await _emitirImpresion(cobrado, metodo_pago, parseFloat(monto_recibido) - monto_neto, pedido.sucursal_id);
  return cobrado;
}

async function cancelar(pedido_id, usuario_id, alcance) {
  const pedido = await Pedido.findByPk(pedido_id);
  if (!pedido) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  _verificarAlcance(pedido, alcance);
  if (pedido.estado !== 'pendiente') throw Object.assign(new Error('Solo se pueden cancelar pedidos pendientes'), { status: 409 });

  await pedido.update({ estado: 'cancelado' });

  if (pedido.tipo !== 'llevar' && pedido.mesa_id) {
    const pendientes = await Pedido.count({ where: { mesa_id: pedido.mesa_id, estado: 'pendiente' } });
    if (pendientes === 0) {
      await Mesa.update({ estado: 'disponible' }, { where: { id: pedido.mesa_id } });
    }
  }

  const cancelado = await obtener(pedido_id);
  emitir('restaurante:actualizar', { tipo: 'pedido_cancelado' });
  return cancelado;
}

async function _recalcularTotal(pedido_id) {
  const [result] = await sequelize.query(
    'SELECT COALESCE(SUM(cantidad * precio), 0) as total FROM detalle_pedidos WHERE pedido_id = ?',
    { replacements: [pedido_id], type: sequelize.QueryTypes.SELECT }
  );
  await Pedido.update({ total: result.total }, { where: { id: pedido_id } });
}

async function marcarListo(pedido_id, alcance) {
  const pedido = await Pedido.findByPk(pedido_id);
  if (!pedido) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  _verificarAlcance(pedido, alcance);
  if (pedido.estado !== 'pendiente') throw Object.assign(new Error('Solo pedidos pendientes pueden marcarse como listos'), { status: 409 });
  await pedido.update({ estado: 'listo' });
  const listo = await obtener(pedido_id);
  emitir('restaurante:actualizar', { tipo: 'pedido_listo' });
  return listo;
}

module.exports = {
  listar, listarCocina, obtener, crear, crearCompleta, agregarItem, actualizarItem, eliminarItem,
  cobrar, cancelar, marcarListo,
  consultarEstadoPagoQr, cancelarPagoQr, procesarWebhookPagoQr,
};
```

- [ ] **Step 2: Agregar los controladores nuevos**

En `backend/src/modules/ventas/ventas.controller.js`, agregar (junto a `cobrar`/`cancelar`):

```javascript
async function estadoPagoQr(req, res, next) {
  try { res.json({ ok: true, datos: await svc.consultarEstadoPagoQr(req.params.id, _alcance(req)) }); }
  catch (err) { next(err); }
}

async function cancelarPagoQr(req, res, next) {
  try { res.json({ ok: true, datos: await svc.cancelarPagoQr(req.params.id, _alcance(req)) }); }
  catch (err) { next(err); }
}
```

Y en el `module.exports` final, agregar `estadoPagoQr, cancelarPagoQr`:

```javascript
module.exports = { listar, obtener, crear, crearCompleta, agregarItem, actualizarItem, eliminarItem, cobrar, cancelar, listarCocina, marcarListo, estadoPagoQr, cancelarPagoQr };
```

- [ ] **Step 3: Agregar las rutas nuevas**

En `backend/src/modules/ventas/ventas.routes.js`, agregar después de la línea de `/:id/cobrar`:

```javascript
router.get('/:id/pago-qr/estado', verificarPermiso('ventas', 'cobrar'), ctrl.estadoPagoQr);
router.post('/:id/pago-qr/cancelar', verificarPermiso('ventas', 'cobrar'), ctrl.cancelarPagoQr);
```

- [ ] **Step 4: Agregar los tests de integración a `backend/tests/ventas.test.js`**

Agregar al final del archivo (después del último `describe` existente), reutilizando el import de modelos que ya está en la parte superior del archivo — agregar `PagoQr` a esa lista de imports existente (`const { Sucursal, Area, Mesa, Categoria, Producto, ProductoStockSucursal, Usuario, Rol, SesionCaja, Pedido, RegistroInventario, LibroCaja, Caja } = require('../src/models');` pasa a incluir también `PagoQr`), y agregar `jest.mock` del cliente de CodePay como las primeras líneas del archivo, **antes** de `const app = require('../src/app');`. Este proyecto no usa Babel/ESM (es CommonJS puro, sin hoisting automático de `jest.mock`), así que el orden físico en el archivo importa: si `jest.mock` quedara después del `require('../src/app')`, `ventas.service.js` ya habría cargado el cliente real de CodePay antes de que el mock exista:

```javascript
jest.mock('../src/integrations/codepay/codepay.client', () => ({
  generarQr: jest.fn(),
  consultarEstado: jest.fn(),
  verificarFirmaWebhook: jest.fn(),
}));
```

Y al final del archivo:

```javascript
const codepayClientMock = require('../src/integrations/codepay/codepay.client');

describe('Ventas — cobro con QR (CodePay)', () => {
  let sucursalId, areaId, mesaId, usuarioId, cajaId, sesionId, productoId, token;

  beforeAll(async () => {
    const sucursal = await Sucursal.create({ nombre: 'Sucursal PagoQr Ventas Test' });
    sucursalId = sucursal.id;
    const area = await Area.create({ nombre: 'Area PagoQr Ventas Test', sucursal_id: sucursalId });
    areaId = area.id;
    const mesa = await Mesa.create({ area_id: areaId, nombre: 'Mesa PagoQr Ventas Test' });
    mesaId = mesa.id;
    const categoria = await Categoria.create({ nombre: 'Categoria PagoQr Ventas Test' });
    const producto = await Producto.create({ categoria_id: categoria.id, nombre: 'Producto PagoQr Ventas Test', precio: 5, stock: 0 });
    productoId = producto.id;
    await ProductoStockSucursal.create({ producto_id: productoId, sucursal_id: sucursalId, stock: 10 });

    const rol = await Rol.findOne({ where: { nombre: 'Cajero' } });
    const hash = await bcrypt.hash('clave123', 10);
    const usuario = await Usuario.create({ rol_id: rol.id, nombre: 'PagoQr Ventas Test', email: 'pagoqr-ventas-test@restaurante.com', contrasena: hash });
    usuarioId = usuario.id;
    await usuario.addSucursal(sucursal);

    const login = await request(app).post('/api/v1/auth/login').send({ email: 'pagoqr-ventas-test@restaurante.com', contrasena: 'clave123' });
    token = login.body.datos.token;

    const caja = await Caja.create({ sucursal_id: sucursalId, nombre: 'Caja PagoQr Ventas Test' });
    cajaId = caja.id;
    const sesion = await SesionCaja.create({ usuario_id: usuarioId, sucursal_id: sucursalId, caja_id: cajaId, monto_apertura: 0 });
    sesionId = sesion.id;
  });

  afterEach(() => { jest.clearAllMocks(); });

  afterAll(async () => {
    await PagoQr.destroy({ where: { sucursal_id: sucursalId } });
    await Pedido.destroy({ where: { usuario_id: usuarioId } });
    await LibroCaja.destroy({ where: { usuario_id: usuarioId } });
    await SesionCaja.destroy({ where: { id: sesionId } });
    await Caja.destroy({ where: { id: cajaId } });
    await ProductoStockSucursal.destroy({ where: { producto_id: productoId } });
    await Producto.destroy({ where: { id: productoId } });
    await Usuario.destroy({ where: { id: usuarioId } });
    await Mesa.destroy({ where: { id: mesaId } });
    await Area.destroy({ where: { id: areaId } });
    await Sucursal.destroy({ where: { id: sucursalId } });
  });

  it('crearCompleta con metodo_pago=qr deja el pedido en pendiente_pago sin tocar stock ni libro de caja', async () => {
    codepayClientMock.generarQr.mockResolvedValue({
      qr_code: 'data:image/png;base64,abc', tx_id: 'tx_qr_1', amount: 10.35, net_amount: 10, commission_amount: 0.35,
    });

    const res = await request(app)
      .post('/api/v1/ventas/completa')
      .set('Authorization', `Bearer ${token}`)
      .send({
        tipo: 'llevar', metodo_pago: 'qr', sesion_caja_id: sesionId,
        items: [{ producto_id: productoId, cantidad: 2 }],
      });

    expect(res.status).toBe(201);
    expect(res.body.datos.pago_qr.tx_id).toBe('tx_qr_1');
    expect(res.body.datos.pedido.estado).toBe('pendiente_pago');

    const fila = await ProductoStockSucursal.findOne({ where: { producto_id: productoId, sucursal_id: sucursalId } });
    expect(fila.stock).toBe(10); // sin cambios todavía

    const entradasLibro = await LibroCaja.count({ where: { referencia_id: res.body.datos.pedido.id } });
    expect(entradasLibro).toBe(0);
  });

  it('confirmación exitosa por polling: completa la venta, descuenta stock y registra el ingreso', async () => {
    codepayClientMock.generarQr.mockResolvedValue({
      qr_code: 'data:image/png;base64,abc', tx_id: 'tx_qr_2', amount: 10.35, net_amount: 10, commission_amount: 0.35,
    });

    const creado = await request(app)
      .post('/api/v1/ventas/completa')
      .set('Authorization', `Bearer ${token}`)
      .send({
        tipo: 'llevar', metodo_pago: 'qr', sesion_caja_id: sesionId,
        items: [{ producto_id: productoId, cantidad: 1 }],
      });
    const pedidoId = creado.body.datos.pedido.id;

    codepayClientMock.consultarEstado.mockResolvedValue({ status: 'completed', tx_id: 'tx_qr_2', order_id: `pedido_${pedidoId}_1` });

    const res = await request(app)
      .get(`/api/v1/ventas/${pedidoId}/pago-qr/estado`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.datos.estado).toBe('completado');
    expect(res.body.datos.pedido.estado).toBe('completado');

    const entradasLibro = await LibroCaja.count({ where: { referencia_id: pedidoId } });
    expect(entradasLibro).toBe(1);
  });

  it('confirmación fallida por polling: el pedido vuelve a pendiente y puede reintentarse', async () => {
    codepayClientMock.generarQr.mockResolvedValue({
      qr_code: 'data:image/png;base64,abc', tx_id: 'tx_qr_3', amount: 10.35, net_amount: 10, commission_amount: 0.35,
    });

    const creado = await request(app)
      .post('/api/v1/ventas/completa')
      .set('Authorization', `Bearer ${token}`)
      .send({
        tipo: 'llevar', metodo_pago: 'qr', sesion_caja_id: sesionId,
        items: [{ producto_id: productoId, cantidad: 1 }],
      });
    const pedidoId = creado.body.datos.pedido.id;

    codepayClientMock.consultarEstado.mockResolvedValue({ status: 'failed', tx_id: 'tx_qr_3', order_id: `pedido_${pedidoId}_1` });

    const res = await request(app)
      .get(`/api/v1/ventas/${pedidoId}/pago-qr/estado`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.datos.estado).toBe('fallido');
    expect(res.body.datos.pedido.estado).toBe('pendiente');

    // Reintento: nuevo order_id (segundo intento), pedido vuelve a pendiente_pago
    codepayClientMock.generarQr.mockResolvedValue({
      qr_code: 'data:image/png;base64,def', tx_id: 'tx_qr_3b', amount: 10.35, net_amount: 10, commission_amount: 0.35,
    });
    const reintento = await request(app)
      .post(`/api/v1/ventas/${pedidoId}/cobrar`)
      .set('Authorization', `Bearer ${token}`)
      .send({ metodo_pago: 'qr' });

    expect(reintento.status).toBe(200);
    expect(reintento.body.datos.pago_qr.tx_id).toBe('tx_qr_3b');
    expect(codepayClientMock.generarQr).toHaveBeenCalledWith(expect.objectContaining({ order_id: `pedido_${pedidoId}_2` }));
  });

  it('cancelación manual: revierte el pedido a su estado previo', async () => {
    codepayClientMock.generarQr.mockResolvedValue({
      qr_code: 'data:image/png;base64,abc', tx_id: 'tx_qr_4', amount: 10.35, net_amount: 10, commission_amount: 0.35,
    });

    const creado = await request(app)
      .post('/api/v1/ventas/completa')
      .set('Authorization', `Bearer ${token}`)
      .send({
        tipo: 'llevar', metodo_pago: 'qr', sesion_caja_id: sesionId,
        items: [{ producto_id: productoId, cantidad: 1 }],
      });
    const pedidoId = creado.body.datos.pedido.id;

    const res = await request(app)
      .post(`/api/v1/ventas/${pedidoId}/pago-qr/cancelar`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.datos.estado).toBe('pendiente');
  });

  it('GET pago-qr/estado sin ningún pago pendiente → 404', async () => {
    const creado = await request(app)
      .post('/api/v1/ventas')
      .set('Authorization', `Bearer ${token}`)
      .send({ mesa_id: mesaId, tipo: 'mesa', sesion_caja_id: sesionId });

    const res = await request(app)
      .get(`/api/v1/ventas/${creado.body.datos.id}/pago-qr/estado`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(404);
  });
});
```

- [ ] **Step 5: Correr toda la suite de backend**

Run: `cd backend && npm test`
Expected: todas las suites PASS (incluidas las preexistentes — `cobrar`/`crearCompleta` con `metodo_pago='efectivo'` deben seguir pasando exactamente igual que antes).

- [ ] **Step 6: Commit**

```bash
git add backend/src/modules/ventas/ventas.service.js backend/src/modules/ventas/ventas.controller.js backend/src/modules/ventas/ventas.routes.js backend/tests/ventas.test.js
git commit -m "feat(pagos-qr): flujo de cobro con QR en ventas (iniciar, confirmar por polling, cancelar)"
```

---

### Task 4: Webhook `/webhooks/codepay`

**Files:**
- Create: `backend/src/webhooks/codepay.webhook.routes.js`
- Modify: `backend/src/app.js`
- Test: `backend/tests/webhooks-codepay.test.js`

**Interfaces:**
- Consumes: `codepayClient.verificarFirmaWebhook` (Task 2), `ventasService.procesarWebhookPagoQr` (Task 3).
- Produces: ruta pública `POST /webhooks/codepay` montada en `app.js`, fuera de `/api/v1` y sin middleware de auth de sesión.

- [ ] **Step 1: Capturar el body crudo en `app.js` (una sola línea de cambio)**

En `backend/src/app.js`, reemplazar:

```javascript
app.use(express.json());
```

por:

```javascript
app.use(express.json({
  verify: (req, _res, buf) => { req.rawBody = buf; },
}));
```

Esto no cambia el comportamiento de ninguna ruta existente — solo agrega `req.rawBody` (el `Buffer` crudo del body) disponible para el webhook.

- [ ] **Step 2: Crear el router del webhook**

`backend/src/webhooks/codepay.webhook.routes.js`:

```javascript
const { Router } = require('express');
const codepayClient = require('../integrations/codepay/codepay.client');
const ventasService = require('../modules/ventas/ventas.service');

const router = Router();

router.post('/codepay', async (req, res) => {
  const firmaValida = codepayClient.verificarFirmaWebhook(req.rawBody, req.headers['x-codepay-signature']);
  if (!firmaValida) {
    return res.status(401).json({ ok: false, mensaje: 'Firma inválida' });
  }

  try {
    await ventasService.procesarWebhookPagoQr(req.body);
  } catch (err) {
    console.error('Error procesando webhook de CodePay:', err);
  }

  res.status(200).json({ ok: true });
});

module.exports = router;
```

- [ ] **Step 3: Montar la ruta en `app.js`**

Agregar el require junto a los demás:

```javascript
const codepayWebhookRoutes = require('./webhooks/codepay.webhook.routes');
```

Y montarla (después de la ruta de salud, junto con el resto de `app.use`):

```javascript
app.use('/webhooks', codepayWebhookRoutes);
```

- [ ] **Step 4: Escribir los tests**

`backend/tests/webhooks-codepay.test.js`:

```javascript
const request = require('supertest');
const { createHmac } = require('crypto');
const bcrypt = require('bcryptjs');
const app = require('../src/app');
const {
  Sucursal, Area, Mesa, Categoria, Producto, ProductoStockSucursal, Usuario, Rol,
  Caja, SesionCaja, Pedido, DetallePedido, PagoQr, LibroCaja,
} = require('../src/models');

function firmar(bodyObj) {
  const raw = JSON.stringify(bodyObj);
  return createHmac('sha256', process.env.CODEPAY_NOTIFICATION_SECRET).update(raw).digest('hex');
}

describe('POST /webhooks/codepay', () => {
  let sucursalId, areaId, mesaId, usuarioId, cajaId, sesionId, productoId, pedidoId, pagoQrId;
  const orderId = () => `pedido_${pedidoId}_1`;

  beforeAll(async () => {
    const sucursal = await Sucursal.create({ nombre: 'Sucursal Webhook Test' });
    sucursalId = sucursal.id;
    const area = await Area.create({ nombre: 'Area Webhook Test', sucursal_id: sucursalId });
    areaId = area.id;
    const mesa = await Mesa.create({ area_id: areaId, nombre: 'Mesa Webhook Test' });
    mesaId = mesa.id;
    const categoria = await Categoria.create({ nombre: 'Categoria Webhook Test' });
    const producto = await Producto.create({ categoria_id: categoria.id, nombre: 'Producto Webhook Test', precio: 5, stock: 0 });
    productoId = producto.id;
    await ProductoStockSucursal.create({ producto_id: productoId, sucursal_id: sucursalId, stock: 3 });

    const rol = await Rol.findOne({ where: { nombre: 'Cajero' } });
    const hash = await bcrypt.hash('clave123', 10);
    const usuario = await Usuario.create({ rol_id: rol.id, nombre: 'Webhook Test', email: 'webhook-codepay-test@restaurante.com', contrasena: hash });
    usuarioId = usuario.id;

    const caja = await Caja.create({ sucursal_id: sucursalId, nombre: 'Caja Webhook Test' });
    cajaId = caja.id;
    const sesion = await SesionCaja.create({ usuario_id: usuarioId, sucursal_id: sucursalId, caja_id: cajaId, monto_apertura: 0 });
    sesionId = sesion.id;

    const pedido = await Pedido.create({
      sucursal_id: sucursalId, mesa_id: mesaId, usuario_id: usuarioId, sesion_caja_id: sesionId,
      tipo: 'mesa', estado: 'pendiente_pago', total: 10, descuento: 0, propina: 0,
    });
    pedidoId = pedido.id;
    await DetallePedido.create({ pedido_id: pedidoId, producto_id: productoId, cantidad: 2, precio: 5 });

    const pagoQr = await PagoQr.create({
      pedido_id: pedidoId, sucursal_id: sucursalId, order_id: orderId(), tx_id: 'tx_webhook_1',
      estado: 'pendiente', estado_previo: 'pendiente', monto_neto: 10, expires_at: new Date(Date.now() + 30 * 60000),
    });
    pagoQrId = pagoQr.id;
  });

  afterAll(async () => {
    await PagoQr.destroy({ where: { pedido_id: pedidoId } });
    await LibroCaja.destroy({ where: { referencia_id: pedidoId } });
    await Pedido.destroy({ where: { id: pedidoId } });
    await SesionCaja.destroy({ where: { id: sesionId } });
    await Caja.destroy({ where: { id: cajaId } });
    await ProductoStockSucursal.destroy({ where: { producto_id: productoId } });
    await Producto.destroy({ where: { id: productoId } });
    await Usuario.destroy({ where: { id: usuarioId } });
    await Mesa.destroy({ where: { id: mesaId } });
    await Area.destroy({ where: { id: areaId } });
    await Sucursal.destroy({ where: { id: sucursalId } });
  });

  it('firma inválida → 401 y no cambia nada', async () => {
    const body = { event: 'payment.completed', order_id: orderId(), tx_id: 'tx_webhook_1' };
    const res = await request(app)
      .post('/webhooks/codepay')
      .set('X-Codepay-Signature', '00112233')
      .send(body);

    expect(res.status).toBe(401);
    const pedido = await Pedido.findByPk(pedidoId);
    expect(pedido.estado).toBe('pendiente_pago');
  });

  it('firma válida + payment.completed → finaliza la venta', async () => {
    const body = { event: 'payment.completed', order_id: orderId(), tx_id: 'tx_webhook_1', status: 'completed' };
    const res = await request(app)
      .post('/webhooks/codepay')
      .set('X-Codepay-Signature', firmar(body))
      .send(body);

    expect(res.status).toBe(200);

    const pedido = await Pedido.findByPk(pedidoId);
    expect(pedido.estado).toBe('completado');

    const fila = await ProductoStockSucursal.findOne({ where: { producto_id: productoId, sucursal_id: sucursalId } });
    expect(fila.stock).toBe(1); // 3 - 2

    const pagoQr = await PagoQr.findByPk(pagoQrId);
    expect(pagoQr.estado).toBe('completado');

    const entradasLibro = await LibroCaja.count({ where: { referencia_id: pedidoId } });
    expect(entradasLibro).toBe(1);
  });

  it('webhook duplicado sobre el mismo pago ya completado → 200 no-op, no duplica el asiento', async () => {
    const body = { event: 'payment.completed', order_id: orderId(), tx_id: 'tx_webhook_1' };
    const res = await request(app)
      .post('/webhooks/codepay')
      .set('X-Codepay-Signature', firmar(body))
      .send(body);

    expect(res.status).toBe(200);
    const entradasLibro = await LibroCaja.count({ where: { referencia_id: pedidoId } });
    expect(entradasLibro).toBe(1);
  });

  it('order_id desconocido → 200 no-op', async () => {
    const body = { event: 'payment.completed', order_id: 'pedido_9999999_1', tx_id: 'tx_inexistente' };
    const res = await request(app)
      .post('/webhooks/codepay')
      .set('X-Codepay-Signature', firmar(body))
      .send(body);

    expect(res.status).toBe(200);
  });
});
```

- [ ] **Step 5: Correr los tests**

Run: `cd backend && npm test -- webhooks-codepay.test.js`
Expected: 4/4 PASS.

- [ ] **Step 6: Correr toda la suite de backend una vez más**

Run: `cd backend && npm test`
Expected: todas las suites PASS (nada de `app.js` afecta otras rutas).

- [ ] **Step 7: Commit**

```bash
git add backend/src/webhooks/codepay.webhook.routes.js backend/src/app.js backend/tests/webhooks-codepay.test.js
git commit -m "feat(pagos-qr): webhook de confirmación de CodePay con verificación de firma"
```

---

### Task 5: Frontend — modal de cobro QR en Ventas

**Files:**
- Create: `frontend/src/api/pagosQr.js`
- Create: `frontend/src/pages/ventas/components/ModalPagoQr.jsx`
- Modify: `frontend/src/pages/ventas/VentasPage.jsx`
- Modify: `frontend/src/pages/ventas/PedidoPage.jsx`

**Interfaces:**
- Consumes: `GET /api/v1/ventas/:id/pago-qr/estado`, `POST /api/v1/ventas/:id/pago-qr/cancelar` (Task 3); `cobrarVenta`/`crearVentaCompleta` de `frontend/src/api/ventas.js` (sin cambios de firma — ahora pueden devolver `{ pedido, pago_qr }` en vez del pedido directo cuando `metodo_pago==='qr'`).
- Produces: `ModalPagoQr` reutilizable, importado por ambas páginas.

**Nota importante de diseño:** cuando `crearVentaCompleta`/`cobrarVenta` con `metodo_pago:'qr'` fallan o expiran, el pedido YA EXISTE en la base de datos (vuelve a `'pendiente'`/`'listo'`, no se borra). El botón "Reintentar" **nunca** debe volver a llamar `crearVentaCompleta` (crearía un pedido duplicado) — siempre debe llamar `cobrarVenta(pedidoId, { metodo_pago: 'qr', monto_recibido: total })` sobre el pedido ya creado.

- [ ] **Step 1: Crear `frontend/src/api/pagosQr.js`**

```javascript
import api from './cliente';

export const consultarEstadoPagoQr = (pedidoId) =>
  api.get(`/ventas/${pedidoId}/pago-qr/estado`).then((r) => r.data.datos);

export const cancelarPagoQr = (pedidoId) =>
  api.post(`/ventas/${pedidoId}/pago-qr/cancelar`).then((r) => r.data.datos);
```

- [ ] **Step 2: Crear `frontend/src/pages/ventas/components/ModalPagoQr.jsx`**

```jsx
import { useEffect, useState } from 'react';
import { useMutation, useQuery } from '@tanstack/react-query';
import { consultarEstadoPagoQr, cancelarPagoQr } from '../../../api/pagosQr';
import Modal from '../../../components/ui/Modal';

export default function ModalPagoQr({ pedidoId, pagoQr, onClose, onCompletado, onReintentar }) {
  const [restanteMs, setRestanteMs] = useState(() => Math.max(0, new Date(pagoQr.expires_at).getTime() - Date.now()));

  const estadoQuery = useQuery({
    queryKey: ['pago-qr-estado', pedidoId, pagoQr.tx_id],
    queryFn: () => consultarEstadoPagoQr(pedidoId),
    refetchInterval: (query) => {
      const estado = query.state.data?.estado;
      return (!estado || estado === 'pendiente') ? 3000 : false;
    },
  });

  const cancelar = useMutation({
    mutationFn: () => cancelarPagoQr(pedidoId),
    onSuccess: () => onClose(),
  });

  useEffect(() => {
    const intervalo = setInterval(() => {
      setRestanteMs(Math.max(0, new Date(pagoQr.expires_at).getTime() - Date.now()));
    }, 1000);
    return () => clearInterval(intervalo);
  }, [pagoQr.expires_at]);

  const estado = estadoQuery.data?.estado ?? 'pendiente';

  useEffect(() => {
    if (estado === 'completado' && estadoQuery.data?.pedido) {
      onCompletado(estadoQuery.data.pedido);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [estado]);

  const minutos = Math.floor(restanteMs / 60000);
  const segundos = Math.floor((restanteMs % 60000) / 1000);

  return (
    <Modal titulo="Cobro por QR" onClose={onClose} ancho="max-w-sm">
      <div className="space-y-4 text-center">
        {estado === 'pendiente' && (
          <>
            <img
              src={pagoQr.qr_code}
              alt="Código QR de pago"
              className="mx-auto w-56 h-56 sm:w-64 sm:h-64 rounded-xl border border-gray-200 dark:border-gray-700 object-contain"
            />
            <div>
              <p className="text-xs text-gray-400 uppercase tracking-wide mb-1">Total que paga el cliente</p>
              <p className="text-2xl font-bold text-gray-900 dark:text-white">
                Bs {Number(pagoQr.monto_total ?? pagoQr.monto_neto).toFixed(2)}
              </p>
              <p className="text-xs text-gray-400 mt-1">
                Expira en {minutos}:{String(segundos).padStart(2, '0')}
              </p>
            </div>
            <button
              onClick={() => cancelar.mutate()}
              disabled={cancelar.isPending}
              className="px-4 py-2 rounded-xl text-sm text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors disabled:opacity-60"
            >
              Cancelar cobro QR
            </button>
          </>
        )}

        {(estado === 'fallido' || estado === 'expirado') && (
          <div className="space-y-4">
            <p className="text-sm text-red-600">
              {estado === 'expirado' ? 'El QR expiró sin que se registre el pago.' : 'El pago no se completó.'}
            </p>
            <div className="flex justify-center gap-3">
              <button
                onClick={onClose}
                className="px-4 py-2 rounded-xl text-sm text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
              >
                Cambiar método de pago
              </button>
              <button
                onClick={onReintentar}
                className="px-4 py-2 rounded-xl text-sm bg-blue-600 hover:bg-blue-700 text-white font-semibold transition-colors"
              >
                Reintentar
              </button>
            </div>
          </div>
        )}
      </div>
    </Modal>
  );
}
```

- [ ] **Step 3: Integrar en `frontend/src/pages/ventas/VentasPage.jsx`**

Cambiar el import de `api/ventas`:

```javascript
import { getVentas, crearVentaCompleta, cobrarVenta } from '../../api/ventas';
```

Agregar el import del modal nuevo (junto a los otros imports de `./components/...`):

```javascript
import ModalPagoQr from './components/ModalPagoQr';
```

Reemplazar la función `ModalCobrar` completa por:

```jsx
function ModalCobrar({ total, carrito, tipo, mesaId, nombreCliente, sesionCajaId, onClose, onExito }) {
  const [metodo, setMetodo] = useState('efectivo');
  const [error, setError] = useState(null);
  const [pagoQrEstado, setPagoQrEstado] = useState(null); // { pedidoId, pagoQr } | null

  const iniciar = useMutation({
    mutationFn: () => crearVentaCompleta({
      tipo,
      mesa_id: tipo === 'mesa' ? mesaId : undefined,
      nombre_cliente: nombreCliente ?? undefined,
      items: carrito.map((it) => ({ producto_id: it.producto_id, cantidad: it.cantidad, nota: it.nota })),
      metodo_pago: metodo,
      monto_recibido: total,
      sesion_caja_id: sesionCajaId,
    }),
    onSuccess: (resultado) => {
      if (resultado.pago_qr) {
        setPagoQrEstado({ pedidoId: resultado.pedido.id, pagoQr: resultado.pago_qr });
      } else {
        onExito();
      }
    },
    onError: (err) => setError(err?.response?.data?.mensaje ?? 'Error al cobrar'),
  });

  const reintentar = useMutation({
    mutationFn: () => cobrarVenta(pagoQrEstado.pedidoId, { metodo_pago: 'qr', monto_recibido: total }),
    onSuccess: (resultado) => setPagoQrEstado({ pedidoId: resultado.pedido.id, pagoQr: resultado.pago_qr }),
    onError: (err) => setError(err?.response?.data?.mensaje ?? 'Error al generar el QR'),
  });

  if (pagoQrEstado) {
    return (
      <ModalPagoQr
        pedidoId={pagoQrEstado.pedidoId}
        pagoQr={pagoQrEstado.pagoQr}
        onClose={onClose}
        onCompletado={() => onExito()}
        onReintentar={() => reintentar.mutate()}
      />
    );
  }

  return (
    <Modal titulo="Cobrar orden" onClose={onClose} ancho="max-w-sm">
      <div className="space-y-5">
        <div className="bg-gray-50 dark:bg-gray-700/50 rounded-xl p-4 text-center">
          <p className="text-xs text-gray-400 uppercase tracking-wide mb-1">Total a cobrar</p>
          <p className="text-3xl font-bold text-gray-900 dark:text-white">Bs {total.toFixed(2)}</p>
        </div>

        <div>
          <p className="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-2">Método de pago</p>
          <div className="grid grid-cols-2 gap-2">
            {[{ id: 'efectivo', label: 'Efectivo' }, { id: 'qr', label: 'QR / Transferencia' }].map((m) => (
              <button
                key={m.id}
                onClick={() => { setMetodo(m.id); setError(null); }}
                className={`py-3 rounded-xl text-sm font-medium border transition-colors ${
                  metodo === m.id ? 'bg-blue-600 border-blue-600 text-white' : 'border-gray-200 dark:border-gray-600 text-gray-600 dark:text-gray-300 hover:border-blue-400 dark:hover:border-blue-500'
                }`}
              >
                {m.label}
              </button>
            ))}
          </div>
        </div>

        {error && <p className="text-sm text-red-600">{error}</p>}

        <div className="flex justify-end gap-3 pt-1">
          <button onClick={onClose} className="px-4 py-2 rounded-xl text-sm text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors">
            Cancelar
          </button>
          <button
            onClick={() => iniciar.mutate()}
            disabled={iniciar.isPending}
            className="px-5 py-2 rounded-xl text-sm bg-blue-600 hover:bg-blue-700 text-white font-semibold transition-colors disabled:opacity-60"
          >
            {iniciar.isPending ? 'Procesando...' : 'Confirmar cobro'}
          </button>
        </div>
      </div>
    </Modal>
  );
}
```

(Esta reemplaza la función `ModalCobrar` existente al final del archivo — el resto del archivo, incluido el componente `VentasPage` y el resto de modales, no cambia.)

- [ ] **Step 4: Integrar en `frontend/src/pages/ventas/PedidoPage.jsx`**

Agregar el import del modal nuevo:

```javascript
import ModalPagoQr from './components/ModalPagoQr';
```

Reemplazar la función `ModalCobrar` completa por:

```jsx
function ModalCobrar({ total, pedidoId, pedido, config, onClose, onExito }) {
  const [metodo, setMetodo] = useState('efectivo');
  const [error, setError] = useState(null);
  const [pagoQr, setPagoQr] = useState(null);

  const cobrar = useMutation({
    mutationFn: () => cobrarVenta(pedidoId, { metodo_pago: metodo, monto_recibido: total }),
    onSuccess: (resultado) => {
      if (resultado.pago_qr) {
        setPagoQr(resultado.pago_qr);
      } else {
        onExito();
      }
    },
    onError: (err) => setError(err?.response?.data?.mensaje ?? 'Error al cobrar'),
  });

  if (pagoQr) {
    return (
      <ModalPagoQr
        pedidoId={pedidoId}
        pagoQr={pagoQr}
        onClose={onClose}
        onCompletado={() => onExito()}
        onReintentar={() => cobrar.mutate()}
      />
    );
  }

  return (
    <Modal titulo="Cobrar orden" onClose={onClose} ancho="max-w-sm">
      <div className="space-y-5">
        {/* Total */}
        <div className="bg-gray-50 dark:bg-gray-700/50 rounded-xl p-4 text-center">
          <p className="text-xs text-gray-400 uppercase tracking-wide mb-1">Total a cobrar</p>
          <p className="text-3xl font-bold text-gray-900 dark:text-white">Bs {total.toFixed(2)}</p>
        </div>

        {/* Método de pago */}
        <div>
          <p className="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-2">Método de pago</p>
          <div className="grid grid-cols-2 gap-2">
            {[
              { id: 'efectivo', label: 'Efectivo' },
              { id: 'qr',       label: 'QR / Transferencia' },
            ].map(m => (
              <button
                key={m.id}
                onClick={() => { setMetodo(m.id); setError(null); }}
                className={`py-3 rounded-xl text-sm font-medium border transition-colors ${
                  metodo === m.id
                    ? 'bg-blue-600 border-blue-600 text-white'
                    : 'border-gray-200 dark:border-gray-600 text-gray-600 dark:text-gray-300 hover:border-blue-400 dark:hover:border-blue-500'
                }`}
              >
                {m.label}
              </button>
            ))}
          </div>
        </div>

        {error && <p className="text-sm text-red-600">{error}</p>}

        <div className="flex justify-end gap-3 pt-1">
          <button
            onClick={onClose}
            className="px-4 py-2 rounded-xl text-sm text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
          >
            Cancelar
          </button>
          <button
            onClick={() => cobrar.mutate()}
            disabled={cobrar.isPending}
            className="px-5 py-2 rounded-xl text-sm bg-blue-600 hover:bg-blue-700 text-white font-semibold transition-colors disabled:opacity-60"
          >
            {cobrar.isPending ? 'Procesando...' : 'Confirmar cobro'}
          </button>
        </div>
      </div>
    </Modal>
  );
}
```

(El resto de `PedidoPage.jsx` — componente principal, `ModalCancelar`, imports existentes de `cobrarVenta`/`cancelarVenta` — no cambia.)

- [ ] **Step 5: Verificar el build**

Run: `cd frontend && npx vite build`
Expected: build exitoso, sin errores de import ni de sintaxis JSX.

- [ ] **Step 6: Commit**

```bash
git add frontend/src/api/pagosQr.js frontend/src/pages/ventas/components/ModalPagoQr.jsx frontend/src/pages/ventas/VentasPage.jsx frontend/src/pages/ventas/PedidoPage.jsx
git commit -m "feat(pagos-qr): modal de cobro por QR (CodePay) en Ventas, con polling y reintento"
```
