const request = require('supertest');
const app = require('../src/app');

describe('Productos API', () => {
  it('GET /api/v1/productos sin token → 401', async () => {
    const res = await request(app).get('/api/v1/productos');
    expect(res.status).toBe(401);
  });

  it('GET /api/v1/categorias sin token → 401', async () => {
    const res = await request(app).get('/api/v1/categorias');
    expect(res.status).toBe(401);
  });
});
