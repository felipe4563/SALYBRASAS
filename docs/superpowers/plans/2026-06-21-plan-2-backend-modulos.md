# Plan 2: Backend Módulos del Sistema de Restaurante

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar todos los módulos CRUD del negocio: Usuarios, Mesas/Áreas, Categorías/Productos, Clientes, Caja+Arqueo, Ventas/POS, Libro Caja, Compras+Proveedores, Inventario, Configuración.

**Architecture:** Cada módulo sigue el patrón de Plan 1: `routes.js` → `controller.js` → `service.js`. El service lanza errores con `Object.assign(new Error('msg'), { status: N })`. El controller usa try/catch/next(err). Todos los modelos base ya existen en `src/models/index.js`; las tareas 5–10 agregan modelos nuevos (DetalleArqueo, Gasto, LibroCaja, Proveedor, Compra, DetalleCompra, RegistroInventario, Configuracion) y actualizan `models/index.js`. Cada tarea también registra sus rutas en `src/app.js`.

**Tech Stack:** Node.js 20+ / Express 4.22.2 / Sequelize 6 / MySQL 8 / Jest / Supertest

## Global Constraints

- Todas las tablas y columnas en español (crítico — coinciden con las migraciones existentes)
- Formato respuesta exitosa: `{ ok: true, datos: ... }` / error: `{ ok: false, mensaje: "..." }`
- Prefijo API: `/api/v1`, puerto 3001
- Todas las rutas requieren JWT via middleware `auth` de `src/middlewares/auth.js`
- Verificación de permisos: `verificarPermiso('modulo', 'accion')` de `src/middlewares/permisos.js`
- Errores de servicio: `throw Object.assign(new Error('mensaje'), { status: N })`
- Patrón controller: `try { res.json({ ok: true, datos: await svc.fn() }); } catch (err) { next(err); }`
- Timestamps: `creado_en`, `actualizado_en` — ya configurado globalmente en Sequelize
- Directorio de trabajo: `c:/Users/ASUS/OneDrive/Escritorio/TODO/SISTEMAS/RESTAURANTE/backend/`
- Tests en `tests/`; Jest + Supertest; tests que requieren DB fallan sin MySQL (comportamiento esperado)
- Rutas `GET /api/v1/X` sin Authorization → 401 siempre (sin DB), esto debe ser el primer test de cada módulo

---

### Task 1: Módulo Usuarios

**Files:**
- Create: `src/modules/usuarios/usuarios.service.js`
- Create: `src/modules/usuarios/usuarios.controller.js`
- Create: `src/modules/usuarios/usuarios.routes.js`
- Modify: `src/app.js`
- Create: `tests/usuarios.test.js`

**Interfaces:**
- Consumes: `Usuario`, `Rol` de `src/models/index.js`; `auth` y `verificarPermiso` de middlewares
- Produces: rutas `/api/v1/usuarios` con CRUD

- [ ] **Step 1: Escribir test que falla**

Crear `tests/usuarios.test.js`:

```js
const request = require('supertest');
const app = require('../src/app');

describe('Usuarios API', () => {
  it('GET /api/v1/usuarios sin token → 401', async () => {
    const res = await request(app).get('/api/v1/usuarios');
    expect(res.status).toBe(401);
    expect(res.body.ok).toBe(false);
  });
});
```

- [ ] **Step 2: Correr test y verificar que falla**

```bash
cd c:/Users/ASUS/OneDrive/Escritorio/TODO/SISTEMAS/RESTAURANTE/backend
npx jest tests/usuarios.test.js --no-coverage 2>&1 | head -20
```

Esperado: FAIL — ruta no existe aún (404 en lugar de 401).

- [ ] **Step 3: Crear `src/modules/usuarios/usuarios.service.js`**

```js
const bcrypt = require('bcryptjs');
const { Usuario, Rol } = require('../../models');

const ATTRS_PUBLICOS = { exclude: ['contrasena', 'token_recordar'] };
const INCLUDE_ROL = [{ model: Rol, as: 'rol', attributes: ['id', 'nombre'] }];

async function listar() {
  return Usuario.findAll({ include: INCLUDE_ROL, attributes: ATTRS_PUBLICOS, order: [['creado_en', 'DESC']] });
}

async function obtener(id) {
  const u = await Usuario.findByPk(id, { include: INCLUDE_ROL, attributes: ATTRS_PUBLICOS });
  if (!u) throw Object.assign(new Error('Usuario no encontrado'), { status: 404 });
  return u;
}

async function crear({ nombre, email, contrasena, rol_id, activo = 1 }) {
  const hash = await bcrypt.hash(contrasena, 10);
  const u = await Usuario.create({ nombre, email, contrasena: hash, rol_id, activo });
  return obtener(u.id);
}

async function actualizar(id, { nombre, email, contrasena, rol_id, activo }) {
  const u = await Usuario.findByPk(id);
  if (!u) throw Object.assign(new Error('Usuario no encontrado'), { status: 404 });
  const datos = {};
  if (nombre !== undefined) datos.nombre = nombre;
  if (email !== undefined) datos.email = email;
  if (rol_id !== undefined) datos.rol_id = rol_id;
  if (activo !== undefined) datos.activo = activo;
  if (contrasena) datos.contrasena = await bcrypt.hash(contrasena, 10);
  await u.update(datos);
  return obtener(id);
}

async function eliminar(id, solicitante_id) {
  if (Number(id) === Number(solicitante_id)) {
    throw Object.assign(new Error('No puedes desactivar tu propio usuario'), { status: 409 });
  }
  const u = await Usuario.findByPk(id);
  if (!u) throw Object.assign(new Error('Usuario no encontrado'), { status: 404 });
  await u.update({ activo: 0 });
}

module.exports = { listar, obtener, crear, actualizar, eliminar };
```

- [ ] **Step 4: Crear `src/modules/usuarios/usuarios.controller.js`**

```js
const svc = require('./usuarios.service');

async function listar(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listar() }); }
  catch (err) { next(err); }
}

async function obtener(req, res, next) {
  try { res.json({ ok: true, datos: await svc.obtener(req.params.id) }); }
  catch (err) { next(err); }
}

async function crear(req, res, next) {
  try {
    const { nombre, email, contrasena, rol_id, activo } = req.body;
    if (!nombre || !email || !contrasena || !rol_id) {
      return res.status(400).json({ ok: false, mensaje: 'nombre, email, contrasena y rol_id son requeridos' });
    }
    res.status(201).json({ ok: true, datos: await svc.crear({ nombre, email, contrasena, rol_id, activo }) });
  } catch (err) { next(err); }
}

async function actualizar(req, res, next) {
  try { res.json({ ok: true, datos: await svc.actualizar(req.params.id, req.body) }); }
  catch (err) { next(err); }
}

async function eliminar(req, res, next) {
  try {
    await svc.eliminar(req.params.id, req.usuario.id);
    res.json({ ok: true, datos: null });
  } catch (err) { next(err); }
}

module.exports = { listar, obtener, crear, actualizar, eliminar };
```

- [ ] **Step 5: Crear `src/modules/usuarios/usuarios.routes.js`**

```js
const { Router } = require('express');
const ctrl = require('./usuarios.controller');
const auth = require('../../middlewares/auth');
const { verificarPermiso } = require('../../middlewares/permisos');

const router = Router();
router.use(auth);

router.get('/', verificarPermiso('usuarios', 'ver'), ctrl.listar);
router.post('/', verificarPermiso('usuarios', 'crear'), ctrl.crear);
router.get('/:id', verificarPermiso('usuarios', 'ver'), ctrl.obtener);
router.put('/:id', verificarPermiso('usuarios', 'editar'), ctrl.actualizar);
router.delete('/:id', verificarPermiso('usuarios', 'eliminar'), ctrl.eliminar);

module.exports = router;
```

- [ ] **Step 6: Registrar en `src/app.js`**

Agregar después de `const rolesRoutes = require('./modules/roles/roles.routes');`:
```js
const usuariosRoutes = require('./modules/usuarios/usuarios.routes');
```

Agregar después de `app.use('/api/v1/roles', rolesRoutes);`:
```js
app.use('/api/v1/usuarios', usuariosRoutes);
```

- [ ] **Step 7: Correr tests y verificar**

```bash
npx jest tests/usuarios.test.js --no-coverage 2>&1 | head -20
```

Esperado: PASS (el test 401 no necesita DB).

- [ ] **Step 8: Commit**

```bash
git add src/modules/usuarios/ src/app.js tests/usuarios.test.js
git commit -m "feat: módulo usuarios CRUD con soft delete"
```

---

### Task 2: Módulo Mesas y Áreas

**Files:**
- Create: `src/modules/mesas/mesas.service.js`
- Create: `src/modules/mesas/mesas.controller.js`
- Create: `src/modules/mesas/mesas.routes.js`
- Modify: `src/app.js`
- Create: `tests/mesas.test.js`

**Interfaces:**
- Consumes: `Area`, `Mesa` de `src/models/index.js`
- Produces: rutas `/api/v1/areas` y `/api/v1/mesas`

- [ ] **Step 1: Escribir test que falla**

Crear `tests/mesas.test.js`:

```js
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
```

- [ ] **Step 2: Correr test y verificar que falla**

```bash
npx jest tests/mesas.test.js --no-coverage 2>&1 | head -20
```

Esperado: FAIL — rutas no existen aún.

- [ ] **Step 3: Crear `src/modules/mesas/mesas.service.js`**

```js
const { Area, Mesa } = require('../../models');

// --- Áreas ---

async function listarAreas() {
  return Area.findAll({ include: [{ model: Mesa, as: 'mesas' }], order: [['nombre', 'ASC']] });
}

async function crearArea({ nombre }) {
  return Area.create({ nombre });
}

async function actualizarArea(id, { nombre }) {
  const area = await Area.findByPk(id);
  if (!area) throw Object.assign(new Error('Área no encontrada'), { status: 404 });
  await area.update({ nombre });
  return area;
}

async function eliminarArea(id) {
  const area = await Area.findByPk(id);
  if (!area) throw Object.assign(new Error('Área no encontrada'), { status: 404 });
  const mesas = await Mesa.count({ where: { area_id: id } });
  if (mesas > 0) throw Object.assign(new Error('El área tiene mesas asignadas'), { status: 409 });
  await area.destroy();
}

// --- Mesas ---

async function listarMesas(area_id) {
  const where = area_id ? { area_id } : {};
  return Mesa.findAll({ where, include: [{ model: Area, as: 'area', attributes: ['id', 'nombre'] }], order: [['nombre', 'ASC']] });
}

async function obtenerMesa(id) {
  const mesa = await Mesa.findByPk(id, { include: [{ model: Area, as: 'area', attributes: ['id', 'nombre'] }] });
  if (!mesa) throw Object.assign(new Error('Mesa no encontrada'), { status: 404 });
  return mesa;
}

async function crearMesa({ area_id, nombre, asientos = 4, pos_x = 0, pos_y = 0 }) {
  const area = await Area.findByPk(area_id);
  if (!area) throw Object.assign(new Error('Área no encontrada'), { status: 404 });
  return Mesa.create({ area_id, nombre, asientos, pos_x, pos_y });
}

async function actualizarMesa(id, datos) {
  const mesa = await Mesa.findByPk(id);
  if (!mesa) throw Object.assign(new Error('Mesa no encontrada'), { status: 404 });
  await mesa.update(datos);
  return obtenerMesa(id);
}

async function actualizarPosicion(id, { pos_x, pos_y }) {
  const mesa = await Mesa.findByPk(id);
  if (!mesa) throw Object.assign(new Error('Mesa no encontrada'), { status: 404 });
  await mesa.update({ pos_x, pos_y });
  return mesa;
}

async function eliminarMesa(id) {
  const mesa = await Mesa.findByPk(id);
  if (!mesa) throw Object.assign(new Error('Mesa no encontrada'), { status: 404 });
  if (mesa.estado === 'ocupada') throw Object.assign(new Error('No se puede eliminar una mesa ocupada'), { status: 409 });
  await mesa.destroy();
}

module.exports = { listarAreas, crearArea, actualizarArea, eliminarArea, listarMesas, obtenerMesa, crearMesa, actualizarMesa, actualizarPosicion, eliminarMesa };
```

