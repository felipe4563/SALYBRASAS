# Multi-sucursal Fase 5: Caja e ingreso de stock para usuarios acceso-todas — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Un usuario con `acceso_todas_sucursales` puede elegir explícitamente
la sucursal destino para abrir caja, cargar/ajustar stock, o asignar stock
inicial al crear un producto — hoy esas tres acciones están bloqueadas
(403) o descartan el valor en silencio para ese tipo de usuario.

**Architecture:** Se agrega una función `_resolverSucursal(req)` en los
controllers de `caja` e `inventario` que devuelve `req.usuario.sucursal_id`
para un usuario normal, o valida y devuelve un `sucursal_id` explícito del
body/query cuando el usuario es acceso-todas. Se quita el middleware
`requiereSucursalActiva` de las rutas de escritura afectadas (ahora la
validación vive en el controller, que sí distingue los dos casos). En el
frontend, cada pantalla afectada agrega un `<select>` de sucursal visible
solo para usuarios acceso-todas, replicando el patrón ya usado en
`TabProductos` de `ProductosPage.jsx`.

**Tech Stack:** Node.js/Express/Sequelize (backend), React 18 + Vite +
TanStack Query + Zustand (frontend), Jest + Supertest (tests backend, hit
la base de datos real de desarrollo, sin mocks). No hay test runner de
frontend — la verificación de las tareas de frontend es `npx vite build`
más trazado manual del código.

## Global Constraints

- Solo usuarios con `acceso_todas_sucursales` (sucursal activa `null`) ven
  o pueden usar el selector de sucursal destino. Un usuario de una sola
  sucursal nunca puede operar sobre otra sucursal, ni mandando
  `sucursal_id` explícito en el body — el backend debe ignorar ese campo
  para usuarios no acceso-todas y usar siempre `req.usuario.sucursal_id`.
- Cuando un usuario acceso-todas no manda `sucursal_id` en una acción que
  lo requiere: 400 `{ ok: false, mensaje: 'sucursal_id es requerido' }`.
  Cuando manda un `sucursal_id` que no existe: 404
  `{ ok: false, mensaje: 'Sucursal no encontrada' }`.
- No se cambian las firmas de los `service` (`caja.service.js`,
  `inventario.service.js`, `stock.service.js`) — ya reciben `sucursal_id`
  como parámetro explícito. Solo cambia de dónde sale ese valor en el
  controller.
- No se toca `GET /caja` (historial de sesiones) ni `actualizarProducto` —
  fuera de alcance según la spec.

---

### Task 1: Backend — Caja: sucursal explícita para acceso-todas

**Files:**
- Modify: `backend/src/modules/caja/caja.controller.js`
- Modify: `backend/src/modules/caja/caja.routes.js`
- Test: `backend/tests/caja.test.js`

**Interfaces:**
- Consumes: `svc.obtenerActiva(usuario_id, sucursal_id)`,
  `svc.abrir(usuario_id, sucursal_id, monto_apertura)` — firmas sin
  cambios, ya declaradas en `caja.service.js`.
- Produces: `_resolverSucursal(req)` (async, lanza error con `.status` si
  falla) — usado internamente por `caja.controller.js` en esta tarea; el
  mismo patrón (no la misma función, cada módulo tiene la suya) se repite
  en Task 2 para `inventario.controller.js`.

- [ ] **Step 1: Escribir los tests que fallan**

Agregar al final de `backend/tests/caja.test.js` (después del bloque
`describe('Caja por sucursal', ...)` ya existente):

```javascript
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
```

- [ ] **Step 2: Correr los tests y verificar que fallan**

Run: `cd backend && npx jest caja.test.js -v`
Expected: FAIL — hoy `/caja/abrir` sin `sucursal_id` responde 403
(bloqueado por `requiereSucursalActiva`), no 400; `/caja/activa` sin
query responde con `sesion: null` (200), no 400.

- [ ] **Step 3: Implementar `_resolverSucursal` y actualizar el controller**

Reemplazar el contenido de `backend/src/modules/caja/caja.controller.js`:

