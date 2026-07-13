const request = require('supertest');
const app = require('../src/app');

describe('Inventario API', () => {
  it('GET /api/v1/inventario sin token → 401', async () => {
    const res = await request(app).get('/api/v1/inventario');
    expect(res.status).toBe(401);
  });
});

const { Sucursal, Categoria, Producto, ProductoStockSucursal } = require('../src/models');

describe('Inventario manual por sucursal', () => {
  let adminToken, producto;

  beforeAll(async () => {
    const login = await request(app).post('/api/v1/auth/login').send({ email: 'admin@restaurante.com', contrasena: process.env.ADMIN_PASSWORD || 'admin123' });
    adminToken = login.body.datos.token;

    const categoria = await Categoria.create({ nombre: 'Categoria Inventario Test' });
    producto = await Producto.create({ categoria_id: categoria.id, nombre: 'Producto Inventario Test', precio: 4, stock: 0 });
  });

  afterAll(async () => {
    await ProductoStockSucursal.destroy({ where: { producto_id: producto.id } });
    await Producto.destroy({ where: { id: producto.id } });
  });

  it('una entrada manual va al stock de la sucursal activa del admin', async () => {
    const res = await request(app)
      .post('/api/v1/inventario/entrada')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ producto_id: producto.id, cantidad: 20, nota: 'Entrada test' });

    expect(res.status).toBe(201);

    const principal = await Sucursal.findOne({ where: { nombre: 'Sucursal Principal' } });
    const fila = await ProductoStockSucursal.findOne({ where: { producto_id: producto.id, sucursal_id: principal.id } });
    expect(fila.stock).toBe(20);
  });
});