- [ ] **Step 4: Crear `src/modules/mesas/mesas.controller.js`**

```js
const svc = require('./mesas.service');

async function listarAreas(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listarAreas() }); }
  catch (err) { next(err); }
}

async function crearArea(req, res, next) {
  try {
    if (!req.body.nombre) return res.status(400).json({ ok: false, mensaje: 'nombre es requerido' });
    res.status(201).json({ ok: true, datos: await svc.crearArea(req.body) });
  } catch (err) { next(err); }
}

async function actualizarArea(req, res, next) {
  try { res.json({ ok: true, datos: await svc.actualizarArea(req.params.id, req.body) }); }
  catch (err) { next(err); }
}

async function eliminarArea(req, res, next) {
  try { await svc.eliminarArea(req.params.id); res.json({ ok: true, datos: null }); }
  catch (err) { next(err); }
}

async function listarMesas(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listarMesas(req.query.area_id) }); }
  catch (err) { next(err); }
}

async function obtenerMesa(req, res, next) {
  try { res.json({ ok: true, datos: await svc.obtenerMesa(req.params.id) }); }
  catch (err) { next(err); }
}

async function crearMesa(req, res, next) {
  try {
    const { area_id, nombre } = req.body;
    if (!area_id || !nombre) return res.status(400).json({ ok: false, mensaje: 'area_id y nombre son requeridos' });
    res.status(201).json({ ok: true, datos: await svc.crearMesa(req.body) });
  } catch (err) { next(err); }
}

async function actualizarMesa(req, res, next) {
  try { res.json({ ok: true, datos: await svc.actualizarMesa(req.params.id, req.body) }); }
  catch (err) { next(err); }
}

async function actualizarPosicion(req, res, next) {
  try {
    const { pos_x, pos_y } = req.body;
    if (pos_x === undefined || pos_y === undefined) return res.status(400).json({ ok: false, mensaje: 'pos_x y pos_y son requeridos' });
    res.json({ ok: true, datos: await svc.actualizarPosicion(req.params.id, { pos_x, pos_y }) });
  } catch (err) { next(err); }
}

async function eliminarMesa(req, res, next) {
  try { await svc.eliminarMesa(req.params.id); res.json({ ok: true, datos: null }); }
  catch (err) { next(err); }
}

module.exports = { listarAreas, crearArea, actualizarArea, eliminarArea, listarMesas, obtenerMesa, crearMesa, actualizarMesa, actualizarPosicion, eliminarMesa };
```

- [ ] **Step 5: Crear `src/modules/mesas/mesas.routes.js`**

```js
const { Router } = require('express');
const ctrl = require('./mesas.controller');
const auth = require('../../middlewares/auth');
const { verificarPermiso } = require('../../middlewares/permisos');

const router = Router();
router.use(auth);

// Áreas
router.get('/areas', verificarPermiso('ventas', 'ver'), ctrl.listarAreas);
router.post('/areas', verificarPermiso('configuracion', 'editar'), ctrl.crearArea);
router.put('/areas/:id', verificarPermiso('configuracion', 'editar'), ctrl.actualizarArea);
router.delete('/areas/:id', verificarPermiso('configuracion', 'editar'), ctrl.eliminarArea);

// Mesas
router.get('/', verificarPermiso('ventas', 'ver'), ctrl.listarMesas);
router.post('/', verificarPermiso('configuracion', 'editar'), ctrl.crearMesa);
router.get('/:id', verificarPermiso('ventas', 'ver'), ctrl.obtenerMesa);
router.put('/:id', verificarPermiso('configuracion', 'editar'), ctrl.actualizarMesa);
router.patch('/:id/posicion', verificarPermiso('configuracion', 'editar'), ctrl.actualizarPosicion);
router.delete('/:id', verificarPermiso('configuracion', 'editar'), ctrl.eliminarMesa);

module.exports = router;
```

- [ ] **Step 6: Registrar en `src/app.js`**

Agregar el require:
```js
const mesasRoutes = require('./modules/mesas/mesas.routes');
```

Agregar la ruta (las áreas van bajo el mismo router de mesas):
```js
app.use('/api/v1/mesas', mesasRoutes);
```

Nota: `GET /api/v1/areas` es en realidad `GET /api/v1/mesas/areas` dado que el router está montado en `/api/v1/mesas`. Si se prefiere `/api/v1/areas` como ruta independiente, montar también: `app.use('/api/v1/areas', mesasRoutes)` — pero esto causaría doble registro. La solución más limpia es un router separado para areas. **Hacer esto:** montar mesas en `/api/v1/mesas` y crear rutas de areas directamente en `app.js` con un segundo router o separar en dos archivos.

**Alternativa final recomendada:** separar en `areas.routes.js` y `mesas.routes.js`:

Crear `src/modules/mesas/areas.routes.js`:
```js
const { Router } = require('express');
const ctrl = require('./mesas.controller');
const auth = require('../../middlewares/auth');
const { verificarPermiso } = require('../../middlewares/permisos');

const router = Router();
router.use(auth);

router.get('/', verificarPermiso('ventas', 'ver'), ctrl.listarAreas);
router.post('/', verificarPermiso('configuracion', 'editar'), ctrl.crearArea);
router.put('/:id', verificarPermiso('configuracion', 'editar'), ctrl.actualizarArea);
router.delete('/:id', verificarPermiso('configuracion', 'editar'), ctrl.eliminarArea);

module.exports = router;
```

Actualizar `mesas.routes.js` para quitar las rutas de áreas (quedan solo las de mesas):
```js
const { Router } = require('express');
const ctrl = require('./mesas.controller');
const auth = require('../../middlewares/auth');
const { verificarPermiso } = require('../../middlewares/permisos');

const router = Router();
router.use(auth);

router.get('/', verificarPermiso('ventas', 'ver'), ctrl.listarMesas);
router.post('/', verificarPermiso('configuracion', 'editar'), ctrl.crearMesa);
router.get('/:id', verificarPermiso('ventas', 'ver'), ctrl.obtenerMesa);
router.put('/:id', verificarPermiso('configuracion', 'editar'), ctrl.actualizarMesa);
router.patch('/:id/posicion', verificarPermiso('configuracion', 'editar'), ctrl.actualizarPosicion);
router.delete('/:id', verificarPermiso('configuracion', 'editar'), ctrl.eliminarMesa);

module.exports = router;
```

En `src/app.js`, agregar:
```js
const mesasRoutes = require('./modules/mesas/mesas.routes');
const areasRoutes = require('./modules/mesas/areas.routes');
```

```js
app.use('/api/v1/mesas', mesasRoutes);
app.use('/api/v1/areas', areasRoutes);
```

- [ ] **Step 7: Correr tests**

```bash
npx jest tests/mesas.test.js --no-coverage 2>&1 | head -20
```

Esperado: PASS.

- [ ] **Step 8: Commit**

```bash
git add src/modules/mesas/ src/app.js tests/mesas.test.js
git commit -m "feat: módulo mesas y áreas con posición drag & drop"
```

---

### Task 3: Módulo Categorías y Productos

**Files:**
- Create: `src/modules/productos/productos.service.js`
- Create: `src/modules/productos/productos.controller.js`
- Create: `src/modules/productos/productos.routes.js`
- Create: `src/modules/productos/categorias.routes.js`
- Modify: `src/app.js`
- Create: `tests/productos.test.js`

**Interfaces:**
- Consumes: `Categoria`, `Producto` de `src/models/index.js`
- Produces: rutas `/api/v1/categorias` y `/api/v1/productos`

- [ ] **Step 1: Escribir test que falla**

Crear `tests/productos.test.js`:

```js
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
```

- [ ] **Step 2: Correr test y verificar que falla**

```bash
npx jest tests/productos.test.js --no-coverage 2>&1 | head -20
```

Esperado: FAIL — rutas no existen aún.

- [ ] **Step 3: Crear `src/modules/productos/productos.service.js`**

```js
const { Categoria, Producto } = require('../../models');

// --- Categorías ---

async function listarCategorias() {
  return Categoria.findAll({ order: [['nombre', 'ASC']] });
}

async function crearCategoria({ nombre, imagen }) {
  return Categoria.create({ nombre, imagen });
}

async function actualizarCategoria(id, { nombre, imagen, activo }) {
  const cat = await Categoria.findByPk(id);
  if (!cat) throw Object.assign(new Error('Categoría no encontrada'), { status: 404 });
  await cat.update({ nombre, imagen, activo });
  return cat;
}

async function eliminarCategoria(id) {
  const cat = await Categoria.findByPk(id);
  if (!cat) throw Object.assign(new Error('Categoría no encontrada'), { status: 404 });
  const productos = await Producto.count({ where: { categoria_id: id } });
  if (productos > 0) throw Object.assign(new Error('La categoría tiene productos asignados'), { status: 409 });
  await cat.destroy();
}

// --- Productos ---

async function listarProductos({ categoria_id, solo_vendibles } = {}) {
  const where = { activo: 1 };
  if (categoria_id) where.categoria_id = categoria_id;
  if (solo_vendibles === 'true' || solo_vendibles === true) where.es_vendible = 1;
  return Producto.findAll({
    where,
    include: [{ model: Categoria, as: 'categoria', attributes: ['id', 'nombre'] }],
    order: [['nombre', 'ASC']],
  });
}

async function obtenerProducto(id) {
  const p = await Producto.findByPk(id, {
    include: [{ model: Categoria, as: 'categoria', attributes: ['id', 'nombre'] }],
  });
  if (!p) throw Object.assign(new Error('Producto no encontrado'), { status: 404 });
  return p;
}

async function crearProducto({ categoria_id, nombre, codigo_barras, codigo, precio, costo, stock, es_vendible, imagen }) {
  return Producto.create({ categoria_id, nombre, codigo_barras, codigo, precio, costo, stock, es_vendible, imagen });
}

async function actualizarProducto(id, datos) {
  const p = await Producto.findByPk(id);
  if (!p) throw Object.assign(new Error('Producto no encontrado'), { status: 404 });
  await p.update(datos);
  return obtenerProducto(id);
}

async function eliminarProducto(id) {
  const p = await Producto.findByPk(id);
  if (!p) throw Object.assign(new Error('Producto no encontrado'), { status: 404 });
  await p.update({ activo: 0 });
}

module.exports = { listarCategorias, crearCategoria, actualizarCategoria, eliminarCategoria, listarProductos, obtenerProducto, crearProducto, actualizarProducto, eliminarProducto };
```