```javascript
const svc = require('./caja.service');
const { Sucursal } = require('../../models');

function _alcance(req) {
  return { sucursal_id: req.usuario.sucursal_id, acceso_todas: req.usuario.acceso_todas };
}

async function _resolverSucursal(req) {
  if (!req.usuario.acceso_todas) return req.usuario.sucursal_id;
  const sucursal_id = req.body.sucursal_id || req.query.sucursal_id;
  if (!sucursal_id) {
    throw Object.assign(new Error('sucursal_id es requerido'), { status: 400 });
  }
  const existe = await Sucursal.findByPk(sucursal_id);
  if (!existe) throw Object.assign(new Error('Sucursal no encontrada'), { status: 404 });
  return sucursal_id;
}

async function obtenerActiva(req, res, next) {
  try {
    const sucursal_id = await _resolverSucursal(req);
    const sesion = await svc.obtenerActiva(req.usuario.id, sucursal_id);
    res.json({ ok: true, datos: sesion });
  } catch (err) { next(err); }
}

async function listar(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listar(_alcance(req)) }); }
  catch (err) { next(err); }
}

async function obtener(req, res, next) {
  try { res.json({ ok: true, datos: await svc.obtener(req.params.id, _alcance(req)) }); }
  catch (err) { next(err); }
}

async function abrir(req, res, next) {
  try {
    const { monto_apertura } = req.body;
    const sucursal_id = await _resolverSucursal(req);
    res.status(201).json({ ok: true, datos: await svc.abrir(req.usuario.id, sucursal_id, monto_apertura) });
  } catch (err) { next(err); }
}

async function registrarGasto(req, res, next) {
  try {
    const { descripcion, monto } = req.body;
    if (!descripcion || monto === undefined) return res.status(400).json({ ok: false, mensaje: 'descripcion y monto son requeridos' });
    res.status(201).json({ ok: true, datos: await svc.registrarGasto(req.params.id, req.usuario.id, { descripcion, monto }, _alcance(req)) });
  } catch (err) { next(err); }
}

async function listarGastos(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listarGastos(req.params.id, _alcance(req)) }); }
  catch (err) { next(err); }
}

async function cerrar(req, res, next) {
  try {
    const { denominaciones = [] } = req.body;
    res.json({ ok: true, datos: await svc.cerrar(req.params.id, req.usuario.id, denominaciones, _alcance(req)) });
  } catch (err) { next(err); }
}

async function reporte(req, res, next) {
  try { res.json({ ok: true, datos: await svc.reporte(req.params.id, _alcance(req)) }); }
  catch (err) { next(err); }
}

module.exports = { obtenerActiva, listar, obtener, abrir, registrarGasto, listarGastos, cerrar, reporte };
```

(Solo `obtenerActiva` y `abrir` cambian de contenido; el resto se copia
tal cual del archivo actual — no lo reescribas de memoria, es una
transcripción.)

En `backend/src/modules/caja/caja.routes.js`, quitar el import y el uso
de `requiereSucursalActiva`:

```javascript
const { Router } = require('express');
const ctrl = require('./caja.controller');
const auth = require('../../middlewares/auth');
const { verificarPermiso } = require('../../middlewares/permisos');

const router = Router();
router.use(auth);

router.get('/activa', verificarPermiso('caja', 'ver'), ctrl.obtenerActiva);
router.get('/', verificarPermiso('caja', 'ver'), ctrl.listar);
router.post('/abrir', verificarPermiso('caja', 'abrir'), ctrl.abrir);
router.get('/:id', verificarPermiso('caja', 'ver'), ctrl.obtener);
router.get('/:id/gastos', verificarPermiso('caja', 'ver'), ctrl.listarGastos);
router.post('/:id/gastos', verificarPermiso('caja', 'ver'), ctrl.registrarGasto);
router.post('/:id/cerrar', verificarPermiso('caja', 'cerrar'), ctrl.cerrar);
router.get('/:id/reporte', verificarPermiso('caja', 'ver'), ctrl.reporte);

module.exports = router;
```

- [ ] **Step 4: Correr los tests y verificar que pasan**

Run: `cd backend && npx jest caja.test.js -v`
Expected: PASS — todos los tests del archivo, incluidos los ya
existentes de la sección "Caja por sucursal".

- [ ] **Step 5: Commit**

```bash
git add backend/src/modules/caja/caja.controller.js backend/src/modules/caja/caja.routes.js backend/tests/caja.test.js
git commit -m "feat(caja): permite a usuarios acceso-todas elegir sucursal para abrir/ver caja"
```

---

### Task 2: Backend — Inventario: sucursal explícita para acceso-todas

**Files:**
- Modify: `backend/src/modules/inventario/inventario.controller.js`
- Modify: `backend/src/modules/inventario/inventario.routes.js`
- Test: `backend/tests/inventario.test.js`

**Interfaces:**
- Consumes: `svc.entrada(usuario_id, sucursal_id, body)`,
  `svc.salida(usuario_id, sucursal_id, body)`,
  `svc.ajuste(usuario_id, sucursal_id, body)` — firmas sin cambios.
- Produces: nada consumido por otras tareas de este plan.

- [ ] **Step 1: Escribir los tests que fallan**

Revisar primero el inicio de `backend/tests/inventario.test.js` (imports
y setup existentes) para reusar sus fixtures de producto/rol si ya
existen; si no hay un usuario acceso-todas ya creado en ese archivo,
agregar al final el siguiente bloque (ajustando los imports del archivo
si `Sucursal`, `Rol`, `bcrypt` no están ya importados arriba):

