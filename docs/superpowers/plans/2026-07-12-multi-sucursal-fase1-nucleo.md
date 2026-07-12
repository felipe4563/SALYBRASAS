# Multi-sucursal — Fase 1: Núcleo — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let SALYBRASAS operate as a chain — usuarios can belong to one or more sucursales, sessions carry an active `sucursal_id`, and there's a working CRUD to manage sucursales and assign them to users. No operational module (mesas, inventario, ventas, caja, compras) filters by sucursal yet — that's Fase 2.

**Architecture:** New `sucursales` table + `usuarios_sucursales` many-to-many join table + `usuarios.acceso_todas_sucursales` flag. Login becomes a two-step flow when a user has more than one sucursal available: step 1 validates credentials and returns a short-lived `pre_token` plus the list of sucursales to choose from; step 2 exchanges `pre_token` + chosen `sucursal_id` for the real JWT (which now carries `sucursal_id` in its payload, `null` meaning "todas las sucursales"). `middlewares/auth.js` decodes that payload and exposes `req.usuario.sucursal_id` / `req.usuario.acceso_todas` for Fase 2 to consume later.

**Tech Stack:** Node.js/Express, Sequelize (MySQL), JWT (`jsonwebtoken`), Jest + Supertest (backend tests run against the real dev DB — no test DB/mocking in this codebase). React 18, React Router, Zustand (`persist`), TanStack Query, Tailwind, `axios`. No frontend test runner is configured — frontend tasks are verified manually against the dev server.

## Global Constraints

- Sequelize models follow the existing style in `backend/src/models/`: `sequelize.define('Nombre', {...}, { tableName: 'snake_case', createdAt: 'creado_en', updatedAt: 'actualizado_en' })`, no timestamps on join tables.
- API responses always use the envelope `{ ok: true, datos }` or `{ ok: false, mensaje }` (see `backend/src/middlewares/errores.js`).
- Route protection pattern: `router.use(auth)` then `verificarPermiso('modulo', 'accion')` per route (see `backend/src/middlewares/permisos.js`).
- Migrations (`backend/database/migrations/*.sql`) are schema-only (`CREATE TABLE IF NOT EXISTS`, `ALTER TABLE ... ADD COLUMN`), applied manually with `mysql -u root -p bd_restaurante < database/migrations/0NN_x.sql` against the local dev DB (per `backend/.env`: `DB_NAME=bd_restaurante`, `DB_USER=root`, empty password). They never contain data/INSERTs.
- All data provisioning (permission catalog, default rows, idempotent upserts) lives in `backend/database/seeds/seed.js`, using `findOrCreate` so it's safe to re-run against a populated DB (this is how existing permisos/roles/admin user are seeded — see lines 47-112 of that file).
- Backend tests (`backend/tests/*.test.js`) use `supertest` against `backend/src/app.js` directly, authenticating as `admin@restaurante.com` / `admin123` (or `process.env.ADMIN_PASSWORD`). Run with `npm test` (`jest --runInBand`) from `backend/`.
- Frontend API calls live in `frontend/src/api/*.js`, each a thin wrapper around the shared `axios` instance in `frontend/src/api/cliente.js`, returning `r.data.datos`.

---

### Task 1: Esquema de base de datos — sucursales, usuarios_sucursales, acceso_todas_sucursales

**Files:**
- Create: `backend/database/migrations/012_sucursales.sql`

**Interfaces:**
- Produces: table `sucursales(id, nombre, direccion, telefono, activo, creado_en, actualizado_en)`; table `usuarios_sucursales(usuario_id, sucursal_id)` (composite PK, `ON DELETE CASCADE` both sides); column `usuarios.acceso_todas_sucursales TINYINT(1) NOT NULL DEFAULT 0`. Task 2 depends on these existing.

- [ ] **Step 1: Write the migration file**

```sql
CREATE TABLE IF NOT EXISTS sucursales (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(255) NOT NULL,
  direccion VARCHAR(255),
  telefono VARCHAR(50),
  activo TINYINT(1) NOT NULL DEFAULT 1,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE usuarios
  ADD COLUMN acceso_todas_sucursales TINYINT(1) NOT NULL DEFAULT 0 AFTER rol_id;

CREATE TABLE IF NOT EXISTS usuarios_sucursales (
  usuario_id INT UNSIGNED NOT NULL,
  sucursal_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (usuario_id, sucursal_id),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
  FOREIGN KEY (sucursal_id) REFERENCES sucursales(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- [ ] **Step 2: Apply it to the local dev DB**

Run: `mysql -u root -p bd_restaurante < database/migrations/012_sucursales.sql` (from `backend/`; empty password, just press enter at the prompt per `backend/.env`).
Expected: no output, exit code 0.

- [ ] **Step 3: Verify the schema landed**

Run: `mysql -u root -p bd_restaurante -e "DESCRIBE sucursales; DESCRIBE usuarios_sucursales; SHOW COLUMNS FROM usuarios LIKE 'acceso_todas_sucursales';"`
Expected: three result sets — `sucursales` columns, `usuarios_sucursales` columns, and one row for `acceso_todas_sucursales` (`tinyint(1)`, default `0`).

- [ ] **Step 4: Commit**

```bash
git add backend/database/migrations/012_sucursales.sql
git commit -m "feat(db): add sucursales schema (multi-branch core)"
```

---

### Task 2: Modelos Sequelize y datos iniciales (Sucursal Principal)

**Files:**
- Create: `backend/src/models/Sucursal.js`
- Modify: `backend/src/models/Usuario.js`
- Modify: `backend/src/models/index.js`
- Modify: `backend/database/seeds/seed.js`

**Interfaces:**
- Consumes: tables from Task 1.
- Produces: `models/index.js` exports `Sucursal` alongside existing exports. `Usuario.belongsToMany(Sucursal, { as: 'sucursales' })` and `Sucursal.belongsToMany(Usuario, { as: 'usuarios' })`, giving every `Usuario`/`Sucursal` instance `getSucursales()/setSucursales()/addSucursal()/countUsuarios()` etc (standard Sequelize association methods). `Usuario` model gains `acceso_todas_sucursales` (boolean-ish `TINYINT(1)`, default `0`). After running the seed, a `sucursales` row named `"Sucursal Principal"` exists and every existing `usuarios` row is linked to it in `usuarios_sucursales`. Task 3+ rely on all of this.

- [ ] **Step 1: Create the `Sucursal` model**

```javascript
// backend/src/models/Sucursal.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Sucursal = sequelize.define('Sucursal', {
  id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
  nombre: { type: DataTypes.STRING(255), allowNull: false },
  direccion: { type: DataTypes.STRING(255) },
  telefono: { type: DataTypes.STRING(50) },
  activo: { type: DataTypes.TINYINT(1), defaultValue: 1 },
}, {
  tableName: 'sucursales',
  createdAt: 'creado_en',
  updatedAt: 'actualizado_en',
});

module.exports = Sucursal;
```

- [ ] **Step 2: Add `acceso_todas_sucursales` to the `Usuario` model**

In `backend/src/models/Usuario.js`, add the field right after `rol_id`:

```javascript
  rol_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
  acceso_todas_sucursales: { type: DataTypes.TINYINT(1), defaultValue: 0 },
```

- [ ] **Step 3: Wire the association in `models/index.js`**

Add near the top, alongside the existing `RolesPermisos` join definition:

```javascript
const UsuariosSucursales = sequelize.define('usuarios_sucursales', {
  usuario_id: { type: DataTypes.INTEGER.UNSIGNED },
  sucursal_id: { type: DataTypes.INTEGER.UNSIGNED },
}, { tableName: 'usuarios_sucursales', timestamps: false });
```

Add the require next to the other model requires:

```javascript
const Sucursal = require('./Sucursal');
```

Add the association block near the `// Usuario` section:

```javascript
// Sucursales
Usuario.belongsToMany(Sucursal, { through: UsuariosSucursales, foreignKey: 'usuario_id', otherKey: 'sucursal_id', as: 'sucursales' });
Sucursal.belongsToMany(Usuario, { through: UsuariosSucursales, foreignKey: 'sucursal_id', otherKey: 'usuario_id', as: 'usuarios' });
```

Add `Sucursal` to the final `module.exports` object.

- [ ] **Step 4: Verify the models load and associate correctly**