- [ ] **Step 4: Crear `src/modules/productos/productos.controller.js`**

```js
const svc = require('./productos.service');

async function listarCategorias(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listarCategorias() }); }
  catch (err) { next(err); }
}

async function crearCategoria(req, res, next) {
  try {
    if (!req.body.nombre) return res.status(400).json({ ok: false, mensaje: 'nombre es requerido' });
    res.status(201).json({ ok: true, datos: await svc.crearCategoria(req.body) });
  } catch (err) { next(err); }
}

async function actualizarCategoria(req, res, next) {
  try { res.json({ ok: true, datos: await svc.actualizarCategoria(req.params.id, req.body) }); }
  catch (err) { next(err); }
}

async function eliminarCategoria(req, res, next) {
  try { await svc.eliminarCategoria(req.params.id); res.json({ ok: true, datos: null }); }
  catch (err) { next(err); }
}

async function listarProductos(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listarProductos(req.query) }); }
  catch (err) { next(err); }
}

async function obtenerProducto(req, res, next) {
  try { res.json({ ok: true, datos: await svc.obtenerProducto(req.params.id) }); }
  catch (err) { next(err); }
}

async function crearProducto(req, res, next) {
  try {
    const { categoria_id, nombre, precio } = req.body;
    if (!categoria_id || !nombre || precio === undefined) {
      return res.status(400).json({ ok: false, mensaje: 'categoria_id, nombre y precio son requeridos' });
    }
    res.status(201).json({ ok: true, datos: await svc.crearProducto(req.body) });
  } catch (err) { next(err); }
}

async function actualizarProducto(req, res, next) {
  try { res.json({ ok: true, datos: await svc.actualizarProducto(req.params.id, req.body) }); }
  catch (err) { next(err); }
}

async function eliminarProducto(req, res, next) {
  try { await svc.eliminarProducto(req.params.id); res.json({ ok: true, datos: null }); }
  catch (err) { next(err); }
}

module.exports = { listarCategorias, crearCategoria, actualizarCategoria, eliminarCategoria, listarProductos, obtenerProducto, crearProducto, actualizarProducto, eliminarProducto };
```

- [ ] **Step 5: Crear `src/modules/productos/categorias.routes.js`**

```js
const { Router } = require('express');
const ctrl = require('./productos.controller');
const auth = require('../../middlewares/auth');
const { verificarPermiso } = require('../../middlewares/permisos');

const router = Router();
router.use(auth);

router.get('/', verificarPermiso('productos', 'ver'), ctrl.listarCategorias);
router.post('/', verificarPermiso('productos', 'crear'), ctrl.crearCategoria);
router.put('/:id', verificarPermiso('productos', 'editar'), ctrl.actualizarCategoria);
router.delete('/:id', verificarPermiso('productos', 'eliminar'), ctrl.eliminarCategoria);

module.exports = router;
```

- [ ] **Step 6: Crear `src/modules/productos/productos.routes.js`**

```js
const { Router } = require('express');
const ctrl = require('./productos.controller');
const auth = require('../../middlewares/auth');
const { verificarPermiso } = require('../../middlewares/permisos');

const router = Router();
router.use(auth);

router.get('/', verificarPermiso('productos', 'ver'), ctrl.listarProductos);
router.post('/', verificarPermiso('productos', 'crear'), ctrl.crearProducto);
router.get('/:id', verificarPermiso('productos', 'ver'), ctrl.obtenerProducto);
router.put('/:id', verificarPermiso('productos', 'editar'), ctrl.actualizarProducto);
router.delete('/:id', verificarPermiso('productos', 'eliminar'), ctrl.eliminarProducto);

module.exports = router;
```

- [ ] **Step 7: Registrar en `src/app.js`**

```js
const productosRoutes = require('./modules/productos/productos.routes');
const categoriasRoutes = require('./modules/productos/categorias.routes');
```

```js
app.use('/api/v1/productos', productosRoutes);
app.use('/api/v1/categorias', categoriasRoutes);
```

- [ ] **Step 8: Correr tests**

```bash
npx jest tests/productos.test.js --no-coverage 2>&1 | head -20
```

Esperado: PASS.

- [ ] **Step 9: Commit**

```bash
git add src/modules/productos/ src/app.js tests/productos.test.js
git commit -m "feat: módulo categorías y productos con soft delete"
```

---

### Task 4: Módulo Clientes

**Files:**
- Create: `src/modules/clientes/clientes.service.js`
- Create: `src/modules/clientes/clientes.controller.js`
- Create: `src/modules/clientes/clientes.routes.js`
- Modify: `src/app.js`
- Create: `tests/clientes.test.js`

**Interfaces:**
- Consumes: `Cliente` de `src/models/index.js`
- Produces: rutas `/api/v1/clientes`

- [ ] **Step 1: Escribir test que falla**

Crear `tests/clientes.test.js`:

```js
const request = require('supertest');
const app = require('../src/app');

describe('Clientes API', () => {
  it('GET /api/v1/clientes sin token → 401', async () => {
    const res = await request(app).get('/api/v1/clientes');
    expect(res.status).toBe(401);
  });
});
```

- [ ] **Step 2: Correr test y verificar que falla**

```bash
npx jest tests/clientes.test.js --no-coverage 2>&1 | head -20
```

- [ ] **Step 3: Crear `src/modules/clientes/clientes.service.js`**

```js
const { Op } = require('sequelize');
const { Cliente } = require('../../models');

async function listar({ buscar } = {}) {
  const where = {};
  if (buscar) {
    where[Op.or] = [
      { nombre: { [Op.like]: `%${buscar}%` } },
      { numero_documento: { [Op.like]: `%${buscar}%` } },
    ];
  }
  return Cliente.findAll({ where, order: [['nombre', 'ASC']] });
}

async function obtener(id) {
  const c = await Cliente.findByPk(id);
  if (!c) throw Object.assign(new Error('Cliente no encontrado'), { status: 404 });
  return c;
}

async function crear({ nombre, tipo_documento = 'CI', numero_documento, email, telefono, direccion }) {
  return Cliente.create({ nombre, tipo_documento, numero_documento, email, telefono, direccion });
}

async function actualizar(id, datos) {
  const c = await Cliente.findByPk(id);
  if (!c) throw Object.assign(new Error('Cliente no encontrado'), { status: 404 });
  await c.update(datos);
  return c;
}

module.exports = { listar, obtener, crear, actualizar };
```

- [ ] **Step 4: Crear `src/modules/clientes/clientes.controller.js`**

```js
const svc = require('./clientes.service');

async function listar(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listar(req.query) }); }
  catch (err) { next(err); }
}

async function obtener(req, res, next) {
  try { res.json({ ok: true, datos: await svc.obtener(req.params.id) }); }
  catch (err) { next(err); }
}

async function crear(req, res, next) {
  try {
    if (!req.body.nombre) return res.status(400).json({ ok: false, mensaje: 'nombre es requerido' });
    res.status(201).json({ ok: true, datos: await svc.crear(req.body) });
  } catch (err) { next(err); }
}

async function actualizar(req, res, next) {
  try { res.json({ ok: true, datos: await svc.actualizar(req.params.id, req.body) }); }
  catch (err) { next(err); }
}

module.exports = { listar, obtener, crear, actualizar };
```

- [ ] **Step 5: Crear `src/modules/clientes/clientes.routes.js`**

```js
const { Router } = require('express');
const ctrl = require('./clientes.controller');
const auth = require('../../middlewares/auth');
const { verificarPermiso } = require('../../middlewares/permisos');

const router = Router();
router.use(auth);

router.get('/', verificarPermiso('clientes', 'ver'), ctrl.listar);
router.post('/', verificarPermiso('clientes', 'crear'), ctrl.crear);
router.get('/:id', verificarPermiso('clientes', 'ver'), ctrl.obtener);
router.put('/:id', verificarPermiso('clientes', 'editar'), ctrl.actualizar);

module.exports = router;
```

- [ ] **Step 6: Registrar en `src/app.js`**

```js
const clientesRoutes = require('./modules/clientes/clientes.routes');
```

```js
app.use('/api/v1/clientes', clientesRoutes);
```

- [ ] **Step 7: Correr tests**

```bash
npx jest tests/clientes.test.js --no-coverage 2>&1 | head -20
```

Esperado: PASS.

- [ ] **Step 8: Commit**

```bash
git add src/modules/clientes/ src/app.js tests/clientes.test.js
git commit -m "feat: módulo clientes con búsqueda por nombre y documento"
```

---

### Task 5: Módulo Caja + Arqueo + Gastos

**Files:**
- Create: `src/models/DetalleArqueo.js`
- Create: `src/models/Gasto.js`
- Create: `src/models/LibroCaja.js`
- Modify: `src/models/index.js`
- Create: `src/modules/caja/caja.service.js`
- Create: `src/modules/caja/caja.controller.js`
- Create: `src/modules/caja/caja.routes.js`
- Modify: `src/app.js`
- Create: `tests/caja.test.js`

**Interfaces:**
- Consumes: `SesionCaja`, `Usuario`, `DetalleArqueo`, `Gasto`, `LibroCaja` de models
- Produces: rutas `/api/v1/caja`; expone `LibroCaja` para Task 6 (ventas.cobrar) y Task 7 (libro-caja module)

- [ ] **Step 1: Escribir test que falla**

Crear `tests/caja.test.js`:

```js
const request = require('supertest');
const app = require('../src/app');

describe('Caja API', () => {
  it('GET /api/v1/caja/activa sin token → 401', async () => {
    const res = await request(app).get('/api/v1/caja/activa');
    expect(res.status).toBe(401);
  });
});
```

- [ ] **Step 2: Correr test y verificar que falla**

```bash
npx jest tests/caja.test.js --no-coverage 2>&1 | head -20
```

- [ ] **Step 3: Crear `src/models/DetalleArqueo.js`**

```js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const DetalleArqueo = sequelize.define('DetalleArqueo', {
  id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
  sesion_caja_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
  denominacion: { type: DataTypes.DECIMAL(10, 2), allowNull: false },
  cantidad: { type: DataTypes.INTEGER, defaultValue: 0 },
  subtotal: { type: DataTypes.DECIMAL(10, 2), defaultValue: 0 },
}, { tableName: 'detalle_arqueo', timestamps: false });

module.exports = DetalleArqueo;
```

- [ ] **Step 4: Crear `src/models/Gasto.js`**

```js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Gasto = sequelize.define('Gasto', {
  id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
  sesion_caja_id: { type: DataTypes.INTEGER.UNSIGNED },
  usuario_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
  descripcion: { type: DataTypes.STRING(255), allowNull: false },
  monto: { type: DataTypes.DECIMAL(10, 2), allowNull: false },
}, { tableName: 'gastos', createdAt: 'creado_en', updatedAt: 'actualizado_en' });

module.exports = Gasto;
```

- [ ] **Step 5: Crear `src/models/LibroCaja.js`**