```javascript
describe('Inventario — acceso a todas las sucursales', () => {
  let sucursalX, productoTest, usuarioTodasId, tokenTodas, usuarioNormalId, tokenNormal;

  beforeAll(async () => {
    sucursalX = await Sucursal.create({ nombre: 'Sucursal Inventario Todas X' });
    const categoria = await Categoria.create({ nombre: 'Categoria Inventario Todas Test' });
    productoTest = await Producto.create({ categoria_id: categoria.id, nombre: 'Producto Inventario Todas Test', precio: 5, stock: 0 });

    const rolAdmin = await Rol.findOne({ where: { nombre: 'Administrador' } });
    const hash = await bcrypt.hash('clave123', 10);

    const todas = await Usuario.create({
      rol_id: rolAdmin.id, nombre: 'Inventario Acceso Todas Test', email: 'inventario-todas-test@restaurante.com',
      contrasena: hash, acceso_todas_sucursales: 1,
    });
    usuarioTodasId = todas.id;
    const loginTodas = await request(app).post('/api/v1/auth/login').send({ email: 'inventario-todas-test@restaurante.com', contrasena: 'clave123' });
    const elegidoTodas = await request(app).post('/api/v1/auth/login/sucursal').send({ pre_token: loginTodas.body.datos.pre_token, sucursal_id: null });
    tokenTodas = elegidoTodas.body.datos.token;

    const principal = await Sucursal.findOne({ where: { nombre: 'Sucursal Principal' } });
    const normal = await Usuario.create({
      rol_id: rolAdmin.id, nombre: 'Inventario Normal Todas Test', email: 'inventario-normal-todas-test@restaurante.com',
      contrasena: hash, acceso_todas_sucursales: 0,
    });
    await normal.addSucursal(principal);
    usuarioNormalId = normal.id;
    const loginNormal = await request(app).post('/api/v1/auth/login').send({ email: 'inventario-normal-todas-test@restaurante.com', contrasena: 'clave123' });
    tokenNormal = loginNormal.body.datos.token;
  });

  afterAll(async () => {
    await RegistroInventario.destroy({ where: { producto_id: productoTest.id } });
    await ProductoStockSucursal.destroy({ where: { producto_id: productoTest.id } });
    await Producto.destroy({ where: { id: productoTest.id } });
    await Usuario.destroy({ where: { id: [usuarioTodasId, usuarioNormalId] } });
    await Sucursal.destroy({ where: { id: sucursalX.id } });
  });

  it('acceso-todas sin sucursal_id → 400 al registrar entrada', async () => {
    const res = await request(app)
      .post('/api/v1/inventario/entrada')
      .set('Authorization', `Bearer ${tokenTodas}`)
      .send({ producto_id: productoTest.id, cantidad: 10 });
    expect(res.status).toBe(400);
  });

  it('acceso-todas con sucursal_id inexistente → 404 al registrar entrada', async () => {
    const res = await request(app)
      .post('/api/v1/inventario/entrada')
      .set('Authorization', `Bearer ${tokenTodas}`)
      .send({ producto_id: productoTest.id, cantidad: 10, sucursal_id: 999999 });
    expect(res.status).toBe(404);
  });

  it('acceso-todas con sucursal_id válido → registra entrada en esa sucursal', async () => {
    const res = await request(app)
      .post('/api/v1/inventario/entrada')
      .set('Authorization', `Bearer ${tokenTodas}`)
      .send({ producto_id: productoTest.id, cantidad: 10, sucursal_id: sucursalX.id });
    expect(res.status).toBe(201);

    const stock = await ProductoStockSucursal.findOne({ where: { producto_id: productoTest.id, sucursal_id: sucursalX.id } });
    expect(stock.stock).toBe(10);
  });

  it('acceso-todas con sucursal_id válido → registra ajuste en esa sucursal', async () => {
    const res = await request(app)
      .post('/api/v1/inventario/ajuste')
      .set('Authorization', `Bearer ${tokenTodas}`)
      .send({ producto_id: productoTest.id, cantidad: 25, sucursal_id: sucursalX.id });
    expect(res.status).toBe(201);

    const stock = await ProductoStockSucursal.findOne({ where: { producto_id: productoTest.id, sucursal_id: sucursalX.id } });
    expect(stock.stock).toBe(25);
  });

  it('usuario normal no puede cargar stock en otra sucursal aunque la mande en el body', async () => {
    const principal = await Sucursal.findOne({ where: { nombre: 'Sucursal Principal' } });
    const res = await request(app)
      .post('/api/v1/inventario/entrada')
      .set('Authorization', `Bearer ${tokenNormal}`)
      .send({ producto_id: productoTest.id, cantidad: 5, sucursal_id: sucursalX.id });
    expect(res.status).toBe(201);

    const stockPropia = await ProductoStockSucursal.findOne({ where: { producto_id: productoTest.id, sucursal_id: principal.id } });
    expect(stockPropia.stock).toBe(5); // fue a su propia sucursal, no a sucursalX
  });
});
```

Antes de pegar este bloque, revisar los imports existentes al inicio de
`backend/tests/inventario.test.js` — agregar los que falten
(`ProductoStockSucursal`, `Sucursal`, `Categoria`, `Rol`, `bcrypt`,
`request`, `app`) siguiendo el mismo estilo que ya usa el archivo.

- [ ] **Step 2: Correr los tests y verificar que fallan**

Run: `cd backend && npx jest inventario.test.js -v`
Expected: FAIL — hoy `/inventario/entrada` sin `sucursal_id` responde
403 (bloqueado por `requiereSucursalActiva`), no 400.