Run: `node -e "const {sequelize, Usuario, Sucursal} = require('./src/models'); sequelize.authenticate().then(() => Usuario.findOne({include:[{model:Sucursal,as:'sucursales'}]})).then(u => { console.log('OK', u ? u.sucursales : 'no rows yet'); process.exit(0); }).catch(e => { console.error(e.message); process.exit(1); });"` (from `backend/`)
Expected: prints `OK` (with an empty sucursales array or `no rows yet` since the seed hasn't run) and exits 0 — confirms the association doesn't throw.

- [ ] **Step 5: Add the `sucursales` permission catalog to the seed**

In `backend/database/seeds/seed.js`, add to the `PERMISOS` array (after the `roles` entries):

```javascript
  { modulo: 'sucursales', accion: 'ver', descripcion: 'Ver sucursales' },
  { modulo: 'sucursales', accion: 'crear', descripcion: 'Crear sucursales' },
  { modulo: 'sucursales', accion: 'editar', descripcion: 'Editar sucursales' },
  { modulo: 'sucursales', accion: 'eliminar', descripcion: 'Eliminar sucursales' },
```

This is automatically granted to `Administrador` because that role already does `await admin.setPermisos(permisosCreados)` with the full list — no other seed change needed for that role.

- [ ] **Step 6: Seed the default "Sucursal Principal" and backfill existing users**

In `backend/database/seeds/seed.js`, update the model import at the top:

```javascript
const { sequelize, Rol, Permiso, Usuario, Sucursal } = require('../../src/models');
```

Add this block right before the `// Configuraciones base` section (so it runs after the admin user exists):

```javascript
  // Sucursal por defecto — migra instalaciones existentes a una sola sucursal
  const [principal] = await Sucursal.findOrCreate({
    where: { nombre: 'Sucursal Principal' },
    defaults: { activo: 1 },
  });
  const usuariosExistentes = await Usuario.findAll();
  for (const u of usuariosExistentes) {
    const yaAsignado = await u.hasSucursal(principal);
    if (!yaAsignado) await u.addSucursal(principal);
  }
```

- [ ] **Step 7: Run the seed against the local dev DB**

Run: `npm run seed` (from `backend/`)
Expected: ends with `Seed completado` and exit code 0, no errors.

- [ ] **Step 8: Verify the data landed**

Run: `mysql -u root -p bd_restaurante -e "SELECT * FROM sucursales; SELECT * FROM usuarios_sucursales; SELECT modulo,accion FROM permisos WHERE modulo='sucursales';"`
Expected: one `sucursales` row (`Sucursal Principal`), one `usuarios_sucursales` row per existing user (at least the admin), and 4 rows for the `sucursales` permission module.

- [ ] **Step 9: Commit**

```bash
git add backend/src/models/Sucursal.js backend/src/models/Usuario.js backend/src/models/index.js backend/database/seeds/seed.js
git commit -m "feat(db): add Sucursal model, association and default-branch seed"
```

---

### Task 3: Backend — login en dos pasos y sesión con sucursal activa

**Files:**
- Modify: `backend/src/modules/auth/auth.service.js`
- Modify: `backend/src/modules/auth/auth.controller.js`
- Modify: `backend/src/modules/auth/auth.routes.js`
- Modify: `backend/src/middlewares/auth.js`
- Test: `backend/tests/auth-sucursales.test.js`

**Interfaces:**
- Consumes: `Sucursal`, `Usuario` (with `sucursales` association and `acceso_todas_sucursales`) from Task 2.
- Produces: `POST /api/v1/auth/login` — unchanged shape (`{ token, refresh_token, usuario }`) when the user has exactly one sucursal and no `acceso_todas_sucursales`; otherwise returns `{ requiere_sucursal: true, pre_token, sucursales: [{id, nombre}, ...] }` (with `{id: null, nombre: 'Todas las sucursales'}` first when `acceso_todas_sucursales` is set). New `POST /api/v1/auth/login/sucursal` — body `{ pre_token, sucursal_id }` (`sucursal_id` may be `null`), returns `{ token, refresh_token, usuario }`. `usuario.sucursal_activa = { id, nombre }` is now present in every successful login/`login/sucursal` response. `req.usuario.sucursal_id` (number or `null`) and `req.usuario.acceso_todas` (boolean) are available to every route behind the `auth` middleware — this is what Fase 2 modules will read to scope their queries.

- [ ] **Step 1: Write the failing tests**

```javascript
// backend/tests/auth-sucursales.test.js
const request = require('supertest');
const bcrypt = require('bcryptjs');
const app = require('../src/app');
const { Usuario, Rol, Sucursal } = require('../src/models');

let sucursalB;
let usuarioMultiId;
let usuarioTodasId;

beforeAll(async () => {
  const rol = await Rol.findOne({ where: { nombre: 'Mozo' } });
  const principal = await Sucursal.findOne({ where: { nombre: 'Sucursal Principal' } });
  sucursalB = await Sucursal.create({ nombre: 'Sucursal Test B' });

  const hash = await bcrypt.hash('clave123', 10);

  const multi = await Usuario.create({
    rol_id: rol.id, nombre: 'Multi Sucursal', email: 'multi-sucursal-test@restaurante.com', contrasena: hash,
  });
  await multi.addSucursales([principal, sucursalB]);
  usuarioMultiId = multi.id;

  const todas = await Usuario.create({
    rol_id: rol.id, nombre: 'Acceso Todas', email: 'acceso-todas-test@restaurante.com', contrasena: hash,
    acceso_todas_sucursales: 1,
  });
  usuarioTodasId = todas.id;
});

afterAll(async () => {
  await Usuario.destroy({ where: { id: [usuarioMultiId, usuarioTodasId] } });
  await Sucursal.destroy({ where: { id: sucursalB.id } });
});

describe('Login con múltiples sucursales', () => {
  it('usuario con varias sucursales recibe requiere_sucursal y pre_token', async () => {
    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'multi-sucursal-test@restaurante.com', contrasena: 'clave123' });

    expect(res.status).toBe(200);
    expect(res.body.datos.requiere_sucursal).toBe(true);
    expect(res.body.datos.pre_token).toBeDefined();
    expect(res.body.datos.sucursales).toHaveLength(2);
    expect(res.body.datos.token).toBeUndefined();
  });

  it('completa el login eligiendo una sucursal válida', async () => {
    const login = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'multi-sucursal-test@restaurante.com', contrasena: 'clave123' });
    const { pre_token, sucursales } = login.body.datos;

    const res = await request(app)
      .post('/api/v1/auth/login/sucursal')
      .send({ pre_token, sucursal_id: sucursales[0].id });

    expect(res.status).toBe(200);
    expect(res.body.datos.token).toBeDefined();
    expect(res.body.datos.usuario.sucursal_activa.id).toBe(sucursales[0].id);
  });

  it('rechaza una sucursal que no le pertenece al usuario', async () => {
    const login = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'multi-sucursal-test@restaurante.com', contrasena: 'clave123' });

    const otraSucursal = await Sucursal.create({ nombre: 'Sucursal Ajena Test' });
    const res = await request(app)
      .post('/api/v1/auth/login/sucursal')
      .send({ pre_token: login.body.datos.pre_token, sucursal_id: otraSucursal.id });

    expect(res.status).toBe(403);
    await Sucursal.destroy({ where: { id: otraSucursal.id } });
  });

  it('usuario con acceso_todas_sucursales puede elegir "Todas las sucursales"', async () => {
    const login = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'acceso-todas-test@restaurante.com', contrasena: 'clave123' });

    expect(login.body.datos.sucursales[0]).toEqual({ id: null, nombre: 'Todas las sucursales' });

    const res = await request(app)
      .post('/api/v1/auth/login/sucursal')
      .send({ pre_token: login.body.datos.pre_token, sucursal_id: null });

    expect(res.status).toBe(200);
    expect(res.body.datos.usuario.sucursal_activa).toEqual({ id: null, nombre: 'Todas las sucursales' });

    const yo = await request(app)
      .get('/api/v1/auth/yo')
      .set('Authorization', `Bearer ${res.body.datos.token}`);
    expect(yo.body.datos.sucursal_id).toBeNull();
    expect(yo.body.datos.acceso_todas).toBe(true);
  });
});

describe('Login con una sola sucursal (compatibilidad)', () => {
  it('admin sigue logueando directo, sin paso de sucursal', async () => {
    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'admin@restaurante.com', contrasena: process.env.ADMIN_PASSWORD || 'admin123' });

    expect(res.status).toBe(200);
    expect(res.body.datos.token).toBeDefined();
    expect(res.body.datos.usuario.sucursal_activa.nombre).toBe('Sucursal Principal');

    const yo = await request(app)
      .get('/api/v1/auth/yo')
      .set('Authorization', `Bearer ${res.body.datos.token}`);
    expect(yo.body.datos.acceso_todas).toBe(false);
    expect(typeof yo.body.datos.sucursal_id).toBe('number');
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npm test -- auth-sucursales` (from `backend/`)
Expected: FAIL — `requiere_sucursal` is `undefined` (login still returns the old single-step shape) and `POST /auth/login/sucursal` 404s.

- [ ] **Step 3: Rewrite `auth.service.js`**

```javascript
// backend/src/modules/auth/auth.service.js
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { Usuario, Rol, Permiso, Sucursal } = require('../../models');

function emitirSesion(usuario, sucursalId, sucursalNombre) {
  const payload = { id: usuario.id, sucursal_id: sucursalId };
  const token = jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN });
  const refresh_token = jwt.sign(payload, process.env.JWT_REFRESH_SECRET, { expiresIn: process.env.JWT_REFRESH_EXPIRES_IN });

  return {
    token,
    refresh_token,
    usuario: {
      id: usuario.id,
      nombre: usuario.nombre,
      email: usuario.email,
      rol: usuario.rol.nombre,
      permisos: usuario.rol.permisos.map(p => `${p.modulo}.${p.accion}`),
      sucursal_activa: { id: sucursalId, nombre: sucursalNombre },
    },
  };
}

async function buscarUsuarioCompleto(where) {
  return Usuario.findOne({
    where,
    include: [
      { model: Rol, as: 'rol', include: [{ model: Permiso, as: 'permisos' }] },
      { model: Sucursal, as: 'sucursales', where: { activo: 1 }, required: false },
    ],
  });
}

async function login(email, contrasena) {
  const usuario = await buscarUsuarioCompleto({ email, activo: 1 });
  if (!usuario) throw Object.assign(new Error('Credenciales inválidas'), { status: 401 });

  const valida = await bcrypt.compare(contrasena, usuario.contrasena);
  if (!valida) throw Object.assign(new Error('Credenciales inválidas'), { status: 401 });

  let sucursalesDisponibles;
  if (usuario.acceso_todas_sucursales) {
    const todas = await Sucursal.findAll({ where: { activo: 1 }, order: [['nombre', 'ASC']] });
    sucursalesDisponibles = [
      { id: null, nombre: 'Todas las sucursales' },
      ...todas.map(s => ({ id: s.id, nombre: s.nombre })),
    ];
  } else {
    sucursalesDisponibles = (usuario.sucursales || []).map(s => ({ id: s.id, nombre: s.nombre }));
  }

  if (sucursalesDisponibles.length === 0) {
    throw Object.assign(new Error('El usuario no tiene sucursales asignadas'), { status: 403 });
  }

  if (sucursalesDisponibles.length === 1) {
    return emitirSesion(usuario, sucursalesDisponibles[0].id, sucursalesDisponibles[0].nombre);
  }

  const pre_token = jwt.sign({ id: usuario.id, tipo: 'pre_login' }, process.env.JWT_SECRET, { expiresIn: '5m' });
  return { requiere_sucursal: true, pre_token, sucursales: sucursalesDisponibles };
}

async function loginConSucursal(pre_token, sucursal_id) {
  let payload;
  try {
    payload = jwt.verify(pre_token, process.env.JWT_SECRET);
  } catch {
    throw Object.assign(new Error('Sesión de login expirada, vuelve a iniciar sesión'), { status: 401 });
  }
  if (payload.tipo !== 'pre_login') {
    throw Object.assign(new Error('Token inválido'), { status: 401 });
  }

  const usuario = await buscarUsuarioCompleto({ id: payload.id, activo: 1 });
  if (!usuario) throw Object.assign(new Error('Usuario no encontrado'), { status: 401 });

  const idNormalizado = (sucursal_id === undefined || sucursal_id === '') ? null : sucursal_id;
  let sucursalNombre;

  if (idNormalizado === null) {
    if (!usuario.acceso_todas_sucursales) {
      throw Object.assign(new Error('No tienes acceso a todas las sucursales'), { status: 403 });
    }
    sucursalNombre = 'Todas las sucursales';
  } else if (usuario.acceso_todas_sucursales) {
    const sucursal = await Sucursal.findOne({ where: { id: idNormalizado, activo: 1 } });
    if (!sucursal) throw Object.assign(new Error('No tienes acceso a esa sucursal'), { status: 403 });
    sucursalNombre = sucursal.nombre;
  } else {
    const asignada = (usuario.sucursales || []).find(s => s.id === Number(idNormalizado));
    if (!asignada) throw Object.assign(new Error('No tienes acceso a esa sucursal'), { status: 403 });
    sucursalNombre = asignada.nombre;
  }

  return emitirSesion(usuario, idNormalizado, sucursalNombre);
}

async function refresh(refresh_token) {
  let payload;
  try {
    payload = jwt.verify(refresh_token, process.env.JWT_REFRESH_SECRET);
  } catch {
    throw Object.assign(new Error('Refresh token inválido'), { status: 401 });
  }
  const usuario = await Usuario.findOne({ where: { id: payload.id, activo: 1 } });
  if (!usuario) throw Object.assign(new Error('Usuario inactivo o no existe'), { status: 401 });
  const token = jwt.sign(
    { id: payload.id, sucursal_id: payload.sucursal_id ?? null },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN }
  );
  return { token };
}

module.exports = { login, loginConSucursal, refresh };
```

- [ ] **Step 4: Update `auth.controller.js`**

```javascript
// backend/src/modules/auth/auth.controller.js
const authService = require('./auth.service');

async function login(req, res, next) {
  try {
    const { email, contrasena } = req.body;
    if (!email || !contrasena) {
      return res.status(400).json({ ok: false, mensaje: 'Email y contraseña requeridos' });
    }
    const datos = await authService.login(email, contrasena);
    res.json({ ok: true, datos });
  } catch (err) {
    next(err);
  }
}

async function loginSucursal(req, res, next) {
  try {
    const { pre_token, sucursal_id } = req.body;
    if (!pre_token) {
      return res.status(400).json({ ok: false, mensaje: 'pre_token requerido' });
    }
    const datos = await authService.loginConSucursal(pre_token, sucursal_id);
    res.json({ ok: true, datos });
  } catch (err) {
    next(err);
  }
}

async function refresh(req, res, next) {
  try {
    const { refresh_token } = req.body;
    if (!refresh_token) return res.status(400).json({ ok: false, mensaje: 'refresh_token requerido' });
    const datos = await authService.refresh(refresh_token);
    res.json({ ok: true, datos });
  } catch (err) {
    next(err);
  }
}

function yo(req, res) {
  res.json({ ok: true, datos: req.usuario });
}

module.exports = { login, loginSucursal, refresh, yo };
```

- [ ] **Step 5: Add the route in `auth.routes.js`**

```javascript
// backend/src/modules/auth/auth.routes.js
const { Router } = require('express');
const { login, loginSucursal, refresh, yo } = require('./auth.controller');
const auth = require('../../middlewares/auth');

const router = Router();

router.post('/login', login);
router.post('/login/sucursal', loginSucursal);
router.post('/refresh', refresh);
router.get('/yo', auth, yo);

module.exports = router;
```

- [ ] **Step 6: Expose `sucursal_id`/`acceso_todas` in `middlewares/auth.js`**

```javascript
// backend/src/middlewares/auth.js
const jwt = require('jsonwebtoken');
const { Usuario, Rol, Permiso } = require('../models');

async function auth(req, res, next) {
  const header = req.headers['authorization'];
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ ok: false, mensaje: 'Token requerido' });
  }

  const token = header.split(' ')[1];

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    const usuario = await Usuario.findOne({
      where: { id: payload.id, activo: 1 },
      include: [{
        model: Rol,
        as: 'rol',
        include: [{ model: Permiso, as: 'permisos' }],
      }],
    });

    if (!usuario) {
      return res.status(401).json({ ok: false, mensaje: 'Usuario no encontrado' });
    }

    const sucursalId = payload.sucursal_id ?? null;

    req.usuario = {
      id: usuario.id,
      nombre: usuario.nombre,
      email: usuario.email,
      rol_id: usuario.rol_id,
      permisos: usuario.rol.permisos.map(p => `${p.modulo}.${p.accion}`),
      sucursal_id: sucursalId,
      acceso_todas: sucursalId === null,
    };

    next();
  } catch {
    return res.status(401).json({ ok: false, mensaje: 'Token inválido o expirado' });
  }
}

module.exports = auth;
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `npm test -- auth-sucursales auth.test.js` (from `backend/`)
Expected: PASS — all new tests green, plus the pre-existing `backend/tests/auth.test.js` suite still green (admin has exactly one sucursal after Task 2's seed, so the single-step path is unchanged for it).

- [ ] **Step 8: Run the full test suite to check for regressions**

Run: `npm test` (from `backend/`)
Expected: all suites pass — `req.usuario` gained two fields but no existing route reads/breaks on them.

- [ ] **Step 9: Commit**

```bash
git add backend/src/modules/auth backend/src/middlewares/auth.js backend/tests/auth-sucursales.test.js
git commit -m "feat(auth): two-step login and sucursal-aware sessions"
```

---

### Task 4: Backend — módulo CRUD de sucursales

**Files:**
- Create: `backend/src/modules/sucursales/sucursales.service.js`
- Create: `backend/src/modules/sucursales/sucursales.controller.js`
- Create: `backend/src/modules/sucursales/sucursales.routes.js`
- Modify: `backend/src/app.js`
- Test: `backend/tests/sucursales.test.js`

**Interfaces:**
- Consumes: `Sucursal` model (Task 2), `auth`/`verificarPermiso` middlewares (existing).
- Produces: `GET/POST /api/v1/sucursales`, `PUT/DELETE /api/v1/sucursales/:id`, gated by `sucursales.ver|crear|editar|eliminar` permissions. Task 10 (frontend `api/sucursales.js`) consumes this API.

- [ ] **Step 1: Write the failing tests**

```javascript
// backend/tests/sucursales.test.js
const request = require('supertest');
const app = require('../src/app');

let adminToken;

beforeAll(async () => {
  const res = await request(app)
    .post('/api/v1/auth/login')
    .send({ email: 'admin@restaurante.com', contrasena: process.env.ADMIN_PASSWORD || 'admin123' });
  adminToken = res.body.datos.token;
});

describe('Sucursales API', () => {
  it('rechaza sin token', async () => {
    const res = await request(app).get('/api/v1/sucursales');
    expect(res.status).toBe(401);
  });

  it('lista sucursales para admin (incluye la Sucursal Principal del seed)', async () => {
    const res = await request(app)
      .get('/api/v1/sucursales')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(200);
    expect(res.body.datos.some(s => s.nombre === 'Sucursal Principal')).toBe(true);
  });

  it('crea, edita y elimina una sucursal', async () => {
    const crear = await request(app)
      .post('/api/v1/sucursales')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ nombre: 'Sucursal CRUD Test', direccion: 'Av. Siempre Viva 123', telefono: '70000000' });
    expect(crear.status).toBe(201);
    expect(crear.body.datos.nombre).toBe('Sucursal CRUD Test');
    const id = crear.body.datos.id;

    const editar = await request(app)
      .put(`/api/v1/sucursales/${id}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ nombre: 'Sucursal CRUD Test Editada' });
    expect(editar.status).toBe(200);
    expect(editar.body.datos.nombre).toBe('Sucursal CRUD Test Editada');

    const eliminar = await request(app)
      .delete(`/api/v1/sucursales/${id}`)
      .set('Authorization', `Bearer ${adminToken}`);
    expect(eliminar.status).toBe(200);
  });

  it('rechaza crear sin nombre', async () => {
    const res = await request(app)
      .post('/api/v1/sucursales')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ direccion: 'Sin nombre' });
    expect(res.status).toBe(400);
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npm test -- sucursales.test` (from `backend/`)
Expected: FAIL — `GET /api/v1/sucursales` 404s (route doesn't exist yet).

- [ ] **Step 3: Write `sucursales.service.js`**

```javascript
// backend/src/modules/sucursales/sucursales.service.js
const { Sucursal } = require('../../models');

async function listar() {
  return Sucursal.findAll({ order: [['nombre', 'ASC']] });
}

async function crear({ nombre, direccion, telefono, activo = 1 }) {
  if (!nombre || !nombre.trim()) {
    throw Object.assign(new Error('El nombre es requerido'), { status: 400 });
  }
  return Sucursal.create({ nombre: nombre.trim(), direccion, telefono, activo });
}

async function actualizar(id, { nombre, direccion, telefono, activo }) {
  const sucursal = await Sucursal.findByPk(id);
  if (!sucursal) throw Object.assign(new Error('Sucursal no encontrada'), { status: 404 });
  const datos = {};
  if (nombre !== undefined) datos.nombre = nombre;
  if (direccion !== undefined) datos.direccion = direccion;
  if (telefono !== undefined) datos.telefono = telefono;
  if (activo !== undefined) datos.activo = activo;
  await sucursal.update(datos);
  return sucursal;
}

async function eliminar(id) {
  const sucursal = await Sucursal.findByPk(id);
  if (!sucursal) throw Object.assign(new Error('Sucursal no encontrada'), { status: 404 });
  const usuarios = await sucursal.countUsuarios();
  if (usuarios > 0) throw Object.assign(new Error('La sucursal tiene usuarios asignados'), { status: 409 });
  await sucursal.destroy();
}

module.exports = { listar, crear, actualizar, eliminar };
```

- [ ] **Step 4: Write `sucursales.controller.js`**

```javascript
// backend/src/modules/sucursales/sucursales.controller.js
const svc = require('./sucursales.service');

async function listar(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listar() }); }
  catch (err) { next(err); }
}

async function crear(req, res, next) {
  try { res.status(201).json({ ok: true, datos: await svc.crear(req.body) }); }
  catch (err) { next(err); }
}

async function actualizar(req, res, next) {
  try { res.json({ ok: true, datos: await svc.actualizar(req.params.id, req.body) }); }
  catch (err) { next(err); }
}

async function eliminar(req, res, next) {
  try { await svc.eliminar(req.params.id); res.json({ ok: true, datos: null }); }
  catch (err) { next(err); }
}

module.exports = { listar, crear, actualizar, eliminar };
```

- [ ] **Step 5: Write `sucursales.routes.js`**

```javascript
// backend/src/modules/sucursales/sucursales.routes.js
const { Router } = require('express');
const ctrl = require('./sucursales.controller');
const auth = require('../../middlewares/auth');
const { verificarPermiso } = require('../../middlewares/permisos');

const router = Router();
router.use(auth);

router.get('/', verificarPermiso('sucursales', 'ver'), ctrl.listar);
router.post('/', verificarPermiso('sucursales', 'crear'), ctrl.crear);
router.put('/:id', verificarPermiso('sucursales', 'editar'), ctrl.actualizar);
router.delete('/:id', verificarPermiso('sucursales', 'eliminar'), ctrl.eliminar);

module.exports = router;
```

- [ ] **Step 6: Mount the route in `app.js`**

Add the require next to `const rolesRoutes = require('./modules/roles/roles.routes');`:

```javascript
const sucursalesRoutes = require('./modules/sucursales/sucursales.routes');
```

Add the mount next to `app.use('/api/v1/roles', rolesRoutes);`:

```javascript
app.use('/api/v1/sucursales', sucursalesRoutes);
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `npm test -- sucursales.test` (from `backend/`)
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add backend/src/modules/sucursales backend/src/app.js backend/tests/sucursales.test.js
git commit -m "feat(sucursales): add branch CRUD module"
```

---

### Task 5: Backend — asignar sucursales a un usuario

**Files:**
- Modify: `backend/src/modules/usuarios/usuarios.service.js`
- Modify: `backend/src/modules/usuarios/usuarios.controller.js`
- Modify: `backend/src/modules/usuarios/usuarios.routes.js`
- Test: `backend/tests/usuarios.test.js`

**Interfaces:**
- Consumes: `Sucursal` model, `sucursal.setSucursales()` association method (Task 2).
- Produces: `PUT /api/v1/usuarios/:id/sucursales` with body `{ sucursal_ids: number[], acceso_todas_sucursales: boolean }`, gated by `usuarios.editar`. `usuarios.listar()`/`.obtener()` responses now include a `sucursales: [{id, nombre}]` array and `acceso_todas_sucursales`. Task 6 (frontend) calls this endpoint.

- [ ] **Step 1: Write the failing tests**

Append to `backend/tests/usuarios.test.js`:

```javascript
const bcrypt = require('bcryptjs');
const { Usuario, Rol, Sucursal } = require('../src/models');

describe('PUT /api/v1/usuarios/:id/sucursales', () => {
  let adminToken;
  let usuarioId;
  let sucursalId;

  beforeAll(async () => {
    const login = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'admin@restaurante.com', contrasena: process.env.ADMIN_PASSWORD || 'admin123' });
    adminToken = login.body.datos.token;

    const rol = await Rol.findOne({ where: { nombre: 'Mozo' } });
    const hash = await bcrypt.hash('clave123', 10);
    const usuario = await Usuario.create({
      rol_id: rol.id, nombre: 'Asignar Sucursal Test', email: 'asignar-sucursal-test@restaurante.com', contrasena: hash,
    });
    usuarioId = usuario.id;

    const sucursal = await Sucursal.create({ nombre: 'Sucursal Asignacion Test' });
    sucursalId = sucursal.id;
  });

  afterAll(async () => {
    await Usuario.destroy({ where: { id: usuarioId } });
    await Sucursal.destroy({ where: { id: sucursalId } });
  });

  it('asigna sucursales y refleja el cambio al obtener el usuario', async () => {
    const res = await request(app)
      .put(`/api/v1/usuarios/${usuarioId}/sucursales`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ sucursal_ids: [sucursalId], acceso_todas_sucursales: false });

    expect(res.status).toBe(200);
    expect(res.body.datos.sucursales).toHaveLength(1);
    expect(res.body.datos.sucursales[0].id).toBe(sucursalId);
    expect(res.body.datos.acceso_todas_sucursales).toBe(0);
  });

  it('activa acceso_todas_sucursales y limpia las asignaciones puntuales', async () => {
    const res = await request(app)
      .put(`/api/v1/usuarios/${usuarioId}/sucursales`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ sucursal_ids: [], acceso_todas_sucursales: true });

    expect(res.status).toBe(200);
    expect(res.body.datos.sucursales).toHaveLength(0);
    expect(res.body.datos.acceso_todas_sucursales).toBe(1);
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npm test -- usuarios.test` (from `backend/`)
Expected: FAIL — `PUT /api/v1/usuarios/:id/sucursales` 404s.

- [ ] **Step 3: Update `usuarios.service.js`**

```javascript
// backend/src/modules/usuarios/usuarios.service.js
const bcrypt = require('bcryptjs');
const { Usuario, Rol, Sucursal } = require('../../models');

const ATTRS_PUBLICOS = { exclude: ['contrasena', 'token_recordar'] };
const INCLUDE_RELS = [
  { model: Rol, as: 'rol', attributes: ['id', 'nombre'] },
  { model: Sucursal, as: 'sucursales', attributes: ['id', 'nombre'], through: { attributes: [] } },
];

async function listar() {
  return Usuario.findAll({ include: INCLUDE_RELS, attributes: ATTRS_PUBLICOS, order: [['creado_en', 'DESC']] });
}

async function obtener(id) {
  const u = await Usuario.findByPk(id, { include: INCLUDE_RELS, attributes: ATTRS_PUBLICOS });
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

async function actualizarSucursales(id, sucursalIds = [], accesoTodas = false) {
  const u = await Usuario.findByPk(id);
  if (!u) throw Object.assign(new Error('Usuario no encontrado'), { status: 404 });
  await u.update({ acceso_todas_sucursales: accesoTodas ? 1 : 0 });
  const sucursales = sucursalIds.length ? await Sucursal.findAll({ where: { id: sucursalIds } }) : [];
  await u.setSucursales(sucursales);
  return obtener(id);
}

module.exports = { listar, obtener, crear, actualizar, eliminar, actualizarSucursales };
```

- [ ] **Step 4: Update `usuarios.controller.js`**

Add this function and export it:

```javascript
async function actualizarSucursales(req, res, next) {
  try {
    const { sucursal_ids = [], acceso_todas_sucursales = false } = req.body;
    const datos = await svc.actualizarSucursales(req.params.id, sucursal_ids, acceso_todas_sucursales);
    res.json({ ok: true, datos });
  } catch (err) { next(err); }
}

module.exports = { listar, obtener, crear, actualizar, eliminar, actualizarSucursales };
```

- [ ] **Step 5: Add the route in `usuarios.routes.js`**

Add after the existing `PUT /:id` route:

```javascript
router.put('/:id/sucursales', verificarPermiso('usuarios', 'editar'), ctrl.actualizarSucursales);
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `npm test -- usuarios.test` (from `backend/`)
Expected: PASS.

- [ ] **Step 7: Run the full suite to check for regressions**

Run: `npm test` (from `backend/`)
Expected: all suites pass (the new `sucursales` include on `listar`/`obtener` only adds a field, doesn't remove any existing one).

- [ ] **Step 8: Commit**

```bash
git add backend/src/modules/usuarios backend/tests/usuarios.test.js
git commit -m "feat(usuarios): assign sucursales and acceso_todas_sucursales to a user"
```

---

### Task 6: Frontend — cliente API de sucursales y extensión del de usuarios

**Files:**
- Create: `frontend/src/api/sucursales.js`
- Modify: `frontend/src/api/usuarios.js`

**Interfaces:**
- Consumes: `frontend/src/api/cliente.js` (shared `axios` instance), endpoints from Task 4/5.
- Produces: `getSucursales()`, `crearSucursal(datos)`, `actualizarSucursal(id, datos)`, `eliminarSucursal(id)`; `actualizarSucursalesUsuario(id, { sucursal_ids, acceso_todas_sucursales })`. Tasks 7-10 (LoginPage, SucursalesPage, UsuariosPage) import these.

- [ ] **Step 1: Create `frontend/src/api/sucursales.js`**

```javascript
import api from './cliente';

export const getSucursales       = ()          => api.get('/sucursales').then(r => r.data.datos);
export const crearSucursal       = (datos)     => api.post('/sucursales', datos).then(r => r.data.datos);
export const actualizarSucursal  = (id, datos) => api.put(`/sucursales/${id}`, datos).then(r => r.data.datos);
export const eliminarSucursal    = (id)        => api.delete(`/sucursales/${id}`).then(r => r.data.datos);
```

- [ ] **Step 2: Extend `frontend/src/api/usuarios.js`**

```javascript
import api from './cliente';

export const getUsuarios  = ()           => api.get('/usuarios').then(r => r.data.datos);
export const crearUsuario = (datos)      => api.post('/usuarios', datos).then(r => r.data.datos);
export const actualizarUsuario = (id, datos) => api.put(`/usuarios/${id}`, datos).then(r => r.data.datos);
export const eliminarUsuario   = (id)    => api.delete(`/usuarios/${id}`).then(r => r.data.datos);
export const actualizarSucursalesUsuario = (id, datos) => api.put(`/usuarios/${id}/sucursales`, datos).then(r => r.data.datos);
```

- [ ] **Step 3: Verify with the backend running**

Run: `npm run dev` in `backend/` (in one terminal) and, in another, `node -e "fetch('http://localhost:3001/api/v1/sucursales').then(r=>r.json()).then(console.log)"` from `frontend/`.
Expected: `{ ok: false, mensaje: 'Token requerido' }` — confirms the route resolves and is guarded (a real check happens visually in Task 9).

- [ ] **Step 4: Commit**

```bash
git add frontend/src/api/sucursales.js frontend/src/api/usuarios.js
git commit -m "feat(frontend): add sucursales API client"
```

---

### Task 7: Frontend — selector de sucursal en el login

**Files:**
- Modify: `frontend/src/pages/auth/LoginPage.jsx`

**Interfaces:**
- Consumes: `POST /auth/login` / `POST /auth/login/sucursal` responses (Task 3), `useAuthStore().setAuth` (existing, unchanged — it already stores whatever `usuario` object it's given, so `usuario.sucursal_activa` flows through with no store changes needed).
- Produces: a working two-step login UI. Task 8 (Topbar) reads `usuario.sucursal_activa` that this flow saves into the store.

- [ ] **Step 1: Add the two-step state to `LoginPage`**

Replace the top of the component (from `const [email, setEmail]` through `const navigate  = useNavigate();`) with:

```javascript
export default function LoginPage() {
  const [email, setEmail]                       = useState('');
  const [contrasena, setContrasena]             = useState('');
  const [mostrarContrasena, setMostrarContrasena] = useState(false);
  const [error, setError]                       = useState('');
  const [cargando, setCargando]                 = useState(false);
  const [paso, setPaso]                         = useState('credenciales'); // 'credenciales' | 'sucursal'
  const [preToken, setPreToken]                 = useState(null);
  const [sucursales, setSucursales]             = useState([]);
  const setAuth   = useAuthStore((s) => s.setAuth);
  const navigate  = useNavigate();
```

- [ ] **Step 2: Update `handleSubmit` and add `handleElegirSucursal`**

Replace the existing `handleSubmit` function with:

```javascript
  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    setCargando(true);
    try {
      const { data } = await api.post('/auth/login', { email, contrasena });
      if (data.datos.requiere_sucursal) {
        setPreToken(data.datos.pre_token);
        setSucursales(data.datos.sucursales);
        setPaso('sucursal');
      } else {
        setAuth(data.datos);
        navigate('/');
      }
    } catch (err) {
      setError(err.response?.data?.mensaje ?? 'Error al iniciar sesión');
    } finally {
      setCargando(false);
    }
  }

  async function handleElegirSucursal(sucursalId) {
    setError('');
    setCargando(true);
    try {
      const { data } = await api.post('/auth/login/sucursal', { pre_token: preToken, sucursal_id: sucursalId });
      setAuth(data.datos);
      navigate('/');
    } catch (err) {
      setError(err.response?.data?.mensaje ?? 'Error al seleccionar la sucursal');
      setPaso('credenciales');
    } finally {
      setCargando(false);
    }
  }

  function volverACredenciales() {
    setPaso('credenciales');
    setPreToken(null);
    setSucursales([]);
    setError('');
  }
```

- [ ] **Step 3: Render the sucursal-selection step**

Inside the login card, replace the `<form onSubmit={handleSubmit} className="space-y-5">...</form>` block (keep everything else — medallion, business name, footer — untouched) with a conditional:

```jsx
          {paso === 'credenciales' ? (
            <form onSubmit={handleSubmit} className="space-y-5">
              {/* ... keep the existing email input, password input and error block exactly as they are ... */}

              <button
                type="submit"
                disabled={cargando}
                className="w-full mt-1 bg-amber-600 hover:bg-amber-700 active:bg-amber-800 disabled:opacity-60 disabled:cursor-not-allowed text-white rounded-xl py-3 text-sm font-semibold tracking-wide transition-all duration-200 shadow-sm hover:shadow-lg hover:shadow-amber-600/20"
              >
                {cargando ? 'Iniciando sesión...' : 'Iniciar sesión'}
              </button>
            </form>
          ) : (
            <div className="space-y-3">
              <p className="text-xs text-center text-[#9A8878] dark:text-[#5A4A38] -mt-1 mb-2">
                Elige con qué sucursal quieres trabajar
              </p>

              {sucursales.map((s) => (
                <button
                  key={s.id ?? 'todas'}
                  type="button"
                  disabled={cargando}
                  onClick={() => handleElegirSucursal(s.id)}
                  className="w-full text-left bg-[#FDFAF7] dark:bg-[#160F08] border border-[#E2D9CE] dark:border-[#3A2412] rounded-xl px-4 py-3 text-sm text-[#1C1208] dark:text-[#F0E8D8] hover:border-amber-400 dark:hover:border-amber-600 hover:bg-amber-50/40 dark:hover:bg-amber-900/10 transition disabled:opacity-60"
                >
                  {s.nombre}
                </button>
              ))}

              {error && (
                <div className="rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800/40 px-4 py-3">
                  <p className="text-sm text-red-600 dark:text-red-400">{error}</p>
                </div>
              )}

              <button
                type="button"
                onClick={volverACredenciales}
                className="w-full mt-1 text-sm text-[#9A8878] dark:text-[#5A4A38] hover:text-amber-600 dark:hover:text-amber-500 transition-colors"
              >
                ← Volver
              </button>
            </div>
          )}
```

- [ ] **Step 4: Manually verify against the running app**

Run: `npm run dev` in `backend/` and `npm run dev` in `frontend/`.
In the browser:
1. Log in as `admin@restaurante.com` — should go straight to `/` (single sucursal, no selector shown). Confirms backward compatibility.
2. Using the test users created in Task 3's test suite is not viable (they get cleaned up by `afterAll`) — instead, temporarily assign a second sucursal to the admin user via `mysql`: `INSERT INTO usuarios_sucursales (usuario_id, sucursal_id) SELECT u.id, s.id FROM usuarios u, sucursales s WHERE u.email='admin@restaurante.com' AND s.nombre != 'Sucursal Principal' LIMIT 1;` (requires at least one extra sucursal to exist — create one via the API/Postman first, or wait until Task 9's SucursalesPage is done and create it there, then come back to this check). Log in again — the sucursal-selection screen should appear, clicking a sucursal should land on `/`.
3. Revert: `DELETE FROM usuarios_sucursales WHERE usuario_id = (SELECT id FROM usuarios WHERE email='admin@restaurante.com') AND sucursal_id != (SELECT id FROM sucursales WHERE nombre='Sucursal Principal');`

Expected: both paths work with no console errors.

- [ ] **Step 5: Commit**

```bash
git add frontend/src/pages/auth/LoginPage.jsx
git commit -m "feat(frontend): two-step sucursal selection on login"
```

---

### Task 8: Frontend — mostrar la sucursal activa en el Topbar

**Files:**
- Modify: `frontend/src/components/layout/Topbar.jsx`

**Interfaces:**
- Consumes: `usuario.sucursal_activa` from `useAuth()` (populated by Task 7's login flow).
- Produces: read-only branch indicator visible on every authenticated page.

- [ ] **Step 1: Add the sucursal label next to the user's name**

In `Topbar.jsx`, replace the `<Link to="/perfil" ...>` block with:

```jsx
        <Link
          to="/perfil"
          className="text-right px-1 group cursor-pointer"
          title="Ver mi perfil"
        >
          <p className="text-sm font-semibold text-gray-800 dark:text-gray-100 group-hover:text-amber-600 dark:group-hover:text-amber-400 leading-tight transition-colors">{usuario?.nombre}</p>
          <p className="text-xs text-gray-400 dark:text-gray-500 leading-tight">
            {usuario?.rol?.nombre}
            {usuario?.sucursal_activa && <> · {usuario.sucursal_activa.nombre}</>}
          </p>
        </Link>
```

- [ ] **Step 2: Manually verify**

Run: `npm run dev` in `frontend/` (backend already running from Task 7), log in as admin.
Expected: header under the user's name shows `Administrador · Sucursal Principal` (or whatever the role/sucursal names are).

- [ ] **Step 3: Commit**

```bash
git add frontend/src/components/layout/Topbar.jsx
git commit -m "feat(frontend): show active sucursal in the topbar"
```

---

### Task 9: Frontend — página de gestión de sucursales (CRUD)

**Files:**
- Create: `frontend/src/pages/sucursales/SucursalesPage.jsx`
- Modify: `frontend/src/router/index.jsx`
- Modify: `frontend/src/components/layout/Sidebar.jsx`

**Interfaces:**
- Consumes: `getSucursales`, `crearSucursal`, `actualizarSucursal`, `eliminarSucursal` (Task 6), `usePermisos()` (existing), `Modal` (existing, `frontend/src/components/ui/Modal.jsx`).
- Produces: `/sucursales` route, reachable from the sidebar when the user has `sucursales.ver`.

- [ ] **Step 1: Write `SucursalesPage.jsx`**

```jsx
// frontend/src/pages/sucursales/SucursalesPage.jsx
import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Building2, Plus, Pencil, Trash2, AlertCircle, RefreshCw } from 'lucide-react';
import { getSucursales, crearSucursal, actualizarSucursal, eliminarSucursal } from '../../api/sucursales';
import { usePermisos } from '../../hooks/usePermisos';
import Modal from '../../components/ui/Modal';

export default function SucursalesPage() {
  const { tienePermiso } = usePermisos();
  const qc = useQueryClient();

  const puedeVer      = tienePermiso('sucursales', 'ver');
  const puedeCrear    = tienePermiso('sucursales', 'crear');
  const puedeEditar   = tienePermiso('sucursales', 'editar');
  const puedeEliminar = tienePermiso('sucursales', 'eliminar');

  const [modalForm, setModalForm] = useState(null); // null | 'nuevo' | sucursal-object
  const [confirmar, setConfirmar] = useState(null); // null | sucursal-object

  const { data: sucursales = [], isLoading } = useQuery({
    queryKey: ['sucursales'],
    queryFn: getSucursales,
    enabled: puedeVer,
  });

  const eliminar = useMutation({
    mutationFn: (id) => eliminarSucursal(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['sucursales'] });
      setConfirmar(null);
    },
    onError: (err) => alert(err?.response?.data?.mensaje ?? 'Error al eliminar la sucursal'),
  });

  if (!puedeVer) {
    return (
      <div className="flex flex-col items-center justify-center h-64 gap-3 text-gray-400 dark:text-gray-600">
        <AlertCircle className="w-10 h-10" />
        <p className="font-medium">No tienes permiso para ver las sucursales</p>
      </div>
    );
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64 gap-3 text-gray-400">
        <RefreshCw className="w-5 h-5 animate-spin" /><span>Cargando...</span>
      </div>
    );
  }

  return (
    <div className="space-y-6 max-w-4xl">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-gray-800 dark:text-gray-100">Sucursales</h1>
          <p className="text-sm text-gray-400 mt-0.5">{sucursales.length} sucursales registradas</p>
        </div>
        {puedeCrear && (
          <button
            onClick={() => setModalForm('nuevo')}
            className="flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-xl text-sm font-semibold transition-colors"
          >
            <Plus className="w-4 h-4" /> Nueva Sucursal
          </button>
        )}
      </div>

      <div className="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-2xl overflow-hidden">
        {sucursales.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-16 gap-3 text-gray-400">
            <Building2 className="w-10 h-10" />
            <p className="text-sm">No hay sucursales registradas</p>
          </div>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-gray-50 dark:bg-gray-700/50 border-b border-gray-200 dark:border-gray-700">
                <th className="px-5 py-3 text-left text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">Sucursal</th>
                <th className="px-5 py-3 text-left text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">Dirección</th>
                <th className="px-5 py-3 text-left text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">Teléfono</th>
                <th className="px-5 py-3 text-center text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">Estado</th>
                <th className="px-5 py-3" />
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
              {sucursales.map(s => (
                <tr key={s.id} className="hover:bg-gray-50 dark:hover:bg-gray-700/30 transition-colors">
                  <td className="px-5 py-3.5">
                    <div className="flex items-center gap-2.5">
                      <div className="w-8 h-8 rounded-lg bg-blue-100 dark:bg-blue-900/30 flex items-center justify-center shrink-0">
                        <Building2 className="w-4 h-4 text-blue-600 dark:text-blue-400" />
                      </div>
                      <span className="font-semibold text-gray-800 dark:text-gray-100">{s.nombre}</span>
                    </div>
                  </td>
                  <td className="px-5 py-3.5 text-gray-500 dark:text-gray-400">
                    {s.direccion || <span className="italic text-gray-300 dark:text-gray-600">—</span>}
                  </td>
                  <td className="px-5 py-3.5 text-gray-500 dark:text-gray-400">
                    {s.telefono || <span className="italic text-gray-300 dark:text-gray-600">—</span>}
                  </td>
                  <td className="px-5 py-3.5 text-center">
                    <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${s.activo ? 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-300' : 'bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-300'}`}>
                      {s.activo ? 'Activa' : 'Inactiva'}
                    </span>
                  </td>
                  <td className="px-5 py-3.5">
                    <div className="flex items-center justify-end gap-1">
                      {puedeEditar && (
                        <button
                          onClick={() => setModalForm(s)}
                          className="p-1.5 rounded-lg text-gray-400 hover:text-blue-600 hover:bg-blue-50 dark:hover:bg-blue-900/20 transition-colors"
                          title="Editar"
                        >
                          <Pencil className="w-4 h-4" />
                        </button>
                      )}
                      {puedeEliminar && (
                        <button
                          onClick={() => setConfirmar(s)}
                          className="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors"
                          title="Eliminar"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {modalForm !== null && (
        <ModalSucursal
          sucursal={modalForm === 'nuevo' ? null : modalForm}
          onClose={() => setModalForm(null)}
          onExito={() => {
            setModalForm(null);
            qc.invalidateQueries({ queryKey: ['sucursales'] });
          }}
        />
      )}

      {confirmar && (
        <Modal titulo="Eliminar sucursal" onClose={() => setConfirmar(null)} ancho="max-w-sm">
          <div className="space-y-4">
            <p className="text-sm text-gray-600 dark:text-gray-300">
              ¿Eliminar la sucursal <span className="font-semibold text-gray-800 dark:text-gray-100">"{confirmar.nombre}"</span>?
              Esta acción no se puede deshacer.
            </p>
            <div className="bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-xl px-4 py-3 text-xs text-amber-700 dark:text-amber-400">
              Solo se puede eliminar si no hay usuarios asignados a esta sucursal.
            </div>
            <div className="flex justify-end gap-3">
              <button
                onClick={() => setConfirmar(null)}
                className="px-4 py-2 rounded-xl text-sm text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
              >
                Cancelar
              </button>
              <button
                onClick={() => eliminar.mutate(confirmar.id)}
                disabled={eliminar.isPending}
                className="px-5 py-2 rounded-xl text-sm bg-red-600 hover:bg-red-700 text-white font-semibold transition-colors disabled:opacity-60"
              >
                {eliminar.isPending ? 'Eliminando...' : 'Eliminar'}
              </button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}

function ModalSucursal({ sucursal, onClose, onExito }) {
  const esNuevo = !sucursal;
  const [nombre, setNombre]       = useState(sucursal?.nombre ?? '');
  const [direccion, setDireccion] = useState(sucursal?.direccion ?? '');
  const [telefono, setTelefono]   = useState(sucursal?.telefono ?? '');
  const [activo, setActivo]       = useState(sucursal?.activo ?? 1);
  const [error, setError]         = useState(null);

  const guardar = useMutation({
    mutationFn: () => {
      const datos = { nombre: nombre.trim(), direccion: direccion.trim(), telefono: telefono.trim(), activo };
      return esNuevo ? crearSucursal(datos) : actualizarSucursal(sucursal.id, datos);
    },
    onSuccess: onExito,
    onError: (err) => setError(err?.response?.data?.mensaje ?? 'Error al guardar la sucursal'),
  });

  return (
    <Modal titulo={esNuevo ? 'Nueva Sucursal' : `Editar: ${sucursal.nombre}`} onClose={onClose} ancho="max-w-md">
      <div className="space-y-4">
        <div>
          <label className="block text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-1.5">
            Nombre <span className="text-red-500">*</span>
          </label>
          <input
            autoFocus
            value={nombre}
            onChange={e => { setNombre(e.target.value); setError(null); }}
            placeholder="Ej: Sucursal Centro"
            className="w-full bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-gray-800 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500 transition"
          />
        </div>
        <div>
          <label className="block text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-1.5">
            Dirección
          </label>
          <input
            value={direccion}
            onChange={e => setDireccion(e.target.value)}
            placeholder="Av. Principal #123"
            className="w-full bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-gray-800 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500 transition"
          />
        </div>
        <div>
          <label className="block text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-1.5">
            Teléfono
          </label>
          <input
            value={telefono}
            onChange={e => setTelefono(e.target.value)}
            placeholder="70000000"
            className="w-full bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-gray-800 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500 transition"
          />
        </div>
        {!esNuevo && (
          <div className="flex items-center gap-3">
            <label className="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">Estado</label>
            <button
              type="button"
              onClick={() => setActivo(a => a ? 0 : 1)}
              className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${activo ? 'bg-emerald-500' : 'bg-gray-300 dark:bg-gray-600'}`}
            >
              <span className={`inline-block h-4 w-4 transform rounded-full bg-white shadow transition-transform ${activo ? 'translate-x-6' : 'translate-x-1'}`} />
            </button>
            <span className="text-xs text-gray-500 dark:text-gray-400">{activo ? 'Activa' : 'Inactiva'}</span>
          </div>
        )}
        {error && <p className="text-sm text-red-600">{error}</p>}
        <div className="flex justify-end gap-3 pt-1 border-t border-gray-100 dark:border-gray-700">
          <button onClick={onClose} className="px-4 py-2 rounded-xl text-sm text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors">
            Cancelar
          </button>
          <button
            onClick={() => guardar.mutate()}
            disabled={guardar.isPending || !nombre.trim()}
            className="px-5 py-2 rounded-xl text-sm bg-blue-600 hover:bg-blue-700 text-white font-semibold transition-colors disabled:opacity-60"
          >
            {guardar.isPending ? 'Guardando...' : esNuevo ? 'Crear Sucursal' : 'Guardar cambios'}
          </button>
        </div>
      </div>
    </Modal>
  );
}
```

- [ ] **Step 2: Register the route in `router/index.jsx`**

Add the import next to `import RolesPage from '../pages/roles/RolesPage';`:

```javascript
import SucursalesPage from '../pages/sucursales/SucursalesPage';
```

Add the route next to `{ path: '/roles', element: <RolesPage /> },`:

```javascript
            { path: '/sucursales',       element: <SucursalesPage /> },
```

- [ ] **Step 3: Add the nav item in `Sidebar.jsx`**

Add `Building2` to the `lucide-react` import list. Add this entry to `NAV_ITEMS`, next to the `roles` entry:

```javascript
  { to: '/sucursales',   label: 'Sucursales',    Icono: Building2,       modulo: 'sucursales',    accion: 'ver' },
```

- [ ] **Step 4: Manually verify**

With backend + frontend dev servers running, log in as admin (has `sucursales.*` via the `Administrador` role):
1. Sidebar shows a "Sucursales" entry; clicking it loads `/sucursales`.
2. The table shows "Sucursal Principal" from the seed.
3. Create a new sucursal, edit its name, then delete it — confirm each operation reflects immediately (React Query invalidation) and no console errors appear.
4. Try deleting "Sucursal Principal" — expect the 409 error message ("La sucursal tiene usuarios asignados") to show via the `alert`.

Expected: all four checks pass.

- [ ] **Step 5: Commit**

```bash
git add frontend/src/pages/sucursales frontend/src/router/index.jsx frontend/src/components/layout/Sidebar.jsx
git commit -m "feat(frontend): sucursales management page"
```

---

### Task 10: Frontend — asignar sucursales a un usuario desde UsuariosPage

**Files:**
- Modify: `frontend/src/pages/usuarios/UsuariosPage.jsx`

**Interfaces:**
- Consumes: `getSucursales` (Task 6), `actualizarSucursalesUsuario` (Task 6).
- Produces: a "Sucursales" section in the user edit modal, letting an admin multi-select branches or flip "Acceso a todas las sucursales".

- [ ] **Step 1: Import the new API functions and add the query**

At the top of `UsuariosPage.jsx`, update the imports:

```javascript
import { getUsuarios, crearUsuario, actualizarUsuario, eliminarUsuario, actualizarSucursalesUsuario } from '../../api/usuarios';
import { getSucursales } from '../../api/sucursales';
```

In `UsuariosPage()`, after the existing `roles` query, add:

```javascript
  const { data: sucursalesCatalogo = [] } = useQuery({
    queryKey: ['sucursales'],
    queryFn: getSucursales,
    enabled: puedoEditar,
    staleTime: 60_000,
  });
```

- [ ] **Step 2: Pass the catalog and a save handler down to the modal**

In the `ModalUsuario` render call, add two props:

```jsx
        <ModalUsuario
          usuario={modal.usuario}
          roles={roles}
          sucursalesCatalogo={sucursalesCatalogo}
          onClose={() => setModal(null)}
          onGuardar={guardarUsuario}
        />
```

Add a mutation for the assignment, next to `mutEditar`:

```javascript
  const mutSucursales = useMutation({
    mutationFn: ({ id, datos }) => actualizarSucursalesUsuario(id, datos),
    onSuccess: invalidar,
  });
```

- [ ] **Step 3: Extend `ModalUsuario` with the sucursales section**

Update the `ModalUsuario` function signature and add state:

```javascript
function ModalUsuario({ usuario, roles, sucursalesCatalogo, onClose, onGuardar, onGuardarSucursales }) {
  const esNuevo = !usuario;
  const [form, setForm] = useState(
    usuario
      ? { nombre: usuario.nombre, email: usuario.email, contrasena: '', rol_id: usuario.rol?.id ?? '', activo: usuario.activo }
      : CAMPOS_INICIALES
  );
  const [mostrarPass, setMostrarPass] = useState(false);
  const [error, setError] = useState('');
  const [sucursalIds, setSucursalIds] = useState(
    new Set((usuario?.sucursales ?? []).map(s => s.id))
  );
  const [accesoTodas, setAccesoTodas] = useState(!!usuario?.acceso_todas_sucursales);

  const toggleSucursal = (id) => {
    setSucursalIds(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };
```

(Note `onGuardarSucursales` is a new prop — wire it from the parent's mutation in Step 2's render call: `onGuardarSucursales={(datos) => mutSucursales.mutate({ id: usuario.id, datos })}`, only meaningful when editing, i.e. `!esNuevo`.)

- [ ] **Step 4: Render the sucursales section (edit mode only) and wire the save button**

Add this block right before the `{error && ...}` line inside the `<form>`:

```jsx
          {!esNuevo && (
            <div className="pt-2 border-t border-gray-100 dark:border-gray-700 space-y-2.5">
              <label className="block text-xs font-medium text-gray-700 dark:text-gray-300">Sucursales</label>

              <label className="flex items-center gap-2 text-xs text-gray-600 dark:text-gray-300 cursor-pointer">
                <input
                  type="checkbox"
                  checked={accesoTodas}
                  onChange={e => setAccesoTodas(e.target.checked)}
                  className="w-3.5 h-3.5 rounded accent-blue-600"
                />
                Acceso a todas las sucursales
              </label>

              {!accesoTodas && (
                <div className="max-h-32 overflow-y-auto space-y-1 rounded-lg border border-gray-200 dark:border-gray-600 p-2">
                  {sucursalesCatalogo.map(s => (
                    <label key={s.id} className="flex items-center gap-2 text-xs text-gray-600 dark:text-gray-300 cursor-pointer">
                      <input
                        type="checkbox"
                        checked={sucursalIds.has(s.id)}
                        onChange={() => toggleSucursal(s.id)}
                        className="w-3.5 h-3.5 rounded accent-blue-600"
                      />
                      {s.nombre}
                    </label>
                  ))}
                </div>
              )}

              <button
                type="button"
                onClick={() => onGuardarSucursales({ sucursal_ids: [...sucursalIds], acceso_todas_sucursales: accesoTodas })}
                className="w-full py-1.5 text-xs rounded-lg border border-blue-300 dark:border-blue-600 text-blue-700 dark:text-blue-300 hover:bg-blue-50 dark:hover:bg-blue-900/20"
              >
                Guardar sucursales
              </button>
            </div>
          )}
```

- [ ] **Step 5: Pass `onGuardarSucursales` from the page render call**

Update the render call from Step 2 to conditionally include the handler:

```jsx
        <ModalUsuario
          usuario={modal.usuario}
          roles={roles}
          sucursalesCatalogo={sucursalesCatalogo}
          onClose={() => setModal(null)}
          onGuardar={guardarUsuario}
          onGuardarSucursales={modal.usuario ? (datos) => mutSucursales.mutate({ id: modal.usuario.id, datos }) : undefined}
        />
```

- [ ] **Step 6: Manually verify**

With both dev servers running, log in as admin, go to `/usuarios`, edit a non-admin user:
1. Check "Acceso a todas las sucursales", click "Guardar sucursales" — reopen the modal, the checkbox should stay checked (confirms it persisted and `listar()`/`obtener()` return it).
2. Uncheck it, select one or two sucursales from the list, save — reopen, confirm the same sucursales are checked.
3. Log in as that user (if you know/can set their password) — confirm the sucursal-selection screen from Task 7 shows exactly the sucursales you assigned.

Expected: all three checks pass, no console errors.

- [ ] **Step 7: Commit**

```bash
git add frontend/src/pages/usuarios/UsuariosPage.jsx
git commit -m "feat(frontend): assign sucursales to a user from the admin UI"
```

---

## Post-plan note (deploy)

This plan only touches the local dev DB (`bd_restaurante`). Before this reaches `salybrasas.codewave.com.bo`, migration `012_sucursales.sql` and `npm run seed` must also be run against the production DB (`salybrasas_db`) per the steps in Task 1/Task 2 — substitute the DB name/credentials from `backend/.env` on the VPS. Not part of this plan's scope; call it out when Fase 1 is ready to ship.