```js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const LibroCaja = sequelize.define('LibroCaja', {
  id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
  sesion_caja_id: { type: DataTypes.INTEGER.UNSIGNED },
  usuario_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
  tipo: { type: DataTypes.ENUM('ingreso', 'egreso'), allowNull: false },
  concepto: { type: DataTypes.STRING(255), allowNull: false },
  monto: { type: DataTypes.DECIMAL(10, 2), allowNull: false },
  metodo_pago: { type: DataTypes.ENUM('efectivo', 'qr'), defaultValue: 'efectivo' },
  referencia_id: { type: DataTypes.INTEGER.UNSIGNED },
}, { tableName: 'libro_caja', createdAt: 'creado_en', updatedAt: 'actualizado_en' });

module.exports = LibroCaja;
```

- [ ] **Step 6: Actualizar `src/models/index.js`**

Al final de los imports existentes, agregar:
```js
const DetalleArqueo = require('./DetalleArqueo');
const Gasto = require('./Gasto');
const LibroCaja = require('./LibroCaja');
```

Al final de las asociaciones existentes, agregar:
```js
// Caja
SesionCaja.hasMany(DetalleArqueo, { foreignKey: 'sesion_caja_id', as: 'detalle_arqueo' });
DetalleArqueo.belongsTo(SesionCaja, { foreignKey: 'sesion_caja_id' });

SesionCaja.hasMany(Gasto, { foreignKey: 'sesion_caja_id', as: 'gastos' });
Gasto.belongsTo(SesionCaja, { foreignKey: 'sesion_caja_id' });
Gasto.belongsTo(Usuario, { foreignKey: 'usuario_id', as: 'usuario' });

SesionCaja.hasMany(LibroCaja, { foreignKey: 'sesion_caja_id', as: 'libro_caja' });
LibroCaja.belongsTo(SesionCaja, { foreignKey: 'sesion_caja_id' });
LibroCaja.belongsTo(Usuario, { foreignKey: 'usuario_id', as: 'usuario' });
```

En el `module.exports`, agregar `DetalleArqueo, Gasto, LibroCaja`:
```js
module.exports = {
  sequelize,
  Rol, Permiso, Usuario,
  Area, Mesa,
  Categoria, Producto,
  Cliente,
  SesionCaja, Pedido, DetallePedido,
  DetalleArqueo, Gasto, LibroCaja,
};
```

- [ ] **Step 7: Crear `src/modules/caja/caja.service.js`**

```js
const { Op } = require('sequelize');
const { SesionCaja, DetalleArqueo, Gasto, LibroCaja, Usuario } = require('../../models');

async function obtenerActiva(usuario_id) {
  return SesionCaja.findOne({
    where: { usuario_id, estado: 'abierta' },
    include: [{ model: Usuario, as: 'usuario', attributes: ['id', 'nombre'] }],
  });
}

async function listar() {
  return SesionCaja.findAll({
    include: [{ model: Usuario, as: 'usuario', attributes: ['id', 'nombre'] }],
    order: [['abierto_en', 'DESC']],
    limit: 50,
  });
}

async function obtener(id) {
  const s = await SesionCaja.findByPk(id, {
    include: [
      { model: Usuario, as: 'usuario', attributes: ['id', 'nombre'] },
      { model: DetalleArqueo, as: 'detalle_arqueo' },
      { model: Gasto, as: 'gastos' },
    ],
  });
  if (!s) throw Object.assign(new Error('Sesión no encontrada'), { status: 404 });
  return s;
}

async function abrir(usuario_id, monto_apertura = 0) {
  const activa = await obtenerActiva(usuario_id);
  if (activa) throw Object.assign(new Error('Ya tienes una sesión de caja abierta'), { status: 409 });
  return SesionCaja.create({ usuario_id, monto_apertura });
}

async function registrarGasto(sesion_id, usuario_id, { descripcion, monto }) {
  const sesion = await SesionCaja.findByPk(sesion_id);
  if (!sesion) throw Object.assign(new Error('Sesión no encontrada'), { status: 404 });
  if (sesion.estado !== 'abierta') throw Object.assign(new Error('La sesión ya está cerrada'), { status: 409 });

  const gasto = await Gasto.create({ sesion_caja_id: sesion_id, usuario_id, descripcion, monto });

  await LibroCaja.create({
    sesion_caja_id: sesion_id,
    usuario_id,
    tipo: 'egreso',
    concepto: descripcion,
    monto,
    metodo_pago: 'efectivo',
    referencia_id: gasto.id,
  });

  await SesionCaja.increment('total_gastos', { by: parseFloat(monto), where: { id: sesion_id } });

  return gasto;
}

async function listarGastos(sesion_id) {
  return Gasto.findAll({ where: { sesion_caja_id: sesion_id }, order: [['creado_en', 'DESC']] });
}

async function cerrar(sesion_id, usuario_id, denominaciones = []) {
  const sesion = await SesionCaja.findByPk(sesion_id);
  if (!sesion) throw Object.assign(new Error('Sesión no encontrada'), { status: 404 });
  if (sesion.estado !== 'abierta') throw Object.assign(new Error('La sesión ya está cerrada'), { status: 409 });
  if (sesion.usuario_id !== usuario_id) throw Object.assign(new Error('Solo el cajero que abrió puede cerrar la sesión'), { status: 403 });

  // Calcular total físico de denominaciones
  const total_fisico = denominaciones.reduce((sum, d) => sum + (parseFloat(d.denominacion) * parseInt(d.cantidad)), 0);

  // Guardar detalle de arqueo
  if (denominaciones.length > 0) {
    await DetalleArqueo.destroy({ where: { sesion_caja_id: sesion_id } });
    await DetalleArqueo.bulkCreate(
      denominaciones.map(d => ({
        sesion_caja_id: sesion_id,
        denominacion: d.denominacion,
        cantidad: d.cantidad,
        subtotal: parseFloat(d.denominacion) * parseInt(d.cantidad),
      }))
    );
  }

  // Calcular ventas en efectivo para el arqueo
  const ventasEfectivo = await LibroCaja.sum('monto', {
    where: { sesion_caja_id: sesion_id, tipo: 'ingreso', metodo_pago: 'efectivo' },
  }) || 0;

  const efectivo_esperado = parseFloat(sesion.monto_apertura) + ventasEfectivo - parseFloat(sesion.total_gastos);
  const diferencia = total_fisico - efectivo_esperado;

  await sesion.update({
    monto_cierre: total_fisico,
    diferencia,
    estado: 'cerrada',
    cerrado_en: new Date(),
  });

  return obtener(sesion_id);
}

module.exports = { obtenerActiva, listar, obtener, abrir, registrarGasto, listarGastos, cerrar };
```

- [ ] **Step 8: Crear `src/modules/caja/caja.controller.js`**

```js
const svc = require('./caja.service');

async function obtenerActiva(req, res, next) {
  try {
    const sesion = await svc.obtenerActiva(req.usuario.id);
    res.json({ ok: true, datos: sesion });
  } catch (err) { next(err); }
}

async function listar(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listar() }); }
  catch (err) { next(err); }
}

async function obtener(req, res, next) {
  try { res.json({ ok: true, datos: await svc.obtener(req.params.id) }); }
  catch (err) { next(err); }
}

async function abrir(req, res, next) {
  try {
    const { monto_apertura } = req.body;
    res.status(201).json({ ok: true, datos: await svc.abrir(req.usuario.id, monto_apertura) });
  } catch (err) { next(err); }
}

async function registrarGasto(req, res, next) {
  try {
    const { descripcion, monto } = req.body;
    if (!descripcion || monto === undefined) return res.status(400).json({ ok: false, mensaje: 'descripcion y monto son requeridos' });
    res.status(201).json({ ok: true, datos: await svc.registrarGasto(req.params.id, req.usuario.id, { descripcion, monto }) });
  } catch (err) { next(err); }
}

async function listarGastos(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listarGastos(req.params.id) }); }
  catch (err) { next(err); }
}

async function cerrar(req, res, next) {
  try {
    const { denominaciones = [] } = req.body;
    res.json({ ok: true, datos: await svc.cerrar(req.params.id, req.usuario.id, denominaciones) });
  } catch (err) { next(err); }
}

module.exports = { obtenerActiva, listar, obtener, abrir, registrarGasto, listarGastos, cerrar };
```

- [ ] **Step 9: Crear `src/modules/caja/caja.routes.js`**

```js
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

module.exports = router;
```

- [ ] **Step 10: Registrar en `src/app.js`**

```js
const cajaRoutes = require('./modules/caja/caja.routes');
```

```js
app.use('/api/v1/caja', cajaRoutes);
```

- [ ] **Step 11: Correr tests**

```bash
npx jest tests/caja.test.js --no-coverage 2>&1 | head -20
```

Esperado: PASS.

- [ ] **Step 12: Commit**

```bash
git add src/models/DetalleArqueo.js src/models/Gasto.js src/models/LibroCaja.js src/models/index.js src/modules/caja/ src/app.js tests/caja.test.js
git commit -m "feat: módulo caja con arqueo de denominaciones bolivianas y gastos"
```

---

### Task 6: Módulo Ventas / Pedidos (POS)

**Files:**
- Create: `src/modules/ventas/ventas.service.js`
- Create: `src/modules/ventas/ventas.controller.js`
- Create: `src/modules/ventas/ventas.routes.js`
- Modify: `src/app.js`
- Create: `tests/ventas.test.js`

**Interfaces:**
- Consumes: `Pedido`, `DetallePedido`, `Mesa`, `Producto`, `Cliente`, `SesionCaja`, `LibroCaja` de models
- Produces: rutas `/api/v1/ventas`

- [ ] **Step 1: Escribir test que falla**

Crear `tests/ventas.test.js`:

```js
const request = require('supertest');
const app = require('../src/app');

describe('Ventas API', () => {
  it('GET /api/v1/ventas sin token → 401', async () => {
    const res = await request(app).get('/api/v1/ventas');
    expect(res.status).toBe(401);
  });
});
```

- [ ] **Step 2: Correr test y verificar que falla**

```bash
npx jest tests/ventas.test.js --no-coverage 2>&1 | head -20
```

- [ ] **Step 3: Crear `src/modules/ventas/ventas.service.js`**