- [ ] **Step 3: Implementar `_resolverSucursal` y actualizar el controller**

Reemplazar el contenido de
`backend/src/modules/inventario/inventario.controller.js`:

```javascript
const svc = require('./inventario.service');
const { Sucursal } = require('../../models');

function _alcance(req) {
  return { sucursal_id: req.usuario.sucursal_id, acceso_todas: req.usuario.acceso_todas };
}

async function _resolverSucursal(req) {
  if (!req.usuario.acceso_todas) return req.usuario.sucursal_id;
  const { sucursal_id } = req.body;
  if (!sucursal_id) {
    throw Object.assign(new Error('sucursal_id es requerido'), { status: 400 });
  }
  const existe = await Sucursal.findByPk(sucursal_id);
  if (!existe) throw Object.assign(new Error('Sucursal no encontrada'), { status: 404 });
  return sucursal_id;
}

async function listar(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listar({ ...req.query, ..._alcance(req) }) }); }
  catch (err) { next(err); }
}

async function listarPorProducto(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listarPorProducto(req.params.id, _alcance(req)) }); }
  catch (err) { next(err); }
}

async function entrada(req, res, next) {
  try {
    const { producto_id, cantidad } = req.body;
    if (!producto_id || !cantidad) return res.status(400).json({ ok: false, mensaje: 'producto_id y cantidad son requeridos' });
    const sucursal_id = await _resolverSucursal(req);
    res.status(201).json({ ok: true, datos: await svc.entrada(req.usuario.id, sucursal_id, req.body) });
  } catch (err) { next(err); }
}

async function salida(req, res, next) {
  try {
    const { producto_id, cantidad } = req.body;
    if (!producto_id || !cantidad) return res.status(400).json({ ok: false, mensaje: 'producto_id y cantidad son requeridos' });
    const sucursal_id = await _resolverSucursal(req);
    res.status(201).json({ ok: true, datos: await svc.salida(req.usuario.id, sucursal_id, req.body) });
  } catch (err) { next(err); }
}

async function ajuste(req, res, next) {
  try {
    const { producto_id, cantidad } = req.body;
    if (!producto_id || cantidad === undefined) return res.status(400).json({ ok: false, mensaje: 'producto_id y cantidad son requeridos' });
    const sucursal_id = await _resolverSucursal(req);
    res.status(201).json({ ok: true, datos: await svc.ajuste(req.usuario.id, sucursal_id, req.body) });
  } catch (err) { next(err); }
}

module.exports = { listar, listarPorProducto, entrada, salida, ajuste };
```

En `backend/src/modules/inventario/inventario.routes.js`, quitar el
import y uso de `requiereSucursalActiva`:

```javascript
const { Router } = require('express');
const ctrl = require('./inventario.controller');
const auth = require('../../middlewares/auth');
const { verificarPermiso } = require('../../middlewares/permisos');

const router = Router();
router.use(auth);

router.get('/', verificarPermiso('inventario', 'ver'), ctrl.listar);
router.get('/producto/:id', verificarPermiso('inventario', 'ver'), ctrl.listarPorProducto);
router.post('/entrada', verificarPermiso('inventario', 'entrada'), ctrl.entrada);
router.post('/salida', verificarPermiso('inventario', 'salida'), ctrl.salida);
router.post('/ajuste', verificarPermiso('inventario', 'ajustar'), ctrl.ajuste);

module.exports = router;
```

- [ ] **Step 4: Correr los tests y verificar que pasan**

Run: `cd backend && npx jest inventario.test.js -v`
Expected: PASS — todos los tests del archivo.

- [ ] **Step 5: Commit**

```bash
git add backend/src/modules/inventario/inventario.controller.js backend/src/modules/inventario/inventario.routes.js backend/tests/inventario.test.js
git commit -m "feat(inventario): permite a usuarios acceso-todas elegir sucursal destino en entrada/salida/ajuste"
```

---

### Task 3: Backend — Productos: sucursal explícita para stock inicial

**Files:**
- Modify: `backend/src/modules/productos/productos.service.js:62-70`
- Test: `backend/tests/productos.test.js`

**Interfaces:**
- Consumes: `ajustarStockSucursal({ producto_id, sucursal_id, tipo, cantidad, usuario_id, nota })` — sin cambios.
- Produces: `crearProducto` ahora acepta `sucursal_id` en el primer
  argumento (payload) — usado por el frontend en Task 6.

- [ ] **Step 1: Escribir los tests que fallan**

Revisar primero el inicio de `backend/tests/productos.test.js` para
reusar imports/fixtures existentes (`Sucursal`, `Rol`, `bcrypt`, `request`,
`app`, `ProductoStockSucursal` si ya están importados). Agregar al final:

