const request = require('supertest');
const app = require('../src/app');
const { Sucursal, Area, Mesa, Categoria, Producto, SesionCaja, Pedido } = require('../src/models');

describe('Reportes filtrados por sucursal', () => {
  let adminToken, sucursalOtra, pedidoOtraSucursalId;

  beforeAll(async () => {
    const login = await request(app).post('/api/v1/auth/login').send({ email: 'admin@restaurante.com', contrasena: process.env.ADMIN_PASSWORD || 'admin123' });
    adminToken = login.body.datos.token;

    sucursalOtra = await Sucursal.create({ nombre: 'Sucursal Reportes Test' });
    const categoria = await Categoria.create({ nombre: 'Categoria Reportes Test' });
    const producto = await Producto.create({ categoria_id: categoria.id, nombre: 'Producto Reportes Test', precio: 6, stock: null });
    const sesion = await SesionCaja.create({ usuario_id: 1, sucursal_id: sucursalOtra.id, monto_apertura: 0 });
    const pedido = await Pedido.create({
      sucursal_id: sucursalOtra.id, usuario_id: 1, sesion_caja_id: sesion.id, tipo: 'llevar',
      estado: 'completado', total: 6,
    });
    pedidoOtraSucursalId = pedido.id;

    this._cleanup = { producto, categoria, sesion, pedido };
  });

  afterAll(async () => {
    await Pedido.destroy({ where: { id: pedidoOtraSucursalId } });
    await SesionCaja.destroy({ where: { sucursal_id: sucursalOtra.id } });
    await Sucursal.destroy({ where: { id: sucursalOtra.id } });
  });

  it('el reporte de ventas del admin (sucursal Principal) no incluye pedidos de otra sucursal', async () => {
    const res = await request(app)
      .get('/api/v1/reportes/ventas')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(200);
    expect(res.body.datos.find(p => p.id === pedidoOtraSucursalId)).toBeUndefined();
  });
});
