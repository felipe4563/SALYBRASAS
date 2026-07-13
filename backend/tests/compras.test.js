const request = require('supertest');
const app = require('../src/app');

describe('Compras API', () => {
  it('GET /api/v1/proveedores sin token → 401', async () => {
    const res = await request(app).get('/api/v1/proveedores');
    expect(res.status).toBe(401);
  });

  it('GET /api/v1/compras sin token → 401', async () => {
    const res = await request(app).get('/api/v1/compras');
    expect(res.status).toBe(401);
  });
});

const { Sucursal, Proveedor, Categoria, Producto, ProductoStockSucursal, Compra, DetalleCompra } = require('../src/models');

describe('Compras por sucursal', () => {
  let adminToken, sucursalOtra, proveedor, producto;

  beforeAll(async () => {
    const login = await request(app).post('/api/v1/auth/login').send({ email: 'admin@restaurante.com', contrasena: process.env.ADMIN_PASSWORD || 'admin123' });
    adminToken = login.body.datos.token;

    sucursalOtra = await Sucursal.create({ nombre: 'Sucursal Compras Test' });
    proveedor = await Proveedor.create({ nombre: 'Proveedor Compras Test' });
    const categoria = await Categoria.create({ nombre: 'Categoria Compras Test' });
    producto = await Producto.create({ categoria_id: categoria.id, nombre: 'Producto Compras Test', precio: 8, stock: 0 });
  });

  afterAll(async () => {
    await DetalleCompra.destroy({ where: { producto_id: producto.id } });
    await Compra.destroy({ where: { proveedor_id: proveedor.id } });
    await ProductoStockSucursal.destroy({ where: { producto_id: producto.id } });
    await Producto.destroy({ where: { id: producto.id } });
    await Proveedor.destroy({ where: { id: proveedor.id } });
    await Sucursal.destroy({ where: { id: sucursalOtra.id } });
  });

  it('la compra creada por el admin usa su sucursal activa, no la del body', async () => {
    const res = await request(app)
      .post('/api/v1/compras')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ proveedor_id: proveedor.id, sucursal_id: sucursalOtra.id, items: [{ producto_id: producto.id, cantidad: 5, costo_unitario: 3 }] });

    expect(res.status).toBe(201);
    expect(res.body.datos.sucursal_id).not.toBe(sucursalOtra.id);
    this.compraId = res.body.datos.id;
  });

  it('al recibir la compra, el stock entra a la sucursal de la compra (no a otra)', async () => {
    const crear = await request(app)
      .post('/api/v1/compras')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ proveedor_id: proveedor.id, items: [{ producto_id: producto.id, cantidad: 7, costo_unitario: 3 }] });

    const compraId = crear.body.datos.id;
    const compraSucursalId = crear.body.datos.sucursal_id;

    const recibir = await request(app)
      .put(`/api/v1/compras/${compraId}/recibir`)
      .set('Authorization', `Bearer ${adminToken}`);

    expect(recibir.status).toBe(200);

    const fila = await ProductoStockSucursal.findOne({ where: { producto_id: producto.id, sucursal_id: compraSucursalId } });
    expect(fila.stock).toBeGreaterThanOrEqual(7);

    const filaOtra = await ProductoStockSucursal.findOne({ where: { producto_id: producto.id, sucursal_id: sucursalOtra.id } });
    expect(filaOtra).toBeNull();
  });
});