```js
const { Pedido, DetallePedido, Mesa, Producto, Cliente, SesionCaja, LibroCaja } = require('../../models');

const INCLUDE_PEDIDO_COMPLETO = [
  { model: Mesa, as: 'mesa', attributes: ['id', 'nombre', 'estado'] },
  { model: Cliente, as: 'cliente', attributes: ['id', 'nombre', 'numero_documento'] },
  {
    model: DetallePedido, as: 'detalles',
    include: [{ model: Producto, as: 'producto', attributes: ['id', 'nombre', 'precio'] }],
  },
];

async function listar({ estado, mesa_id } = {}) {
  const where = {};
  if (estado) where.estado = estado;
  if (mesa_id) where.mesa_id = mesa_id;
  return Pedido.findAll({ where, include: INCLUDE_PEDIDO_COMPLETO, order: [['creado_en', 'DESC']] });
}

async function obtener(id) {
  const p = await Pedido.findByPk(id, { include: INCLUDE_PEDIDO_COMPLETO });
  if (!p) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  return p;
}

async function crear({ mesa_id, usuario_id, cliente_id, sesion_caja_id, notas, nombre_cliente, documento_cliente, tipo_documento }) {
  const mesa = await Mesa.findByPk(mesa_id);
  if (!mesa) throw Object.assign(new Error('Mesa no encontrada'), { status: 404 });

  const pedido = await Pedido.create({
    mesa_id,
    usuario_id,
    cliente_id,
    sesion_caja_id,
    notas,
    nombre_cliente: nombre_cliente || 'Público General',
    documento_cliente,
    tipo_documento: tipo_documento || 'Ticket',
  });

  await mesa.update({ estado: 'ocupada' });

  return obtener(pedido.id);
}

async function agregarItem(pedido_id, { producto_id, cantidad = 1, nota }) {
  const pedido = await Pedido.findByPk(pedido_id);
  if (!pedido) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  if (pedido.estado !== 'pendiente') throw Object.assign(new Error('El pedido no está pendiente'), { status: 409 });

  const producto = await Producto.findByPk(producto_id);
  if (!producto) throw Object.assign(new Error('Producto no encontrado'), { status: 404 });
  if (!producto.activo || !producto.es_vendible) throw Object.assign(new Error('Producto no disponible'), { status: 409 });

  const item = await DetallePedido.create({
    pedido_id,
    producto_id,
    cantidad,
    precio: producto.precio,
    nota,
  });

  await _recalcularTotal(pedido_id);
  return item;
}

async function actualizarItem(pedido_id, item_id, { cantidad, nota, estado }) {
  const item = await DetallePedido.findOne({ where: { id: item_id, pedido_id } });
  if (!item) throw Object.assign(new Error('Item no encontrado'), { status: 404 });
  await item.update({ cantidad, nota, estado });
  await _recalcularTotal(pedido_id);
  return item;
}

async function eliminarItem(pedido_id, item_id) {
  const pedido = await Pedido.findByPk(pedido_id);
  if (!pedido || pedido.estado !== 'pendiente') throw Object.assign(new Error('Pedido no modificable'), { status: 409 });
  const item = await DetallePedido.findOne({ where: { id: item_id, pedido_id } });
  if (!item) throw Object.assign(new Error('Item no encontrado'), { status: 404 });
  await item.destroy();
  await _recalcularTotal(pedido_id);
}

async function cobrar(pedido_id, usuario_id, { metodo_pago, monto_recibido, descuento = 0, propina = 0 }) {
  const pedido = await Pedido.findByPk(pedido_id, { include: INCLUDE_PEDIDO_COMPLETO });
  if (!pedido) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  if (pedido.estado !== 'pendiente') throw Object.assign(new Error('El pedido no está pendiente'), { status: 409 });
  if (!pedido.sesion_caja_id) throw Object.assign(new Error('No hay sesión de caja activa en este pedido'), { status: 409 });

  const sesion = await SesionCaja.findByPk(pedido.sesion_caja_id);
  if (!sesion || sesion.estado !== 'abierta') throw Object.assign(new Error('La sesión de caja está cerrada'), { status: 409 });

  const monto_neto = parseFloat(pedido.total) - parseFloat(descuento) + parseFloat(propina);

  if (metodo_pago === 'efectivo') {
    if (!monto_recibido || parseFloat(monto_recibido) < monto_neto) {
      throw Object.assign(new Error('Monto recibido insuficiente'), { status: 400 });
    }
  }

  const cambio = metodo_pago === 'efectivo' ? parseFloat(monto_recibido) - monto_neto : 0;

  await pedido.update({
    estado: 'completado',
    metodo_pago,
    monto_recibido: monto_recibido || monto_neto,
    cambio,
    descuento,
    propina,
  });

  // Liberar mesa si no quedan pedidos pendientes
  const pendientes = await Pedido.count({ where: { mesa_id: pedido.mesa_id, estado: 'pendiente' } });
  if (pendientes === 0) {
    await Mesa.update({ estado: 'disponible' }, { where: { id: pedido.mesa_id } });
  }

  // Registrar en libro caja
  await LibroCaja.create({
    sesion_caja_id: pedido.sesion_caja_id,
    usuario_id,
    tipo: 'ingreso',
    concepto: `Venta #${pedido.id}`,
    monto: monto_neto,
    metodo_pago,
    referencia_id: pedido.id,
  });

  // Actualizar total_ventas de la sesión
  await SesionCaja.increment('total_ventas', { by: monto_neto, where: { id: pedido.sesion_caja_id } });

  return obtener(pedido_id);
}

async function cancelar(pedido_id, usuario_id) {
  const pedido = await Pedido.findByPk(pedido_id);
  if (!pedido) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  if (pedido.estado !== 'pendiente') throw Object.assign(new Error('Solo se pueden cancelar pedidos pendientes'), { status: 409 });

  await pedido.update({ estado: 'cancelado' });

  const pendientes = await Pedido.count({ where: { mesa_id: pedido.mesa_id, estado: 'pendiente' } });
  if (pendientes === 0) {
    await Mesa.update({ estado: 'disponible' }, { where: { id: pedido.mesa_id } });
  }

  return obtener(pedido_id);
}

async function _recalcularTotal(pedido_id) {
  const { sequelize } = require('../../models');
  const [result] = await sequelize.query(
    'SELECT COALESCE(SUM(cantidad * precio), 0) as total FROM detalle_pedidos WHERE pedido_id = ?',
    { replacements: [pedido_id], type: sequelize.QueryTypes.SELECT }
  );
  await Pedido.update({ total: result.total }, { where: { id: pedido_id } });
}

module.exports = { listar, obtener, crear, agregarItem, actualizarItem, eliminarItem, cobrar, cancelar };
```

- [ ] **Step 4: Crear `src/modules/ventas/ventas.controller.js`**

```js
const svc = require('./ventas.service');

async function listar(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listar(req.query) }); }
  catch (err) { next(err); }
}

async function obtener(req, res, next) {
  try { res.json({ ok: true, datos: await svc.obtener(req.params.id) }); }
  catch (err) { next(err); }
}

async function crear(req, res, next) {
  try {
    const { mesa_id } = req.body;
    if (!mesa_id) return res.status(400).json({ ok: false, mensaje: 'mesa_id es requerido' });
    const datos = { ...req.body, usuario_id: req.usuario.id };
    res.status(201).json({ ok: true, datos: await svc.crear(datos) });
  } catch (err) { next(err); }
}

async function agregarItem(req, res, next) {
  try {
    const { producto_id, cantidad, nota } = req.body;
    if (!producto_id) return res.status(400).json({ ok: false, mensaje: 'producto_id es requerido' });
    res.status(201).json({ ok: true, datos: await svc.agregarItem(req.params.id, { producto_id, cantidad, nota }) });
  } catch (err) { next(err); }
}

async function actualizarItem(req, res, next) {
  try { res.json({ ok: true, datos: await svc.actualizarItem(req.params.id, req.params.item_id, req.body) }); }
  catch (err) { next(err); }
}

async function eliminarItem(req, res, next) {
  try { await svc.eliminarItem(req.params.id, req.params.item_id); res.json({ ok: true, datos: null }); }
  catch (err) { next(err); }
}

async function cobrar(req, res, next) {
  try {
    const { metodo_pago } = req.body;
    if (!metodo_pago) return res.status(400).json({ ok: false, mensaje: 'metodo_pago es requerido (efectivo|qr)' });
    res.json({ ok: true, datos: await svc.cobrar(req.params.id, req.usuario.id, req.body) });
  } catch (err) { next(err); }
}

async function cancelar(req, res, next) {
  try { res.json({ ok: true, datos: await svc.cancelar(req.params.id, req.usuario.id) }); }
  catch (err) { next(err); }
}

module.exports = { listar, obtener, crear, agregarItem, actualizarItem, eliminarItem, cobrar, cancelar };
```

- [ ] **Step 5: Crear `src/modules/ventas/ventas.routes.js`**

```js
const { Router } = require('express');
const ctrl = require('./ventas.controller');
const auth = require('../../middlewares/auth');
const { verificarPermiso } = require('../../middlewares/permisos');

const router = Router();
router.use(auth);

router.get('/', verificarPermiso('ventas', 'ver'), ctrl.listar);
router.post('/', verificarPermiso('ventas', 'crear'), ctrl.crear);
router.get('/:id', verificarPermiso('ventas', 'ver'), ctrl.obtener);
router.post('/:id/items', verificarPermiso('ventas', 'crear'), ctrl.agregarItem);
router.put('/:id/items/:item_id', verificarPermiso('ventas', 'crear'), ctrl.actualizarItem);
router.delete('/:id/items/:item_id', verificarPermiso('ventas', 'crear'), ctrl.eliminarItem);
router.post('/:id/cobrar', verificarPermiso('ventas', 'cobrar'), ctrl.cobrar);
router.post('/:id/cancelar', verificarPermiso('ventas', 'cancelar'), ctrl.cancelar);

module.exports = router;
```

- [ ] **Step 6: Registrar en `src/app.js`**

```js
const ventasRoutes = require('./modules/ventas/ventas.routes');
```

```js
app.use('/api/v1/ventas', ventasRoutes);
```

- [ ] **Step 7: Correr tests**

```bash
npx jest tests/ventas.test.js --no-coverage 2>&1 | head -20
```

Esperado: PASS.

- [ ] **Step 8: Commit**

```bash
git add src/modules/ventas/ src/app.js tests/ventas.test.js
git commit -m "feat: módulo ventas POS con cobro, items y cancelación"
```

---

### Task 7: Módulo Libro Caja

**Files:**
- Create: `src/modules/libro_caja/libro_caja.service.js`
- Create: `src/modules/libro_caja/libro_caja.controller.js`
- Create: `src/modules/libro_caja/libro_caja.routes.js`
- Modify: `src/app.js`
- Create: `tests/libro_caja.test.js`

**Interfaces:**
- Consumes: `LibroCaja`, `SesionCaja`, `Usuario` de models (LibroCaja ya existe desde Task 5)
- Produces: rutas `/api/v1/libro-caja`

- [ ] **Step 1: Escribir test que falla**

Crear `tests/libro_caja.test.js`:

```js
const request = require('supertest');
const app = require('../src/app');

describe('Libro Caja API', () => {
  it('GET /api/v1/libro-caja sin token → 401', async () => {
    const res = await request(app).get('/api/v1/libro-caja');
    expect(res.status).toBe(401);
  });
});
```

- [ ] **Step 2: Correr test y verificar que falla**

```bash
npx jest tests/libro_caja.test.js --no-coverage 2>&1 | head -20
```

- [ ] **Step 3: Crear `src/modules/libro_caja/libro_caja.service.js`**

```js
const { LibroCaja, SesionCaja, Usuario } = require('../../models');

const INCLUDE_LB = [
  { model: SesionCaja, as: 'sesion_caja', attributes: ['id', 'estado', 'abierto_en'] },
  { model: Usuario, as: 'usuario', attributes: ['id', 'nombre'] },
];

async function listar({ sesion_caja_id } = {}) {
  const where = {};
  if (sesion_caja_id) where.sesion_caja_id = sesion_caja_id;
  return LibroCaja.findAll({ where, include: INCLUDE_LB, order: [['creado_en', 'DESC']] });
}