```javascript
describe('Productos — stock inicial con acceso a todas las sucursales', () => {
  let categoriaId, sucursalX, usuarioTodasId, tokenTodas;

  beforeAll(async () => {
    const categoria = await Categoria.create({ nombre: 'Categoria Stock Inicial Todas Test' });
    categoriaId = categoria.id;
    sucursalX = await Sucursal.create({ nombre: 'Sucursal Stock Inicial Todas X' });

    const rolAdmin = await Rol.findOne({ where: { nombre: 'Administrador' } });
    const hash = await bcrypt.hash('clave123', 10);
    const todas = await Usuario.create({
      rol_id: rolAdmin.id, nombre: 'Productos Acceso Todas Test', email: 'productos-todas-test@restaurante.com',
      contrasena: hash, acceso_todas_sucursales: 1,
    });
    usuarioTodasId = todas.id;
    const login = await request(app).post('/api/v1/auth/login').send({ email: 'productos-todas-test@restaurante.com', contrasena: 'clave123' });
    const elegido = await request(app).post('/api/v1/auth/login/sucursal').send({ pre_token: login.body.datos.pre_token, sucursal_id: null });
    tokenTodas = elegido.body.datos.token;
  });

  afterAll(async () => {
    await Producto.destroy({ where: { categoria_id: categoriaId } });
    await Categoria.destroy({ where: { id: categoriaId } });
    await Usuario.destroy({ where: { id: usuarioTodasId } });
    await Sucursal.destroy({ where: { id: sucursalX.id } });
  });

  it('acceso-todas creando producto con stock y sin sucursal_id → 400', async () => {
    const res = await request(app)
      .post('/api/v1/productos')
      .set('Authorization', `Bearer ${tokenTodas}`)
      .send({ categoria_id: categoriaId, nombre: 'Producto Sin Sucursal Test', precio: 10, stock: 20 });
    expect(res.status).toBe(400);
  });

  it('acceso-todas creando producto con stock y sucursal_id válido → asigna el stock ahí', async () => {
    const res = await request(app)
      .post('/api/v1/productos')
      .set('Authorization', `Bearer ${tokenTodas}`)
      .send({ categoria_id: categoriaId, nombre: 'Producto Con Sucursal Test', precio: 10, stock: 20, sucursal_id: sucursalX.id });
    expect(res.status).toBe(201);

    const stock = await ProductoStockSucursal.findOne({ where: { producto_id: res.body.datos.id, sucursal_id: sucursalX.id } });
    expect(stock.stock).toBe(20);
  });

  it('acceso-todas creando producto sin stock no requiere sucursal_id', async () => {
    const res = await request(app)
      .post('/api/v1/productos')
      .set('Authorization', `Bearer ${tokenTodas}`)
      .send({ categoria_id: categoriaId, nombre: 'Producto Sin Stock Inicial Test', precio: 10 });
    expect(res.status).toBe(201);
  });
});
```

- [ ] **Step 2: Correr los tests y verificar que fallan**

Run: `cd backend && npx jest productos.test.js -v`
Expected: FAIL — hoy el stock se descarta en silencio (la respuesta es
201, no 400, y no queda ninguna fila en `producto_stock_sucursal`).

- [ ] **Step 3: Implementar el cambio en `crearProducto`**

En `backend/src/modules/productos/productos.service.js`, reemplazar la
función `crearProducto` (líneas 62-70) por:

```javascript
async function crearProducto({ categoria_id, nombre, codigo_barras, codigo, precio, costo, stock, sucursal_id, es_vendible, imagen }, alcance) {
  const producto = await Producto.create({ categoria_id, nombre, codigo_barras, codigo, precio, costo, stock: stock !== undefined ? 0 : null, es_vendible, imagen });

  if (stock !== undefined && stock !== null) {
    const sucursalDestino = alcance.acceso_todas ? sucursal_id : alcance.sucursal_id;
    if (alcance.acceso_todas && !sucursalDestino) {
      throw Object.assign(new Error('sucursal_id es requerido para asignar stock inicial'), { status: 400 });
    }
    await ajustarStockSucursal({ producto_id: producto.id, sucursal_id: sucursalDestino, tipo: 'ajuste', cantidad: stock, usuario_id: alcance.usuario_id, nota: 'Stock inicial' });
  }

  return obtenerProducto(producto.id, alcance);
}
```

- [ ] **Step 4: Correr los tests y verificar que pasan**

Run: `cd backend && npx jest productos.test.js -v`
Expected: PASS — todos los tests del archivo.

- [ ] **Step 5: Commit**

```bash
git add backend/src/modules/productos/productos.service.js backend/tests/productos.test.js
git commit -m "fix(productos): exige sucursal_id para stock inicial de usuarios acceso-todas en vez de descartarlo"
```

---

### Task 4: Frontend — Caja: selector de sucursal para acceso-todas

**Files:**
- Modify: `frontend/src/api/caja.js`
- Modify: `frontend/src/pages/caja/CajaPage.jsx`

**Interfaces:**
- Consumes: `getSucursales()` de `frontend/src/api/sucursales.js` (ya
  existe, sin cambios); `GET /caja/activa?sucursal_id=` y
  `POST /caja/abrir { sucursal_id }` de Task 1.

- [ ] **Step 1: Actualizar `frontend/src/api/caja.js`**

Reemplazar `getCajaActiva` y `abrirCaja`:

