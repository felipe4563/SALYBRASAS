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

const { Sucursal, ProductoStockSucursal } = require('../src/models');

describe('Stock de productos por sucursal', () => {
  let adminToken, categoriaId, sucursalPrincipalId;

  beforeAll(async () => {
    const login = await request(app).post('/api/v1/auth/login').send({ email: 'admin@restaurante.com', contrasena: process.env.ADMIN_PASSWORD || 'admin123' });
    adminToken = login.body.datos.token;
    const principal = await Sucursal.findOne({ where: { nombre: 'Sucursal Principal' } });
    sucursalPrincipalId = principal.id;

    const catRes = await request(app)
      .post('/api/v1/categorias')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ nombre: 'Categoria Stock Productos Test' });
    categoriaId = catRes.body.datos.id;
  });

  it('crear un producto con stock inicial lo asigna a la sucursal activa del creador', async () => {
    const res = await request(app)
      .post('/api/v1/productos')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ categoria_id: categoriaId, nombre: 'Producto Stock Inicial Test', precio: 12, stock: 30 });

    expect(res.status).toBe(201);

    const fila = await ProductoStockSucursal.findOne({ where: { producto_id: res.body.datos.id, sucursal_id: sucursalPrincipalId } });
    expect(fila.stock).toBe(30);
  });

  it('el listado muestra el stock de la sucursal activa del usuario que consulta', async () => {
    const res = await request(app)
      .get('/api/v1/productos')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(200);
    const creado = res.body.datos.find(p => p.nombre === 'Producto Stock Inicial Test');
    expect(creado.stock).toBe(30);
  });
});
