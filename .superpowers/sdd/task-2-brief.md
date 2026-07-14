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

