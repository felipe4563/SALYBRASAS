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

const { Sucursal, Area, Mesa, Categoria, Producto, ProductoStockSucursal, Usuario, Rol, SesionCaja, Pedido, RegistroInventario, LibroCaja } = require('../src/models');
const bcrypt = require('bcryptjs');

describe('Ventas por sucursal', () => {
  let sucursalB, usuarioBId, tokenB, sesionCajaBId, mesaBId, productoId;

  beforeAll(async () => {
    sucursalB = await Sucursal.create({ nombre: 'Sucursal Ventas Test B' });
    const area = await Area.create({ nombre: 'Area Ventas Test B', sucursal_id: sucursalB.id });
    const mesa = await Mesa.create({ area_id: area.id, nombre: 'Mesa Ventas Test B' });
    mesaBId = mesa.id;

    const categoria = await Categoria.create({ nombre: 'Categoria Ventas Test' });
    const producto = await Producto.create({ categoria_id: categoria.id, nombre: 'Producto Ventas Test', precio: 5, stock: 0 });
    productoId = producto.id;
    await ProductoStockSucursal.create({ producto_id: producto.id, sucursal_id: sucursalB.id, stock: 3 });

    const rol = await Rol.findOne({ where: { nombre: 'Cajero' } });
    const hash = await bcrypt.hash('clave123', 10);
    const usuario = await Usuario.create({ rol_id: rol.id, nombre: 'Ventas Sucursal B Test', email: 'ventas-sucursal-b-test@restaurante.com', contrasena: hash });
    await usuario.addSucursal(sucursalB);
    usuarioBId = usuario.id;

    const login = await request(app).post('/api/v1/auth/login').send({ email: 'ventas-sucursal-b-test@restaurante.com', contrasena: 'clave123' });
    tokenB = login.body.datos.token; // única sucursal → login directo

    const sesion = await SesionCaja.create({ usuario_id: usuarioBId, sucursal_id: sucursalB.id, monto_apertura: 0 });
    sesionCajaBId = sesion.id;
  });

  afterAll(async () => {
    await Pedido.destroy({ where: { usuario_id: usuarioBId } });
    await RegistroInventario.destroy({ where: { usuario_id: usuarioBId } });
    await LibroCaja.destroy({ where: { usuario_id: usuarioBId } });
    await SesionCaja.destroy({ where: { id: sesionCajaBId } });
    await ProductoStockSucursal.destroy({ where: { producto_id: productoId } });
    await Producto.destroy({ where: { id: productoId } });
    await Usuario.destroy({ where: { id: usuarioBId } });
    await Mesa.destroy({ where: { id: mesaBId } });
    await Area.destroy({ where: { sucursal_id: sucursalB.id } });
    await Sucursal.destroy({ where: { id: sucursalB.id } });
  });

  it('el pedido hereda la sucursal de la sesión de caja activa', async () => {
    const res = await request(app)
      .post('/api/v1/ventas')
      .set('Authorization', `Bearer ${tokenB}`)
      .send({ mesa_id: mesaBId, tipo: 'mesa', sesion_caja_id: sesionCajaBId });

    expect(res.status).toBe(201);
    expect(res.body.datos.sucursal_id).toBe(sucursalB.id);
  });

  it('una venta completa descuenta del stock de la sucursal del pedido', async () => {
    const res = await request(app)
      .post('/api/v1/ventas/completa')
      .set('Authorization', `Bearer ${tokenB}`)
      .send({
        tipo: 'llevar', metodo_pago: 'efectivo', monto_recibido: 10, sesion_caja_id: sesionCajaBId,
        items: [{ producto_id: productoId, cantidad: 2 }],
      });

    expect(res.status).toBe(201);

    const fila = await ProductoStockSucursal.findOne({ where: { producto_id: productoId, sucursal_id: sucursalB.id } });
    expect(fila.stock).toBe(1); // 3 - 2
  });
});
