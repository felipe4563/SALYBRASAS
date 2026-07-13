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

describe('Caja — acceso a todas las sucursales', () => {
  let sucursalX, sucursalY, usuarioTodasId, tokenTodas, usuarioNormalId, tokenNormal;

  beforeAll(async () => {
    sucursalX = await Sucursal.create({ nombre: 'Sucursal Caja Todas X' });
    sucursalY = await Sucursal.create({ nombre: 'Sucursal Caja Todas Y' });

    const rol = await Rol.findOne({ where: { nombre: 'Administrador' } });
    const hash = await bcrypt.hash('clave123', 10);

    const todas = await Usuario.create({
      rol_id: rol.id, nombre: 'Caja Acceso Todas Test', email: 'caja-todas-test@restaurante.com',
      contrasena: hash, acceso_todas_sucursales: 1,
    });
    usuarioTodasId = todas.id;
    const loginTodas = await request(app).post('/api/v1/auth/login').send({ email: 'caja-todas-test@restaurante.com', contrasena: 'clave123' });
    const elegidoTodas = await request(app).post('/api/v1/auth/login/sucursal').send({ pre_token: loginTodas.body.datos.pre_token, sucursal_id: null });
    tokenTodas = elegidoTodas.body.datos.token;

    const cajero = await Rol.findOne({ where: { nombre: 'Cajero' } });
    const normal = await Usuario.create({
      rol_id: cajero.id, nombre: 'Caja Normal Test', email: 'caja-normal-todas-test@restaurante.com',
      contrasena: hash, acceso_todas_sucursales: 0,
    });
    await normal.addSucursal(sucursalX);
    usuarioNormalId = normal.id;
    const loginNormal = await request(app).post('/api/v1/auth/login').send({ email: 'caja-normal-todas-test@restaurante.com', contrasena: 'clave123' });
    tokenNormal = loginNormal.body.datos.token;
  });

  afterAll(async () => {
    await SesionCaja.destroy({ where: { usuario_id: [usuarioTodasId, usuarioNormalId] } });
    await Usuario.destroy({ where: { id: [usuarioTodasId, usuarioNormalId] } });
    await Sucursal.destroy({ where: { id: [sucursalX.id, sucursalY.id] } });
  });

  it('acceso-todas sin sucursal_id → 400 al abrir caja', async () => {
    const res = await request(app)
      .post('/api/v1/caja/abrir')
      .set('Authorization', `Bearer ${tokenTodas}`)
      .send({ monto_apertura: 100 });
    expect(res.status).toBe(400);
  });

  it('acceso-todas con sucursal_id inexistente → 404 al abrir caja', async () => {
    const res = await request(app)
      .post('/api/v1/caja/abrir')
      .set('Authorization', `Bearer ${tokenTodas}`)
      .send({ monto_apertura: 100, sucursal_id: 999999 });
    expect(res.status).toBe(404);
  });

  it('acceso-todas con sucursal_id válido → abre caja en esa sucursal', async () => {
    const res = await request(app)
      .post('/api/v1/caja/abrir')
      .set('Authorization', `Bearer ${tokenTodas}`)
      .send({ monto_apertura: 100, sucursal_id: sucursalX.id });
    expect(res.status).toBe(201);
    expect(res.body.datos.sucursal_id).toBe(sucursalX.id);
  });

  it('acceso-todas puede ver la caja activa de la sucursal elegida via query', async () => {
    const res = await request(app)
      .get('/api/v1/caja/activa')
      .query({ sucursal_id: sucursalX.id })
      .set('Authorization', `Bearer ${tokenTodas}`);
    expect(res.status).toBe(200);
    expect(res.body.datos.sucursal_id).toBe(sucursalX.id);
  });

  it('acceso-todas sin sucursal_id → 400 al consultar caja activa', async () => {
    const res = await request(app)
      .get('/api/v1/caja/activa')
      .set('Authorization', `Bearer ${tokenTodas}`);
    expect(res.status).toBe(400);
  });

  it('usuario normal no puede abrir caja en otra sucursal aunque la mande en el body', async () => {
    const res = await request(app)
      .post('/api/v1/caja/abrir')
      .set('Authorization', `Bearer ${tokenNormal}`)
      .send({ monto_apertura: 50, sucursal_id: sucursalY.id });
    expect(res.status).toBe(201);
    expect(res.body.datos.sucursal_id).toBe(sucursalX.id); // ignora sucursalY, usa la propia
  });
});
