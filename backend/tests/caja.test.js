const request = require('supertest');
const app = require('../src/app');

describe('Caja API', () => {
  it('GET /api/v1/caja/activa sin token → 401', async () => {
    const res = await request(app).get('/api/v1/caja/activa');
    expect(res.status).toBe(401);
  });
});
