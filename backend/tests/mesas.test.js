const request = require('supertest');
const app = require('../src/app');

describe('Mesas API', () => {
  it('GET /api/v1/mesas sin token → 401', async () => {
    const res = await request(app).get('/api/v1/mesas');
    expect(res.status).toBe(401);
  });

  it('GET /api/v1/areas sin token → 401', async () => {
    const res = await request(app).get('/api/v1/areas');
    expect(res.status).toBe(401);
  });
});
