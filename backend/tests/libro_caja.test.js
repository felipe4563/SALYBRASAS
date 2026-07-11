const request = require('supertest');
const app = require('../src/app');

describe('Libro Caja API', () => {
  it('GET /api/v1/libro-caja sin token → 401', async () => {
    const res = await request(app).get('/api/v1/libro-caja');
    expect(res.status).toBe(401);
  });
});
