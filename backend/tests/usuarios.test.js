const request = require('supertest');
const app = require('../src/app');

describe('Usuarios API', () => {
  it('GET /api/v1/usuarios sin token → 401', async () => {
    const res = await request(app).get('/api/v1/usuarios');
    expect(res.status).toBe(401);
    expect(res.body.ok).toBe(false);
  });
});
