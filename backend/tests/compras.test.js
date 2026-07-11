const request = require('supertest');
const app = require('../src/app');

describe('Compras API', () => {
  it('GET /api/v1/proveedores sin token → 401', async () => {
    const res = await request(app).get('/api/v1/proveedores');
    expect(res.status).toBe(401);
  });

  it('GET /api/v1/compras sin token → 401', async () => {
    const res = await request(app).get('/api/v1/compras');
    expect(res.status).toBe(401);
  });
});
