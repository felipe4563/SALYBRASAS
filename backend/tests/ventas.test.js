const request = require('supertest');
const app = require('../src/app');

describe('Ventas API', () => {
  it('GET /api/v1/ventas sin token → 401', async () => {
    const res = await request(app).get('/api/v1/ventas');
    expect(res.status).toBe(401);
  });

  it('POST /api/v1/ventas/completa sin token → 401', async () => {
    const res = await request(app).post('/api/v1/ventas/completa').send({});
    expect(res.status).toBe(401);
  });
});