```javascript
export const getCajaActiva = (sucursal_id) =>
  api.get('/caja/activa', { params: sucursal_id ? { sucursal_id } : {} }).then(r => r.data.datos).catch(() => null);

export const abrirCaja = (monto_apertura, sucursal_id) =>
  api.post('/caja/abrir', { monto_apertura, ...(sucursal_id ? { sucursal_id } : {}) }).then(r => r.data.datos);
```

El resto del archivo (`getSesiones`, `getSesion`, `cerrarCaja`,
`getReporte`, `registrarGasto`, `getGastos`) no cambia.

- [ ] **Step 2: Agregar el selector de sucursal en `CajaPage.jsx`**

En `frontend/src/pages/caja/CajaPage.jsx`, agregar el import de
`getSucursales`:

```javascript
import { getSucursales } from '../../api/sucursales';
```

Dentro de `export default function CajaPage()`, después de la línea
`const { usuario } = useAuth();`, agregar:

```javascript
const accesoTodas = usuario?.sucursal_activa?.id == null;
const [sucursalId, setSucursalId] = useState('');

const { data: sucursales = [] } = useQuery({
  queryKey: ['sucursales'],
  queryFn: getSucursales,
  enabled: accesoTodas,
});
```

Modificar la query de `sesion` (reemplaza la actual `useQuery` de
`caja-activa`):

```javascript
const { data: sesion, isLoading } = useQuery({
  queryKey: ['caja-activa', accesoTodas ? sucursalId : null],
  queryFn: () => getCajaActiva(accesoTodas ? sucursalId : undefined),
  enabled: puedeVer && (!accesoTodas || !!sucursalId),
});
```

Modificar `invalidar` para incluir la clave con sucursal:

```javascript
const invalidar = useCallback(() => {
  qc.invalidateQueries({ queryKey: ['caja-activa'] });
  qc.invalidateQueries({ queryKey: ['caja-sesiones'] });
  if (sesion?.id) qc.invalidateQueries({ queryKey: ['caja-gastos', sesion.id] });
  setUltimaActualizacion(new Date());
}, [qc, sesion?.id]);
```

(No cambia — `invalidateQueries({ queryKey: ['caja-activa'] })` ya
invalida cualquier query cuya key empiece con `'caja-activa'`, incluida
la nueva `['caja-activa', sucursalId]`, por el matching parcial de
TanStack Query.)

Justo después del bloque `if (isLoading) { ... }` (antes del
`return (<div className="space-y-6 max-w-5xl">`), agregar el selector y
el guard de "elegí sucursal":

```javascript
  const selectorSucursal = accesoTodas && (
    <div className="flex items-center gap-3 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl px-4 py-3">
      <label className="text-sm font-medium text-gray-600 dark:text-gray-300 shrink-0">Sucursal</label>
      <select
        value={sucursalId}
        onChange={e => setSucursalId(e.target.value)}
        className="flex-1 bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-lg px-3 py-1.5 text-sm text-gray-800 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500"
      >
        <option value="">Elegí una sucursal...</option>
        {sucursales.map(s => <option key={s.id} value={s.id}>{s.nombre}</option>)}
      </select>
    </div>
  );

  if (accesoTodas && !sucursalId) {
    return (
      <div className="space-y-6 max-w-5xl">
        <h1 className="text-xl font-bold text-gray-800 dark:text-gray-100">Caja</h1>
        {selectorSucursal}
        <div className="flex flex-col items-center justify-center py-16 gap-3 text-gray-400 dark:text-gray-600">
          <Wallet className="w-10 h-10" />
          <p className="text-sm">Elegí una sucursal para ver y operar su caja</p>
        </div>
      </div>
    );
  }
```

Y en el `return` principal, agregar `{selectorSucursal}` justo debajo de
la cabecera existente (`<div className="flex items-center justify-between">...</div>`,
líneas 135-145):

```javascript
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold text-gray-800 dark:text-gray-100">Caja</h1>
        {!sesion && puedeAbrir && (
          <button
            onClick={() => setModalAbrir(true)}
            className="flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-xl text-sm font-semibold transition-colors"
          >
            <Plus className="w-4 h-4" /> Abrir Caja
          </button>
        )}
      </div>

      {selectorSucursal}
```

Actualizar el render de `ModalAbrirCaja` para pasarle `sucursalId`:

```javascript
      {modalAbrir && (
        <ModalAbrirCaja
          sucursalId={accesoTodas ? sucursalId : undefined}
          onClose={() => setModalAbrir(false)}
          onExito={() => { setModalAbrir(false); invalidar(); }}
        />
      )}
```

Y actualizar `ModalAbrirCaja` para recibir y usar esa prop:

```javascript
function ModalAbrirCaja({ sucursalId, onClose, onExito }) {
  const [monto, setMonto] = useState('');
  const [error, setError] = useState(null);

  const abrir = useMutation({
    mutationFn: () => abrirCaja(parseFloat(monto) || 0, sucursalId),
    onSuccess: onExito,
    onError: (err) => setError(err?.response?.data?.mensaje ?? 'Error al abrir la caja'),
  });
  // resto de la función sin cambios
```