async function crear(usuario_id, { sesion_caja_id, tipo, concepto, monto, metodo_pago = 'efectivo' }) {
  if (!['ingreso', 'egreso'].includes(tipo)) throw Object.assign(new Error('tipo debe ser ingreso o egreso'), { status: 400 });
  return LibroCaja.create({ sesion_caja_id, usuario_id, tipo, concepto, monto, metodo_pago });
}

module.exports = { listar, crear };
```

- [ ] **Step 4: Crear `src/modules/libro_caja/libro_caja.controller.js`**

```js
const svc = require('./libro_caja.service');

async function listar(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listar(req.query) }); }
  catch (err) { next(err); }
}

async function crear(req, res, next) {
  try {
    const { tipo, concepto, monto } = req.body;
    if (!tipo || !concepto || monto === undefined) {
      return res.status(400).json({ ok: false, mensaje: 'tipo, concepto y monto son requeridos' });
    }
    res.status(201).json({ ok: true, datos: await svc.crear(req.usuario.id, req.body) });
  } catch (err) { next(err); }
}

module.exports = { listar, crear };
```

- [ ] **Step 5: Crear `src/modules/libro_caja/libro_caja.routes.js`**

```js
const { Router } = require('express');
const ctrl = require('./libro_caja.controller');
const auth = require('../../middlewares/auth');
const { verificarPermiso } = require('../../middlewares/permisos');

const router = Router();
router.use(auth);

router.get('/', verificarPermiso('libro_caja', 'ver'), ctrl.listar);
router.post('/', verificarPermiso('libro_caja', 'crear'), ctrl.crear);

module.exports = router;
```

- [ ] **Step 6: Registrar en `src/app.js`**

```js
const libroCajaRoutes = require('./modules/libro_caja/libro_caja.routes');
```

```js
app.use('/api/v1/libro-caja', libroCajaRoutes);
```

- [ ] **Step 7: Correr tests**

```bash
npx jest tests/libro_caja.test.js --no-coverage 2>&1 | head -20
```

Esperado: PASS.

- [ ] **Step 8: Commit**

```bash
git add src/modules/libro_caja/ src/app.js tests/libro_caja.test.js
git commit -m "feat: módulo libro caja con listado por sesión"
```

---

### Task 8: Módulo Compras y Proveedores

**Files:**
- Create: `src/models/Proveedor.js`
- Create: `src/models/Compra.js`
- Create: `src/models/DetalleCompra.js`
- Modify: `src/models/index.js`
- Create: `src/modules/compras/compras.service.js`
- Create: `src/modules/compras/compras.controller.js`
- Create: `src/modules/compras/compras.routes.js`
- Create: `src/modules/compras/proveedores.routes.js`
- Modify: `src/app.js`
- Create: `tests/compras.test.js`

**Interfaces:**
- Consumes: `Proveedor`, `Compra`, `DetalleCompra`, `Producto`, `Usuario` de models
- Produces: rutas `/api/v1/proveedores` y `/api/v1/compras`

- [ ] **Step 1: Escribir test que falla**

Crear `tests/compras.test.js`:

```js
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
```

- [ ] **Step 2: Correr test y verificar que falla**

```bash
npx jest tests/compras.test.js --no-coverage 2>&1 | head -20
```

- [ ] **Step 3: Crear `src/models/Proveedor.js`**

```js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Proveedor = sequelize.define('Proveedor', {
  id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
  nombre: { type: DataTypes.STRING(255), allowNull: false },
  contacto: { type: DataTypes.STRING(255) },
  telefono: { type: DataTypes.STRING(50) },
  email: { type: DataTypes.STRING(255) },
  direccion: { type: DataTypes.STRING(255) },
  activo: { type: DataTypes.TINYINT(1), defaultValue: 1 },
}, { tableName: 'proveedores', createdAt: 'creado_en', updatedAt: 'actualizado_en' });

module.exports = Proveedor;
```

- [ ] **Step 4: Crear `src/models/Compra.js`**

```js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Compra = sequelize.define('Compra', {
  id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
  proveedor_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
  usuario_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
  total: { type: DataTypes.DECIMAL(10, 2), defaultValue: 0 },
  notas: { type: DataTypes.TEXT },
  estado: { type: DataTypes.ENUM('pendiente', 'recibido'), defaultValue: 'pendiente' },
}, { tableName: 'compras', createdAt: 'creado_en', updatedAt: 'actualizado_en' });

module.exports = Compra;
```

- [ ] **Step 5: Crear `src/models/DetalleCompra.js`**

```js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const DetalleCompra = sequelize.define('DetalleCompra', {
  id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
  compra_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
  producto_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
  cantidad: { type: DataTypes.INTEGER, allowNull: false },
  costo_unitario: { type: DataTypes.DECIMAL(10, 2), allowNull: false },
  subtotal: { type: DataTypes.DECIMAL(10, 2), allowNull: false },
}, { tableName: 'detalle_compras', timestamps: false });

module.exports = DetalleCompra;
```

- [ ] **Step 6: Actualizar `src/models/index.js`**

Agregar imports:
```js
const Proveedor = require('./Proveedor');
const Compra = require('./Compra');
const DetalleCompra = require('./DetalleCompra');
```

Agregar asociaciones:
```js
// Compras
Proveedor.hasMany(Compra, { foreignKey: 'proveedor_id', as: 'compras' });
Compra.belongsTo(Proveedor, { foreignKey: 'proveedor_id', as: 'proveedor' });
Compra.belongsTo(Usuario, { foreignKey: 'usuario_id', as: 'usuario' });
Compra.hasMany(DetalleCompra, { foreignKey: 'compra_id', as: 'detalles' });
DetalleCompra.belongsTo(Compra, { foreignKey: 'compra_id' });
DetalleCompra.belongsTo(Producto, { foreignKey: 'producto_id', as: 'producto' });
```

Agregar al `module.exports`:
```js
module.exports = {
  sequelize,
  Rol, Permiso, Usuario,
  Area, Mesa,
  Categoria, Producto,
  Cliente,
  SesionCaja, Pedido, DetallePedido,
  DetalleArqueo, Gasto, LibroCaja,
  Proveedor, Compra, DetalleCompra,
};
```

- [ ] **Step 7: Crear `src/modules/compras/compras.service.js`**

```js
const { Proveedor, Compra, DetalleCompra, Producto } = require('../../models');

const INCLUDE_COMPRA = [
  { model: Proveedor, as: 'proveedor', attributes: ['id', 'nombre'] },
  {
    model: DetalleCompra, as: 'detalles',
    include: [{ model: Producto, as: 'producto', attributes: ['id', 'nombre', 'stock'] }],
  },
];

// --- Proveedores ---

async function listarProveedores() {
  return Proveedor.findAll({ where: { activo: 1 }, order: [['nombre', 'ASC']] });
}

async function crearProveedor({ nombre, contacto, telefono, email, direccion }) {
  return Proveedor.create({ nombre, contacto, telefono, email, direccion });
}

async function actualizarProveedor(id, datos) {
  const p = await Proveedor.findByPk(id);
  if (!p) throw Object.assign(new Error('Proveedor no encontrado'), { status: 404 });
  await p.update(datos);
  return p;
}

async function desactivarProveedor(id) {
  const p = await Proveedor.findByPk(id);
  if (!p) throw Object.assign(new Error('Proveedor no encontrado'), { status: 404 });
  await p.update({ activo: 0 });
}

// --- Compras ---

async function listarCompras() {
  return Compra.findAll({ include: INCLUDE_COMPRA, order: [['creado_en', 'DESC']] });
}

async function obtenerCompra(id) {
  const c = await Compra.findByPk(id, { include: INCLUDE_COMPRA });
  if (!c) throw Object.assign(new Error('Compra no encontrada'), { status: 404 });
  return c;
}

async function crearCompra(usuario_id, { proveedor_id, notas, items = [] }) {
  const proveedor = await Proveedor.findByPk(proveedor_id);
  if (!proveedor) throw Object.assign(new Error('Proveedor no encontrado'), { status: 404 });

  const total = items.reduce((sum, i) => sum + (parseFloat(i.costo_unitario) * parseInt(i.cantidad)), 0);

  const compra = await Compra.create({ proveedor_id, usuario_id, total, notas });

  await DetalleCompra.bulkCreate(
    items.map(i => ({
      compra_id: compra.id,
      producto_id: i.producto_id,
      cantidad: i.cantidad,
      costo_unitario: i.costo_unitario,
      subtotal: parseFloat(i.costo_unitario) * parseInt(i.cantidad),
    }))
  );

  return obtenerCompra(compra.id);
}

async function actualizarCompra(id, { notas }) {
  const c = await Compra.findByPk(id);
  if (!c) throw Object.assign(new Error('Compra no encontrada'), { status: 404 });
  if (c.estado !== 'pendiente') throw Object.assign(new Error('Solo se pueden editar compras pendientes'), { status: 409 });
  await c.update({ notas });
  return obtenerCompra(id);
}

async function recibirCompra(id) {
  const compra = await Compra.findByPk(id, { include: INCLUDE_COMPRA });
  if (!compra) throw Object.assign(new Error('Compra no encontrada'), { status: 404 });
  if (compra.estado !== 'pendiente') throw Object.assign(new Error('La compra ya fue recibida'), { status: 409 });

  // Actualizar stock de cada producto
  for (const detalle of compra.detalles) {
    await Producto.increment('stock', { by: detalle.cantidad, where: { id: detalle.producto_id } });
  }

  await compra.update({ estado: 'recibido' });
  return obtenerCompra(id);
}

module.exports = { listarProveedores, crearProveedor, actualizarProveedor, desactivarProveedor, listarCompras, obtenerCompra, crearCompra, actualizarCompra, recibirCompra };
```

- [ ] **Step 8: Crear `src/modules/compras/compras.controller.js`**

```js
const svc = require('./compras.service');

async function listarProveedores(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listarProveedores() }); }
  catch (err) { next(err); }
}

async function crearProveedor(req, res, next) {
  try {
    if (!req.body.nombre) return res.status(400).json({ ok: false, mensaje: 'nombre es requerido' });
    res.status(201).json({ ok: true, datos: await svc.crearProveedor(req.body) });
  } catch (err) { next(err); }
}

async function actualizarProveedor(req, res, next) {
  try { res.json({ ok: true, datos: await svc.actualizarProveedor(req.params.id, req.body) }); }
  catch (err) { next(err); }
}

async function desactivarProveedor(req, res, next) {
  try { await svc.desactivarProveedor(req.params.id); res.json({ ok: true, datos: null }); }
  catch (err) { next(err); }
}

async function listarCompras(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listarCompras() }); }
  catch (err) { next(err); }
}

async function obtenerCompra(req, res, next) {
  try { res.json({ ok: true, datos: await svc.obtenerCompra(req.params.id) }); }
  catch (err) { next(err); }
}

async function crearCompra(req, res, next) {
  try {
    const { proveedor_id, items } = req.body;
    if (!proveedor_id || !items || !items.length) {
      return res.status(400).json({ ok: false, mensaje: 'proveedor_id e items son requeridos' });
    }
    res.status(201).json({ ok: true, datos: await svc.crearCompra(req.usuario.id, req.body) });
  } catch (err) { next(err); }
}

