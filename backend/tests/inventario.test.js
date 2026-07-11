const request = require('supertest');
const app = require('../src/app');

describe('Inventario API', () => {
  it('GET /api/v1/inventario sin token → 401', async () => {
    const res = await request(app).get('/api/v1/inventario');
    expect(res.status).toBe(401);
  });
});
