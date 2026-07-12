const request = require('supertest');
const app = require('../src/app');

describe('Caja API', () => {
  it('GET /api/v1/caja/activa sin token → 401', async () => {
    const res = await request(app).get('/api/v1/caja/activa');
    expect(res.status).toBe(401);
  });
});

const { SesionCaja, Sucursal, Usuario, Rol } = require('../src/models');
const bcrypt = require('bcryptjs');

describe('Caja por sucursal', () => {
  let sucursalOtra, usuarioMultiId, tokenMulti, sucursalPrincipalId;

  beforeAll(async () => {
    sucursalOtra = await Sucursal.create({ nombre: 'Sucursal Caja Test' });
    const principal = await Sucursal.findOne({ where: { nombre: 'Sucursal Principal' } });
    sucursalPrincipalId = principal.id;

    const rol = await Rol.findOne({ where: { nombre: 'Cajero' } });
    const hash = await bcrypt.hash('clave123', 10);
    const usuario = await Usuario.create({ rol_id: rol.id, nombre: 'Caja Multi Test', email: 'caja-multi-test@restaurante.com', contrasena: hash });
    await usuario.addSucursales([principal, sucursalOtra]);
    usuarioMultiId = usuario.id;

    const login = await request(app).post('/api/v1/auth/login').send({ email: 'caja-multi-test@restaurante.com', contrasena: 'clave123' });
    const elegido = await request(app).post('/api/v1/auth/login/sucursal').send({ pre_token: login.body.datos.pre_token, sucursal_id: sucursalPrincipalId });
    tokenMulti = elegido.body.datos.token;
  });

  afterAll(async () => {
    await SesionCaja.destroy({ where: { usuario_id: usuarioMultiId } });
    await Usuario.destroy({ where: { id: usuarioMultiId } });
    await Sucursal.destroy({ where: { id: sucursalOtra.id } });
  });

  it('abrir caja graba la sucursal activa del usuario', async () => {
    const res = await request(app)
      .post('/api/v1/caja/abrir')
      .set('Authorization', `Bearer ${tokenMulti}`)
      .send({ monto_apertura: 100 });

    expect(res.status).toBe(201);
    expect(res.body.datos.sucursal_id).toBe(sucursalPrincipalId);
  });

  it('el usuario puede tener como máximo una caja abierta por sucursal, no una global', async () => {
    const res = await request(app)
      .post('/api/v1/caja/abrir')
      .set('Authorization', `Bearer ${tokenMulti}`)
      .send({ monto_apertura: 50 });

    expect(res.status).toBe(409); // ya tiene una abierta en ESTA sucursal (la del test anterior)
  });
});