async function actualizarCompra(req, res, next) {
  try { res.json({ ok: true, datos: await svc.actualizarCompra(req.params.id, req.body) }); }
  catch (err) { next(err); }
}

async function recibirCompra(req, res, next) {
  try { res.json({ ok: true, datos: await svc.recibirCompra(req.params.id) }); }
  catch (err) { next(err); }
}

module.exports = { listarProveedores, crearProveedor, actualizarProveedor, desactivarProveedor, listarCompras, obtenerCompra, crearCompra, actualizarCompra, recibirCompra };
```

- [ ] **Step 9: Crear `src/modules/compras/proveedores.routes.js`**

```js
const { Router } = require('express');
const ctrl = require('./compras.controller');
const auth = require('../../middlewares/auth');
const { verificarPermiso } = require('../../middlewares/permisos');

const router = Router();
router.use(auth);

router.get('/', verificarPermiso('proveedores', 'ver'), ctrl.listarProveedores);
router.post('/', verificarPermiso('proveedores', 'crear'), ctrl.crearProveedor);
router.put('/:id', verificarPermiso('proveedores', 'editar'), ctrl.actualizarProveedor);
router.delete('/:id', verificarPermiso('proveedores', 'editar'), ctrl.desactivarProveedor);

module.exports = router;
```

- [ ] **Step 10: Crear `src/modules/compras/compras.routes.js`**

```js
const { Router } = require('express');
const ctrl = require('./compras.controller');
const auth = require('../../middlewares/auth');
const { verificarPermiso } = require('../../middlewares/permisos');

const router = Router();
router.use(auth);

router.get('/', verificarPermiso('compras', 'ver'), ctrl.listarCompras);
router.post('/', verificarPermiso('compras', 'crear'), ctrl.crearCompra);
router.get('/:id', verificarPermiso('compras', 'ver'), ctrl.obtenerCompra);
router.put('/:id', verificarPermiso('compras', 'editar'), ctrl.actualizarCompra);
router.put('/:id/recibir', verificarPermiso('compras', 'recibir'), ctrl.recibirCompra);

module.exports = router;
```

- [ ] **Step 11: Registrar en `src/app.js`**

```js
const comprasRoutes = require('./modules/compras/compras.routes');
const proveedoresRoutes = require('./modules/compras/proveedores.routes');
```

```js
app.use('/api/v1/compras', comprasRoutes);
app.use('/api/v1/proveedores', proveedoresRoutes);
```

- [ ] **Step 12: Correr tests**

```bash
npx jest tests/compras.test.js --no-coverage 2>&1 | head -20
```

Esperado: PASS.

- [ ] **Step 13: Commit**

```bash
git add src/models/Proveedor.js src/models/Compra.js src/models/DetalleCompra.js src/models/index.js src/modules/compras/ src/app.js tests/compras.test.js
git commit -m "feat: módulo compras y proveedores con recepción de stock"
```

---

### Task 9: Módulo Inventario

**Files:**
- Create: `src/models/RegistroInventario.js`
- Modify: `src/models/index.js`
- Create: `src/modules/inventario/inventario.service.js`
- Create: `src/modules/inventario/inventario.controller.js`
- Create: `src/modules/inventario/inventario.routes.js`
- Modify: `src/app.js`
- Create: `tests/inventario.test.js`

**Interfaces:**
- Consumes: `RegistroInventario`, `Producto`, `Usuario` de models
- Produces: rutas `/api/v1/inventario`

- [ ] **Step 1: Escribir test que falla**

Crear `tests/inventario.test.js`:

```js
const request = require('supertest');
const app = require('../src/app');

describe('Inventario API', () => {
  it('GET /api/v1/inventario sin token → 401', async () => {
    const res = await request(app).get('/api/v1/inventario');
    expect(res.status).toBe(401);
  });
});
```

- [ ] **Step 2: Correr test y verificar que falla**

```bash
npx jest tests/inventario.test.js --no-coverage 2>&1 | head -20
```

- [ ] **Step 3: Crear `src/models/RegistroInventario.js`**

```js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const RegistroInventario = sequelize.define('RegistroInventario', {
  id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
  producto_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
  usuario_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
  tipo: { type: DataTypes.ENUM('entrada', 'salida', 'venta', 'compra', 'ajuste'), allowNull: false },
  cantidad: { type: DataTypes.INTEGER, allowNull: false },
  stock_anterior: { type: DataTypes.INTEGER },
  stock_nuevo: { type: DataTypes.INTEGER },
  nota: { type: DataTypes.STRING(255) },
}, { tableName: 'registros_inventario', createdAt: 'creado_en', updatedAt: 'actualizado_en' });

module.exports = RegistroInventario;
```

- [ ] **Step 4: Actualizar `src/models/index.js`**

Agregar import:
```js
const RegistroInventario = require('./RegistroInventario');
```

Agregar asociaciones:
```js
// Inventario
RegistroInventario.belongsTo(Producto, { foreignKey: 'producto_id', as: 'producto' });
RegistroInventario.belongsTo(Usuario, { foreignKey: 'usuario_id', as: 'usuario' });
Producto.hasMany(RegistroInventario, { foreignKey: 'producto_id', as: 'movimientos' });
```

Agregar al `module.exports`:
```js
module.exports = {
  sequelize,
  Rol, Permiso, Usuario,
  Area, Mesa,
  Categoria, Producto,
  Cliente,
  SesionCaja, Pedido, DetallePedido,
  DetalleArqueo, Gasto, LibroCaja,
  Proveedor, Compra, DetalleCompra,
  RegistroInventario,
};
```

- [ ] **Step 5: Crear `src/modules/inventario/inventario.service.js`**

```js
const { RegistroInventario, Producto, Usuario } = require('../../models');

const INCLUDE_REGISTRO = [
  { model: Producto, as: 'producto', attributes: ['id', 'nombre', 'stock'] },
  { model: Usuario, as: 'usuario', attributes: ['id', 'nombre'] },
];

async function listar({ producto_id } = {}) {
  const where = {};
  if (producto_id) where.producto_id = producto_id;
  return RegistroInventario.findAll({ where, include: INCLUDE_REGISTRO, order: [['creado_en', 'DESC']], limit: 200 });
}

async function listarPorProducto(producto_id) {
  const producto = await Producto.findByPk(producto_id);
  if (!producto) throw Object.assign(new Error('Producto no encontrado'), { status: 404 });
  return RegistroInventario.findAll({
    where: { producto_id },
    include: INCLUDE_REGISTRO,
    order: [['creado_en', 'DESC']],
  });
}

async function _movimiento(usuario_id, producto_id, tipo, cantidad, nota) {
  const producto = await Producto.findByPk(producto_id);
  if (!producto) throw Object.assign(new Error('Producto no encontrado'), { status: 404 });

  const stock_anterior = producto.stock || 0;
  let stock_nuevo;

  if (tipo === 'entrada' || tipo === 'compra') {
    stock_nuevo = stock_anterior + cantidad;
  } else if (tipo === 'salida' || tipo === 'venta') {
    if (stock_anterior < cantidad) throw Object.assign(new Error('Stock insuficiente'), { status: 409 });
    stock_nuevo = stock_anterior - cantidad;
  } else if (tipo === 'ajuste') {
    stock_nuevo = cantidad; // ajuste fija el valor absoluto
  }

  await Producto.update({ stock: stock_nuevo }, { where: { id: producto_id } });

  return RegistroInventario.create({ producto_id, usuario_id, tipo, cantidad, stock_anterior, stock_nuevo, nota });
}

async function entrada(usuario_id, { producto_id, cantidad, nota }) {
  return _movimiento(usuario_id, producto_id, 'entrada', cantidad, nota);
}

async function salida(usuario_id, { producto_id, cantidad, nota }) {
  return _movimiento(usuario_id, producto_id, 'salida', cantidad, nota);
}

async function ajuste(usuario_id, { producto_id, cantidad, nota }) {
  return _movimiento(usuario_id, producto_id, 'ajuste', cantidad, nota);
}

module.exports = { listar, listarPorProducto, entrada, salida, ajuste };
```

- [ ] **Step 6: Crear `src/modules/inventario/inventario.controller.js`**

```js
const svc = require('./inventario.service');

async function listar(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listar(req.query) }); }
  catch (err) { next(err); }
}

async function listarPorProducto(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listarPorProducto(req.params.id) }); }
  catch (err) { next(err); }
}

async function entrada(req, res, next) {
  try {
    const { producto_id, cantidad } = req.body;
    if (!producto_id || !cantidad) return res.status(400).json({ ok: false, mensaje: 'producto_id y cantidad son requeridos' });
    res.status(201).json({ ok: true, datos: await svc.entrada(req.usuario.id, req.body) });
  } catch (err) { next(err); }
}

async function salida(req, res, next) {
  try {
    const { producto_id, cantidad } = req.body;
    if (!producto_id || !cantidad) return res.status(400).json({ ok: false, mensaje: 'producto_id y cantidad son requeridos' });
    res.status(201).json({ ok: true, datos: await svc.salida(req.usuario.id, req.body) });
  } catch (err) { next(err); }
}

async function ajuste(req, res, next) {
  try {
    const { producto_id, cantidad } = req.body;
    if (!producto_id || cantidad === undefined) return res.status(400).json({ ok: false, mensaje: 'producto_id y cantidad son requeridos' });
    res.status(201).json({ ok: true, datos: await svc.ajuste(req.usuario.id, req.body) });
  } catch (err) { next(err); }
}

module.exports = { listar, listarPorProducto, entrada, salida, ajuste };
```

- [ ] **Step 7: Crear `src/modules/inventario/inventario.routes.js`**

```js
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

- [ ] **Step 8: Registrar en `src/app.js`**

```js
const inventarioRoutes = require('./modules/inventario/inventario.routes');
```

```js
app.use('/api/v1/inventario', inventarioRoutes);
```

- [ ] **Step 9: Correr tests**

```bash
npx jest tests/inventario.test.js --no-coverage 2>&1 | head -20
```

Esperado: PASS.

- [ ] **Step 10: Commit**

```bash
git add src/models/RegistroInventario.js src/models/index.js src/modules/inventario/ src/app.js tests/inventario.test.js
git commit -m "feat: módulo inventario con entradas, salidas y ajustes de stock"
```

---

### Task 10: Módulo Configuración

**Files:**
- Create: `src/models/Configuracion.js`
- Modify: `src/models/index.js`
- Create: `src/modules/configuracion/configuracion.service.js`
- Create: `src/modules/configuracion/configuracion.controller.js`
- Create: `src/modules/configuracion/configuracion.routes.js`
- Modify: `src/app.js`
- Create: `tests/configuracion.test.js`

**Interfaces:**
- Consumes: `Configuracion` de models
- Produces: rutas `/api/v1/configuracion`

- [ ] **Step 1: Escribir test que falla**

Crear `tests/configuracion.test.js`:

```js
const request = require('supertest');
const app = require('../src/app');

describe('Configuración API', () => {
  it('GET /api/v1/configuracion sin token → 401', async () => {
    const res = await request(app).get('/api/v1/configuracion');
    expect(res.status).toBe(401);
  });
});
```