- [ ] **Step 3: Verificar con build**

Run: `cd frontend && npx vite build`
Expected: build exitoso, sin errores de sintaxis ni de imports.

Verificación manual de código (no hay test runner de frontend): trazar
que para un usuario normal (`accesoTodas === false`) el comportamiento es
idéntico al actual — `selectorSucursal` es `false` (no renderiza nada),
`getCajaActiva(undefined)` no manda `params`, `abrirCaja(monto, undefined)`
no manda `sucursal_id` — igual que el código antes de esta tarea.

- [ ] **Step 4: Commit**

```bash
git add frontend/src/api/caja.js frontend/src/pages/caja/CajaPage.jsx
git commit -m "feat(caja): selector de sucursal para usuarios acceso-todas en la pantalla de Caja"
```

---

### Task 5: Frontend — Inventario: selector de sucursal para acceso-todas

**Files:**
- Modify: `frontend/src/pages/inventario/InventarioPage.jsx`

**Interfaces:**
- Consumes: `getSucursales()` (sin cambios); `registrarEntrada/Salida/Ajuste(datos)`
  de `frontend/src/api/inventario.js` (sin cambios de firma — ya aceptan
  un objeto genérico, solo se le agrega la clave `sucursal_id` cuando
  corresponde).

- [ ] **Step 1: Agregar `accesoTodas` y la carga de sucursales**

En `frontend/src/pages/inventario/InventarioPage.jsx`, agregar imports:

```javascript
import { useAuthStore } from '../../store/authStore';
import { getSucursales } from '../../api/sucursales';
```

Dentro de `export default function InventarioPage()`, después de
`const qc = useQueryClient();`, agregar:

```javascript
const accesoTodas = useAuthStore((s) => s.usuario?.sucursal_activa?.id == null);
const { data: sucursales = [] } = useQuery({
  queryKey: ['sucursales'],
  queryFn: getSucursales,
  enabled: accesoTodas,
});
```

- [ ] **Step 2: Pasar `accesoTodas`/`sucursales` al modal y usarlos en el submit**

Modificar el render de `ModalMovimiento` (dentro del `return` de
`InventarioPage`, donde dice `{modal && (<ModalMovimiento ...>)}`):

```javascript
      {modal && (
        <ModalMovimiento
          productos={productosActivos}
          accesoTodas={accesoTodas}
          sucursales={sucursales}
          onClose={() => setModal(false)}
          onGuardar={(datos) => mutMovimiento.mutate(datos)}
        />
      )}
```

Modificar la firma y el cuerpo de `ModalMovimiento`:

```javascript
function ModalMovimiento({ productos, accesoTodas, sucursales, onClose, onGuardar }) {
  const [tipo, setTipo] = useState('entrada');
  const [productoId, setProductoId] = useState('');
  const [cantidad, setCantidad] = useState('');
  const [nota, setNota] = useState('');
  const [sucursalId, setSucursalId] = useState('');
  const [error, setError] = useState('');

  const accentColor = tipo === 'entrada' ? 'emerald' : tipo === 'salida' ? 'rose' : 'amber';

  const handleSubmit = (e) => {
    e.preventDefault();
    if (!productoId || !cantidad || Number(cantidad) <= 0) {
      setError('Producto y cantidad son requeridos');
      return;
    }
    if (accesoTodas && !sucursalId) {
      setError('Elegí la sucursal destino');
      return;
    }
    setError('');
    onGuardar({
      tipo,
      producto_id: Number(productoId),
      cantidad: Number(cantidad),
      nota,
      ...(accesoTodas ? { sucursal_id: Number(sucursalId) } : {}),
    });
  };
```

Y dentro del `<form>`, justo antes del bloque `{/* producto */}` (línea
94 del archivo original), agregar el selector condicional:

```javascript
          {/* sucursal destino (solo acceso-todas) */}
          {accesoTodas && (
            <div>
              <label className="block text-xs font-semibold text-gray-500 dark:text-gray-400 mb-1.5 uppercase tracking-wide">
                Sucursal destino
              </label>
              <select
                value={sucursalId}
                onChange={e => setSucursalId(e.target.value)}
                className="w-full rounded-xl border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
              >
                <option value="">Seleccionar sucursal...</option>
                {sucursales.map(s => <option key={s.id} value={s.id}>{s.nombre}</option>)}
              </select>
            </div>
          )}

          {/* producto */}
```

- [ ] **Step 3: Verificar con build**

Run: `cd frontend && npx vite build`
Expected: build exitoso.

Verificación manual: para un usuario normal (`accesoTodas === false`),
`ModalMovimiento` no renderiza el selector nuevo y `onGuardar` no incluye
`sucursal_id` en el payload — comportamiento idéntico al actual.

- [ ] **Step 4: Commit**

```bash
git add frontend/src/pages/inventario/InventarioPage.jsx
git commit -m "feat(inventario): selector de sucursal destino para usuarios acceso-todas"
```

---

### Task 6: Frontend — Productos: selector de sucursal en creación con stock inicial