- [ ] **Step 2: Correr test y verificar que falla**

```bash
npx jest tests/configuracion.test.js --no-coverage 2>&1 | head -20
```

- [ ] **Step 3: Crear `src/models/Configuracion.js`**

```js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Configuracion = sequelize.define('Configuracion', {
  id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
  clave: { type: DataTypes.STRING(100), allowNull: false, unique: true },
  valor: { type: DataTypes.TEXT },
}, { tableName: 'configuraciones', createdAt: 'creado_en', updatedAt: 'actualizado_en' });

module.exports = Configuracion;
```

- [ ] **Step 4: Actualizar `src/models/index.js`**

Agregar import:
```js
const Configuracion = require('./Configuracion');
```

Agregar al `module.exports` (no requiere asociaciones):
```js
module.exports = {
  sequelize,
  Rol, Permiso, Usuario,
  Area, Mesa,
  Categoria, Producto,
  Cliente,
  SesionCaja, Pedido, DetallePedido,
  DetalleArqueo, Gasto, LibroCaja,
  Proveedor, Compra, DetalleCompra,
  RegistroInventario,
  Configuracion,
};
```

- [ ] **Step 5: Crear `src/modules/configuracion/configuracion.service.js`**

```js
const { Configuracion } = require('../../models');

async function obtenerTodo() {
  const configs = await Configuracion.findAll({ order: [['clave', 'ASC']] });
  return configs.reduce((obj, c) => {
    obj[c.clave] = c.valor;
    return obj;
  }, {});
}

async function actualizar(pares) {
  // pares: objeto { clave: valor, clave2: valor2 }
  const claves = Object.keys(pares);
  for (const clave of claves) {
    await Configuracion.upsert({ clave, valor: pares[clave] });
  }
  return obtenerTodo();
}

module.exports = { obtenerTodo, actualizar };
```

- [ ] **Step 6: Crear `src/modules/configuracion/configuracion.controller.js`**

```js
const svc = require('./configuracion.service');

async function obtenerTodo(req, res, next) {
  try { res.json({ ok: true, datos: await svc.obtenerTodo() }); }
  catch (err) { next(err); }
}

async function actualizar(req, res, next) {
  try {
    if (!req.body || typeof req.body !== 'object') {
      return res.status(400).json({ ok: false, mensaje: 'Body debe ser un objeto { clave: valor }' });
    }
    res.json({ ok: true, datos: await svc.actualizar(req.body) });
  } catch (err) { next(err); }
}

module.exports = { obtenerTodo, actualizar };
```

- [ ] **Step 7: Crear `src/modules/configuracion/configuracion.routes.js`**

```js
const { Router } = require('express');
const ctrl = require('./configuracion.controller');
const auth = require('../../middlewares/auth');
const { verificarPermiso } = require('../../middlewares/permisos');

const router = Router();
router.use(auth);

router.get('/', verificarPermiso('configuracion', 'ver'), ctrl.obtenerTodo);
router.put('/', verificarPermiso('configuracion', 'editar'), ctrl.actualizar);

module.exports = router;
```

- [ ] **Step 8: Registrar en `src/app.js`**

```js
const configuracionRoutes = require('./modules/configuracion/configuracion.routes');
```

```js
app.use('/api/v1/configuracion', configuracionRoutes);
```

- [ ] **Step 9: Correr todos los tests**

```bash
npx jest --no-coverage 2>&1 | tail -20
```

Esperado: todos los tests sin-token (401) pasan. Tests de DB fallan si MySQL no está activo — comportamiento esperado.

- [ ] **Step 10: Commit**

```bash
git add src/models/Configuracion.js src/models/index.js src/modules/configuracion/ src/app.js tests/configuracion.test.js
git commit -m "feat: módulo configuración con lectura y actualización de parámetros"
```

---

### Task 11: Módulo Reservaciones

**Files:**
- Create: `src/models/Reservacion.js`
- Modify: `src/models/index.js`
- Create: `src/modules/reservaciones/reservaciones.service.js`
- Create: `src/modules/reservaciones/reservaciones.controller.js`
- Create: `src/modules/reservaciones/reservaciones.routes.js`
- Modify: `src/app.js`
- Create: `tests/reservaciones.test.js`

**Interfaces:**
- Consumes: `Reservacion`, `Mesa` de models
- Produces: rutas `/api/v1/reservaciones`
- Nota: No hay permisos específicos `reservaciones.*` en el seed. Usar `ventas.ver` para GET y `ventas.crear` para crear/actualizar/cancelar.

- [ ] **Step 1: Escribir test que falla**

Crear `tests/reservaciones.test.js`:

```js
const request = require('supertest');
const app = require('../src/app');

describe('Reservaciones API', () => {
  it('GET /api/v1/reservaciones sin token → 401', async () => {
    const res = await request(app).get('/api/v1/reservaciones');
    expect(res.status).toBe(401);
  });
});
```

- [ ] **Step 2: Correr test y verificar que falla**

```bash
npx jest tests/reservaciones.test.js --no-coverage 2>&1 | head -20
```

- [ ] **Step 3: Crear `src/models/Reservacion.js`**

```js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Reservacion = sequelize.define('Reservacion', {
  id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
  nombre_cliente: { type: DataTypes.STRING(255), allowNull: false },
  telefono: { type: DataTypes.STRING(50) },
  hora_reserva: { type: DataTypes.DATE, allowNull: false },
  personas: { type: DataTypes.INTEGER, allowNull: false },
  mesa_id: { type: DataTypes.INTEGER.UNSIGNED },
  nota: { type: DataTypes.TEXT },
  estado: { type: DataTypes.ENUM('pendiente', 'confirmada', 'cancelada'), defaultValue: 'pendiente' },
}, { tableName: 'reservaciones', createdAt: 'creado_en', updatedAt: 'actualizado_en' });

module.exports = Reservacion;
```

- [ ] **Step 4: Actualizar `src/models/index.js`**

Agregar import:
```js
const Reservacion = require('./Reservacion');
```

Agregar asociaciones:
```js
// Reservaciones
Reservacion.belongsTo(Mesa, { foreignKey: 'mesa_id', as: 'mesa' });
Mesa.hasMany(Reservacion, { foreignKey: 'mesa_id', as: 'reservaciones' });
```

Agregar al `module.exports`:
```js
module.exports = {
  sequelize,
  Rol, Permiso, Usuario,
  Area, Mesa,
  Categoria, Producto,
  Cliente,
  SesionCaja, Pedido, DetallePedido,
  DetalleArqueo, Gasto, LibroCaja,
  Proveedor, Compra, DetalleCompra,
  RegistroInventario,
  Configuracion,
  Reservacion,
};
```

- [ ] **Step 5: Crear `src/modules/reservaciones/reservaciones.service.js`**

```js
const { Op } = require('sequelize');
const { Reservacion, Mesa } = require('../../models');

async function listar({ fecha, estado } = {}) {
  const where = {};
  if (estado) where.estado = estado;
  if (fecha) {
    const inicio = new Date(fecha);
    const fin = new Date(fecha);
    fin.setDate(fin.getDate() + 1);
    where.hora_reserva = { [Op.between]: [inicio, fin] };
  }
  return Reservacion.findAll({
    where,
    include: [{ model: Mesa, as: 'mesa', attributes: ['id', 'nombre'] }],
    order: [['hora_reserva', 'ASC']],
  });
}

async function obtener(id) {
  const r = await Reservacion.findByPk(id, {
    include: [{ model: Mesa, as: 'mesa', attributes: ['id', 'nombre'] }],
  });
  if (!r) throw Object.assign(new Error('Reservación no encontrada'), { status: 404 });
  return r;
}

async function crear({ nombre_cliente, telefono, hora_reserva, personas, mesa_id, nota }) {
  return Reservacion.create({ nombre_cliente, telefono, hora_reserva, personas, mesa_id, nota });
}

async function actualizar(id, datos) {
  const r = await Reservacion.findByPk(id);
  if (!r) throw Object.assign(new Error('Reservación no encontrada'), { status: 404 });
  if (r.estado === 'cancelada') throw Object.assign(new Error('No se puede modificar una reservación cancelada'), { status: 409 });
  await r.update(datos);
  return obtener(id);
}

async function cancelar(id) {
  const r = await Reservacion.findByPk(id);
  if (!r) throw Object.assign(new Error('Reservación no encontrada'), { status: 404 });
  await r.update({ estado: 'cancelada' });
  return r;
}

module.exports = { listar, obtener, crear, actualizar, cancelar };
```

- [ ] **Step 6: Crear `src/modules/reservaciones/reservaciones.controller.js`**

```js
const svc = require('./reservaciones.service');

async function listar(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listar(req.query) }); }
  catch (err) { next(err); }
}

async function obtener(req, res, next) {
  try { res.json({ ok: true, datos: await svc.obtener(req.params.id) }); }
  catch (err) { next(err); }
}

async function crear(req, res, next) {
  try {
    const { nombre_cliente, hora_reserva, personas } = req.body;
    if (!nombre_cliente || !hora_reserva || !personas) {
      return res.status(400).json({ ok: false, mensaje: 'nombre_cliente, hora_reserva y personas son requeridos' });
    }
    res.status(201).json({ ok: true, datos: await svc.crear(req.body) });
  } catch (err) { next(err); }
}

async function actualizar(req, res, next) {
  try { res.json({ ok: true, datos: await svc.actualizar(req.params.id, req.body) }); }
  catch (err) { next(err); }
}

async function cancelar(req, res, next) {
  try { res.json({ ok: true, datos: await svc.cancelar(req.params.id) }); }
  catch (err) { next(err); }
}

module.exports = { listar, obtener, crear, actualizar, cancelar };
```

- [ ] **Step 7: Crear `src/modules/reservaciones/reservaciones.routes.js`**

```js
const { Router } = require('express');
const ctrl = require('./reservaciones.controller');
const auth = require('../../middlewares/auth');
const { verificarPermiso } = require('../../middlewares/permisos');

const router = Router();
router.use(auth);

router.get('/', verificarPermiso('ventas', 'ver'), ctrl.listar);
router.post('/', verificarPermiso('ventas', 'crear'), ctrl.crear);
router.get('/:id', verificarPermiso('ventas', 'ver'), ctrl.obtener);
router.put('/:id', verificarPermiso('ventas', 'crear'), ctrl.actualizar);
router.post('/:id/cancelar', verificarPermiso('ventas', 'cancelar'), ctrl.cancelar);

module.exports = router;
```

- [ ] **Step 8: Registrar en `src/app.js`**

```js
const reservacionesRoutes = require('./modules/reservaciones/reservaciones.routes');
```

```js
app.use('/api/v1/reservaciones', reservacionesRoutes);
```

- [ ] **Step 9: Correr todos los tests del plan**

```bash
npx jest --no-coverage 2>&1 | tail -30
```

Esperado: todos los tests `sin token → 401` pasan (11 tests). Tests de negocio requieren MySQL activo.

- [ ] **Step 10: Commit**

```bash
git add src/models/Reservacion.js src/models/index.js src/modules/reservaciones/ src/app.js tests/reservaciones.test.js
git commit -m "feat: módulo reservaciones con filtro por fecha y estado"
```