**Files:**
- Modify: `frontend/src/pages/productos/ProductosPage.jsx`

**Interfaces:**
- Consumes: `getSucursales()` (sin cambios); `crearProducto(datos)` de
  `frontend/src/api/productos.js` (sin cambios de firma — se le agrega
  `sucursal_id` en el payload cuando corresponde).

- [ ] **Step 1: Cargar sucursales en `TabProductos` y pasarlas al form**

En `frontend/src/pages/productos/ProductosPage.jsx`, agregar import:

```javascript
import { getSucursales } from '../../api/sucursales';
```

Dentro de `function TabProductos(...)`, junto a la línea existente
`const accesoTodas = useAuthStore((s) => s.usuario?.sucursal_activa?.id == null);`,
agregar:

```javascript
const { data: sucursales = [] } = useQuery({
  queryKey: ['sucursales'],
  queryFn: getSucursales,
  enabled: accesoTodas,
});
```

Modificar el render de `FormProductoModal` (dentro de `TabProductos`,
donde dice `{modal && (<FormProductoModal ...>)}`):

```javascript
      {modal && (
        <FormProductoModal
          prod={modal.prod}
          categorias={categorias}
          accesoTodas={accesoTodas}
          sucursales={sucursales}
          onClose={() => setModal(null)}
          onGuardar={(datos) => guardar.mutate({ prod: modal.prod, datos })}
          guardando={guardar.isPending}
          error={guardar.error?.response?.data?.mensaje}
        />
      )}
```

- [ ] **Step 2: Agregar el selector y la validación en `FormProductoModal`**

Modificar la firma de `FormProductoModal` y agregar el estado de
sucursal:

```javascript
function FormProductoModal({ prod, categorias, accesoTodas, sucursales, onClose, onGuardar, guardando, error }) {
  const [form, setForm] = useState({
    categoria_id: prod?.categoria_id ?? (categorias[0]?.id ?? ''),
    nombre:       prod?.nombre ?? '',
    precio:       prod?.precio ?? '',
    stock:        prod?.stock ?? '',
    sucursal_id:  '',
    es_vendible:  prod?.es_vendible ?? true,
    imagen:       prod?.imagen ?? null,
  });
```

Modificar `handleGuardar` para incluir `sucursal_id` cuando corresponda:

```javascript
  function handleGuardar() {
    const datos = {
      categoria_id: parseInt(form.categoria_id),
      nombre: form.nombre,
      precio: parseFloat(form.precio),
      es_vendible: form.es_vendible,
      imagen: form.imagen,
    };
    // El stock solo se define al crear el producto; en edición se maneja
    // exclusivamente vía ajustes de inventario (ajustarStockSucursal).
    if (!prod) {
      datos.stock = form.stock !== '' ? parseInt(form.stock) : null;
      if (accesoTodas && datos.stock !== null) {
        datos.sucursal_id = parseInt(form.sucursal_id);
      }
    }
    onGuardar(datos);
  }
```

Dentro del bloque `{!prod && (<div>...Stock inicial...</div>)}`
(alrededor de la línea 535 del archivo original), agregar el selector de
sucursal justo después del `<input>` de stock, dentro del mismo `<div>`
condicional `!prod`:

```javascript
          {!prod && (
            <div>
              <label className="block text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-1.5">Stock inicial</label>
              <input
                type="number" min="0"
                value={form.stock}
                onChange={e => set('stock', e.target.value)}
                placeholder="Opcional"
                className="w-full bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-gray-800 dark:text-gray-100 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 transition"
              />
              {accesoTodas && form.stock !== '' && (
                <select
                  value={form.sucursal_id}
                  onChange={e => set('sucursal_id', e.target.value)}
                  className="w-full mt-2 bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-gray-800 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="">Sucursal para el stock inicial...</option>
                  {sucursales.map(s => <option key={s.id} value={s.id}>{s.nombre}</option>)}
                </select>
              )}
            </div>
          )}
```

Actualizar el `disabled` del botón "Guardar" para exigir la sucursal
cuando corresponda:

```javascript
          <button
            onClick={handleGuardar}
            disabled={
              guardando || subiendoImg || !form.nombre.trim() || !form.precio || !form.categoria_id ||
              (!prod && accesoTodas && form.stock !== '' && !form.sucursal_id)
            }
            className="px-4 py-2 rounded-xl text-sm bg-blue-600 hover:bg-blue-700 text-white transition-colors disabled:opacity-60"
          >
            {guardando ? 'Guardando...' : 'Guardar'}
          </button>
```

- [ ] **Step 3: Verificar con build**

Run: `cd frontend && npx vite build`
Expected: build exitoso.

Verificación manual: para un usuario normal (`accesoTodas === false`), el
selector nunca se renderiza y `handleGuardar` nunca agrega `sucursal_id`
al payload — comportamiento idéntico al actual.

- [ ] **Step 4: Commit**

```bash
git add frontend/src/pages/productos/ProductosPage.jsx
git commit -m "feat(productos): exige elegir sucursal para el stock inicial cuando el creador es acceso-todas"
```
