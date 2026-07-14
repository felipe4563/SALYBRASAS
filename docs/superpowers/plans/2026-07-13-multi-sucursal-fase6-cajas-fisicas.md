# Multi-sucursal Fase 6: Cajas físicas por sucursal — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introducir una entidad `Caja` (punto de cobro físico, uno o
más por sucursal), gestionada por el administrador, con la regla de
que una caja solo puede tener una sesión abierta a la vez — esto
reemplaza el mecanismo de "elegir sucursal_id libremente" que la Fase 5
agregó para abrir/ver caja activa.

**Architecture:** Nueva tabla `cajas` (belongsTo Sucursal) y nueva
columna `sesiones_caja.caja_id`. Nuevo módulo backend `cajas` (CRUD,
mismo patrón que `sucursales`). El módulo `caja` (sesiones) cambia
`abrir` para recibir `caja_id` en vez de `sucursal_id`, reemplaza
`GET /caja/activa` por `GET /caja/estado?sucursal_id=` (lista de cajas
de una sucursal con su estado), y extiende `obtener` para incluir
`ventas_efectivo`/`ventas_qr`. Frontend: página nueva "Cajas" (catálogo)
y rediseño de la pantalla operativa "Caja" de "una sesión activa" a una
grilla responsiva de tarjetas (una por caja).

**Tech Stack:** Node.js/Express/Sequelize (backend), React 18 + Vite +
TanStack Query + Zustand (frontend), Jest + Supertest (tests backend,
contra la base de datos real de desarrollo, sin mocks). No hay test
runner de frontend — verificación por `npx vite build` + trazado manual.

## Global Constraints

- Una caja pertenece a exactamente una sucursal (`cajas.sucursal_id NOT NULL`).
- Una caja no puede tener dos `sesiones_caja` con `estado='abierta'`
  simultáneamente — intentar abrir una caja ya abierta es 409.
- `sesiones_caja.sucursal_id` no se elimina ni se deja de poblar — sigue
  denormalizado (ahora derivado de `caja.sucursal_id` al abrir), para
  no romper ningún reporte/consulta de las Fases 2-5 que ya filtra por
  esa columna.
- Un usuario que no es acceso-todas solo puede abrir/ver cajas de su
  propia sucursal (404, no 403, si intenta otra — mismo patrón anti-IDOR
  de fases anteriores). Un usuario acceso-todas puede operar cualquier
  caja de cualquier sucursal (el frontend ya restringe con el selector
  de sucursal + lista de cajas de esa sucursal).
- Eliminar una caja se bloquea (409) si tiene alguna sesión asociada
  (abierta o histórica) — mismo patrón que `sucursales.eliminar`
  (bloqueado si tiene usuarios asignados).
- Migraciones (`backend/database/migrations/*.sql`) son solo de
  esquema, sin INSERT/UPDATE de datos — el backfill de datos existentes
  va en `backend/database/seeds/seed.js` (idempotente), igual que hizo
  la Fase 2 con `sucursal_id`.
- La pantalla operativa de Caja debe ser responsiva: 1 columna en
  mobile, más columnas en tablet/desktop (mismo breakpoint `sm`/`lg` que
  ya usa el resto de la app).

---

### Task 1: Backend — Migración, modelo Caja, asociaciones, seed

**Files:**
- Create: `backend/database/migrations/014_cajas.sql`
- Create: `backend/src/models/Caja.js`
- Modify: `backend/src/models/index.js`
- Modify: `backend/src/models/SesionCaja.js`
- Modify: `backend/database/seeds/seed.js`
- Modify: `backend/tests/ventas.test.js`
- Modify: `backend/tests/reportes.test.js`

**Interfaces:**
- Produces: modelo `Caja` (`id, sucursal_id, nombre, activo`), export
  desde `models/index.js`; `SesionCaja.caja_id` (NOT NULL) — usado por
  Task 2 (módulo `cajas`) y Task 3 (módulo `caja` de sesiones).

- [ ] **Step 1: Escribir la migración de esquema**

Crear `backend/database/migrations/014_cajas.sql`:

```sql
CREATE TABLE IF NOT EXISTS cajas (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sucursal_id INT UNSIGNED NOT NULL,
  nombre VARCHAR(100) NOT NULL,
  activo TINYINT(1) NOT NULL DEFAULT 1,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (sucursal_id) REFERENCES sucursales(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE sesiones_caja
  ADD COLUMN caja_id INT UNSIGNED NOT NULL AFTER sucursal_id,
  ADD FOREIGN KEY (caja_id) REFERENCES cajas(id);
```

- [ ] **Step 2: Aplicar la migración**

Run: `mysql -u root -p bd_restaurante < database/migrations/014_cajas.sql` (desde `backend/`)

Expected: si `sesiones_caja` ya tiene filas (muy probable en esta base
de desarrollo, que viene de las Fases 1-5), el `ADD COLUMN ... NOT NULL`
va a fallar con un error de columna sin default. Esto es esperado — no
modifiques el archivo de migración committeado (asume una base
fresca/vacía, correcto para una instalación nueva). En su lugar, aplicá
localmente en 3 pasos:

```sql
-- 1. Agregar como nullable
ALTER TABLE cajas ...  -- (el CREATE TABLE de arriba, sin cambios, no falla porque es tabla nueva)
ALTER TABLE sesiones_caja ADD COLUMN caja_id INT UNSIGNED NULL AFTER sucursal_id, ADD FOREIGN KEY (caja_id) REFERENCES cajas(id);
```
Luego el Step 5 (correr `npm run seed`) hace el backfill, y recién
después:
```sql
-- 3. Ya con todas las filas backfilleadas, forzar NOT NULL
ALTER TABLE sesiones_caja MODIFY COLUMN caja_id INT UNSIGNED NOT NULL;
```
No corras este paso 3 hasta confirmar (Step 6) que no quedan
`caja_id IS NULL`.

- [ ] **Step 3: Crear el modelo `Caja`**

Crear `backend/src/models/Caja.js`:

```javascript
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Caja = sequelize.define('Caja', {
  id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
  sucursal_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
  nombre: { type: DataTypes.STRING(100), allowNull: false },
  activo: { type: DataTypes.TINYINT(1), defaultValue: 1 },
}, {
  tableName: 'cajas',
  createdAt: 'creado_en',
  updatedAt: 'actualizado_en',
});

module.exports = Caja;
```

En `backend/src/models/SesionCaja.js`, agregar el campo `caja_id` justo
después de `sucursal_id`:

```javascript
  sucursal_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
  caja_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
```

- [ ] **Step 4: Registrar el modelo y sus asociaciones en `models/index.js`**

Agregar el `require` junto a los demás (después de la línea de
`ProductoStockSucursal`):

```javascript
const Caja = require('./Caja');
```

Agregar las asociaciones, después del bloque `// Sucursal_id operativo (Fase 2)`:

```javascript
// Cajas físicas (Fase 6)
Caja.belongsTo(Sucursal, { foreignKey: 'sucursal_id', as: 'sucursal' });
Sucursal.hasMany(Caja, { foreignKey: 'sucursal_id', as: 'cajas' });
Caja.hasMany(SesionCaja, { foreignKey: 'caja_id', as: 'sesiones' });
SesionCaja.belongsTo(Caja, { foreignKey: 'caja_id', as: 'caja' });
```

Agregar `Caja` al `module.exports` final (junto a `ProductoStockSucursal`):

```javascript
  ProductoStockSucursal,
  Caja,
};
```

- [ ] **Step 5: Backfill en el seed — una "Caja Principal" por sucursal existente**

En `backend/database/seeds/seed.js`, agregar `Caja` al `require` de
modelos (línea 3) y, después del bloque
`// Backfill operativo Fase 2 — todo lo existente queda en la Sucursal Principal`
(antes del bloque de `productosConStock`), agregar:

```javascript
  // Backfill Fase 6 — una Caja Principal por cada sucursal existente
  const sucursalesExistentes = await Sucursal.findAll();
  for (const s of sucursalesExistentes) {
    const [cajaPrincipal] = await Caja.findOrCreate({
      where: { sucursal_id: s.id, nombre: 'Caja Principal' },
      defaults: { activo: 1 },
    });
    await sequelize.query(
      'UPDATE sesiones_caja SET caja_id = ? WHERE sucursal_id = ? AND caja_id IS NULL',
      { replacements: [cajaPrincipal.id, s.id] }
    );
  }
```

Run: `npm run seed` (desde `backend/`)
Expected: "Seed completado", sin errores.

- [ ] **Step 6: Verificar que no queda ningún `caja_id` nulo, y forzar NOT NULL si aplicaste el paso nullable**

Run: `mysql -u root -p bd_restaurante -e "SELECT COUNT(*) FROM sesiones_caja WHERE caja_id IS NULL;"`
Expected: `0`. Si diste el Step 2 en 3 pasos (nullable primero), ahora sí:
Run: `mysql -u root -p bd_restaurante -e "ALTER TABLE sesiones_caja MODIFY COLUMN caja_id INT UNSIGNED NOT NULL;"`

- [ ] **Step 7: Arreglar los fixtures de tests que crean `SesionCaja` directamente**

`SesionCaja.create(...)` ahora exige `caja_id`. Dos archivos de test lo
crean directamente (sin pasar por `caja.service.js`) y van a fallar con
un error de validación de Sequelize hasta que se les agregue una `Caja`.

En `backend/tests/ventas.test.js`, agregar `Caja` al `require` de
modelos (línea 16). En el bloque `describe('Ventas por sucursal', ...)`
(alrededor de la línea 40), justo antes de la línea
`const sesion = await SesionCaja.create({ usuario_id: usuarioBId, sucursal_id: sucursalB.id, monto_apertura: 0 });`:

```javascript
    const cajaB = await Caja.create({ sucursal_id: sucursalB.id, nombre: 'Caja Ventas Test B' });
    const sesion = await SesionCaja.create({ usuario_id: usuarioBId, sucursal_id: sucursalB.id, caja_id: cajaB.id, monto_apertura: 0 });
```

En el bloque `describe('Ventas - aislamiento entre sucursales (acceso por id)', ...)`
(alrededor de la línea 111), mismo cambio para `sucursalA`:

```javascript
    const cajaA = await Caja.create({ sucursal_id: sucursalA.id, nombre: 'Caja Aislamiento A' });
    const sesion = await SesionCaja.create({ usuario_id: usuarioAId, sucursal_id: sucursalA.id, caja_id: cajaA.id, monto_apertura: 0 });
```

Ninguno de los dos bloques necesita destruir la `Caja` explícitamente en
su `afterAll` — al destruirse la `Sucursal` de prueba, la FK
`cajas.sucursal_id` (sin `ON DELETE CASCADE`) haría fallar el
`Sucursal.destroy` si la `Caja` sigue existiendo, así que agregá
`await Caja.destroy({ where: { sucursal_id: sucursalB.id } });` (o
`sucursalA.id`, según el bloque) en el `afterAll` correspondiente,
**antes** de la línea que borra la sucursal.

En `backend/tests/reportes.test.js`, agregar `Caja` al `require` de
modelos (línea 3). En `beforeAll` (línea 16), antes de
`const sesion = await SesionCaja.create({ usuario_id: 1, sucursal_id: sucursalOtra.id, monto_apertura: 0 });`:

```javascript
    const cajaOtra = await Caja.create({ sucursal_id: sucursalOtra.id, nombre: 'Caja Reportes Test' });
    const sesion = await SesionCaja.create({ usuario_id: 1, sucursal_id: sucursalOtra.id, caja_id: cajaOtra.id, monto_apertura: 0 });
```

En el test `'el reporte de caja filtra por sucursal e incluye el objeto sucursal en cada fila'`
(línea 62), mismo cambio, reusando `cajaOtra` (ya está en scope del
`describe` si se declara con `let` a nivel de bloque — declarala junto a
`sucursalOtra` al inicio del `describe` y asignala en `beforeAll`):

```javascript
    const sesionOtra = await SesionCaja.create({ usuario_id: 1, sucursal_id: sucursalOtra.id, caja_id: cajaOtra.id, monto_apertura: 0 });
```

En el `afterAll` de `reportes.test.js` (línea 34-39), agregar
`await Caja.destroy({ where: { sucursal_id: sucursalOtra.id } });`
antes de `await Sucursal.destroy(...)`.

- [ ] **Step 8: Correr toda la suite de tests backend**

Run: `cd backend && npx jest`
Expected: todos los tests pasan (incluidos `ventas.test.js` y
`reportes.test.js`, que ahora crean su `Caja` fixture correctamente).
Los tests de `caja.test.js` van a fallar en este punto — eso se corrige
recién en la Task 3, cuando `abrir`/`activa` cambien de firma. Confirmá
específicamente que `ventas.test.js` y `reportes.test.js` pasan:

Run: `cd backend && npx jest ventas.test.js reportes.test.js`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add backend/database/migrations/014_cajas.sql backend/src/models/Caja.js backend/src/models/index.js backend/src/models/SesionCaja.js backend/database/seeds/seed.js backend/tests/ventas.test.js backend/tests/reportes.test.js
git commit -m "feat(cajas): modelo Caja, migración y backfill de Caja Principal por sucursal"
```

---

### Task 2: Backend — Módulo `cajas` (catálogo CRUD) + permisos

**Files:**
- Create: `backend/src/modules/cajas/cajas.service.js`
- Create: `backend/src/modules/cajas/cajas.controller.js`
- Create: `backend/src/modules/cajas/cajas.routes.js`
- Modify: `backend/src/app.js`
- Modify: `backend/database/seeds/seed.js`
- Test: `backend/tests/cajas.test.js`

**Interfaces:**
- Consumes: modelo `Caja` (Task 1).
- Produces: `GET/POST/PUT/DELETE /api/v1/cajas` — usado por el frontend
  (Task 4) y, indirectamente, es el catálogo que Task 3 lee para
  construir el estado por sucursal.

- [ ] **Step 1: Agregar los permisos nuevos al seed**

En `backend/database/seeds/seed.js`, agregar al arreglo `PERMISOS`
(junto a los de `sucursales`):

```javascript
  { modulo: 'cajas', accion: 'ver',      descripcion: 'Ver cajas' },
  { modulo: 'cajas', accion: 'crear',    descripcion: 'Crear cajas' },
  { modulo: 'cajas', accion: 'editar',   descripcion: 'Editar cajas' },
  { modulo: 'cajas', accion: 'eliminar', descripcion: 'Eliminar cajas' },
```

Run: `npm run seed` (desde `backend/`) para que el rol Administrador
reciba los permisos nuevos (la lógica `admin.setPermisos(permisosCreados)`
ya existente los toma automáticamente).

- [ ] **Step 2: Escribir el service**

Crear `backend/src/modules/cajas/cajas.service.js`:

```javascript
const { Caja, Sucursal } = require('../../models');

async function listar({ sucursal_id } = {}) {
  const where = {};
  if (sucursal_id) where.sucursal_id = sucursal_id;
  return Caja.findAll({
    where,
    include: [{ model: Sucursal, as: 'sucursal', attributes: ['id', 'nombre'] }],
    order: [['nombre', 'ASC']],
  });
}

async function crear({ sucursal_id, nombre, activo = 1 }) {
  if (!sucursal_id) throw Object.assign(new Error('sucursal_id es requerido'), { status: 400 });
  if (!nombre || !nombre.trim()) throw Object.assign(new Error('El nombre es requerido'), { status: 400 });
  const sucursal = await Sucursal.findByPk(sucursal_id);
  if (!sucursal) throw Object.assign(new Error('Sucursal no encontrada'), { status: 404 });
  return Caja.create({ sucursal_id, nombre: nombre.trim(), activo });
}

async function actualizar(id, { nombre, activo }) {
  const caja = await Caja.findByPk(id);
  if (!caja) throw Object.assign(new Error('Caja no encontrada'), { status: 404 });
  const datos = {};
  if (nombre !== undefined) datos.nombre = nombre;
  if (activo !== undefined) datos.activo = activo;
  await caja.update(datos);
  return caja;
}

async function eliminar(id) {
  const caja = await Caja.findByPk(id);
  if (!caja) throw Object.assign(new Error('Caja no encontrada'), { status: 404 });
  const sesiones = await caja.countSesiones();
  if (sesiones > 0) throw Object.assign(new Error('La caja tiene sesiones asociadas'), { status: 409 });
  await caja.destroy();
}

module.exports = { listar, crear, actualizar, eliminar };
```

- [ ] **Step 3: Escribir el controller**

Crear `backend/src/modules/cajas/cajas.controller.js`:

```javascript
const svc = require('./cajas.service');

async function listar(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listar(req.query) }); }
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

- [ ] **Step 4: Escribir las rutas**

Crear `backend/src/modules/cajas/cajas.routes.js`:

```javascript
const { Router } = require('express');
const ctrl = require('./cajas.controller');
const auth = require('../../middlewares/auth');
const { verificarPermiso } = require('../../middlewares/permisos');

const router = Router();
router.use(auth);

router.get('/', verificarPermiso('cajas', 'ver'), ctrl.listar);
router.post('/', verificarPermiso('cajas', 'crear'), ctrl.crear);
router.put('/:id', verificarPermiso('cajas', 'editar'), ctrl.actualizar);
router.delete('/:id', verificarPermiso('cajas', 'eliminar'), ctrl.eliminar);

module.exports = router;
```

- [ ] **Step 5: Montar las rutas en `app.js`**

En `backend/src/app.js`, agregar el `require` junto a
`sucursalesRoutes` (línea 9):

```javascript
const cajasRoutes = require('./modules/cajas/cajas.routes');
```

Y el `app.use` junto a `sucursales` (línea 42):

```javascript
app.use('/api/v1/cajas', cajasRoutes);
```

- [ ] **Step 6: Escribir los tests**

Crear `backend/tests/cajas.test.js`:

```javascript
const request = require('supertest');
const app = require('../src/app');
const { Sucursal, Caja, SesionCaja, Usuario, Rol } = require('../src/models');
const bcrypt = require('bcryptjs');

describe('Cajas API', () => {
  it('GET /api/v1/cajas sin token → 401', async () => {
    const res = await request(app).get('/api/v1/cajas');
    expect(res.status).toBe(401);
  });
});

describe('Cajas CRUD', () => {
  let adminToken, sucursalTest;

  beforeAll(async () => {
    const login = await request(app).post('/api/v1/auth/login').send({ email: 'admin@restaurante.com', contrasena: process.env.ADMIN_PASSWORD || 'admin123' });
    adminToken = login.body.datos.token;
    sucursalTest = await Sucursal.create({ nombre: 'Sucursal Cajas Test' });
  });

  afterAll(async () => {
    await Caja.destroy({ where: { sucursal_id: sucursalTest.id } });
    await Sucursal.destroy({ where: { id: sucursalTest.id } });
  });

  it('crea una caja para una sucursal', async () => {
    const res = await request(app)
      .post('/api/v1/cajas')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ sucursal_id: sucursalTest.id, nombre: 'Caja Test 1' });
    expect(res.status).toBe(201);
    expect(res.body.datos.nombre).toBe('Caja Test 1');
    expect(res.body.datos.sucursal_id).toBe(sucursalTest.id);
  });

  it('rechaza crear una caja con sucursal_id inexistente', async () => {
    const res = await request(app)
      .post('/api/v1/cajas')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ sucursal_id: 999999, nombre: 'Caja Fantasma' });
    expect(res.status).toBe(404);
  });

  it('lista cajas filtradas por sucursal', async () => {
    const res = await request(app)
      .get('/api/v1/cajas')
      .query({ sucursal_id: sucursalTest.id })
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(200);
    expect(res.body.datos.length).toBeGreaterThan(0);
    expect(res.body.datos.every(c => c.sucursal_id === sucursalTest.id)).toBe(true);
  });

  it('edita el nombre y estado de una caja', async () => {
    const caja = await Caja.create({ sucursal_id: sucursalTest.id, nombre: 'Caja Editar Test' });
    const res = await request(app)
      .put(`/api/v1/cajas/${caja.id}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ nombre: 'Caja Editada Test', activo: 0 });
    expect(res.status).toBe(200);
    expect(res.body.datos.nombre).toBe('Caja Editada Test');
    expect(res.body.datos.activo).toBe(0);
  });

  it('bloquea eliminar una caja con sesiones asociadas', async () => {
    const caja = await Caja.create({ sucursal_id: sucursalTest.id, nombre: 'Caja Con Sesion Test' });
    const rol = await Rol.findOne({ where: { nombre: 'Cajero' } });
    const hash = await bcrypt.hash('clave123', 10);
    const usuario = await Usuario.create({ rol_id: rol.id, nombre: 'Cajas Test User', email: 'cajas-test-user@restaurante.com', contrasena: hash });
    const sesion = await SesionCaja.create({ usuario_id: usuario.id, sucursal_id: sucursalTest.id, caja_id: caja.id, monto_apertura: 0 });

    const res = await request(app)
      .delete(`/api/v1/cajas/${caja.id}`)
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(409);

    await SesionCaja.destroy({ where: { id: sesion.id } });
    await Usuario.destroy({ where: { id: usuario.id } });
  });

  it('elimina una caja sin sesiones asociadas', async () => {
    const caja = await Caja.create({ sucursal_id: sucursalTest.id, nombre: 'Caja Sin Sesion Test' });
    const res = await request(app)
      .delete(`/api/v1/cajas/${caja.id}`)
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(200);
    const buscar = await Caja.findByPk(caja.id);
    expect(buscar).toBeNull();
  });
});
```

Run: `cd backend && npx jest cajas.test.js -v`
Expected: PASS (7/7).

- [ ] **Step 7: Commit**

```bash
git add backend/src/modules/cajas backend/src/app.js backend/database/seeds/seed.js backend/tests/cajas.test.js
git commit -m "feat(cajas): módulo CRUD de cajas (catálogo), permisos y rutas"
```

---

### Task 3: Backend — Sesiones de caja: `caja_id` en abrir, endpoint `estado`, `obtener` enriquecido

**Files:**
- Modify: `backend/src/modules/caja/caja.service.js`
- Modify: `backend/src/modules/caja/caja.controller.js`
- Modify: `backend/src/modules/caja/caja.routes.js`
- Modify: `backend/tests/caja.test.js` (reescritura completa)

**Interfaces:**
- Consumes: modelo `Caja` (Task 1).
- Produces: `POST /caja/abrir { caja_id, monto_apertura }`,
  `GET /caja/estado?sucursal_id=` (reemplaza `GET /caja/activa`) — usado
  por el frontend en Task 5.

- [ ] **Step 1: Reescribir `caja.service.js`**

Reemplazar el contenido completo de
`backend/src/modules/caja/caja.service.js`:

```javascript
const { SesionCaja, DetalleArqueo, Gasto, LibroCaja, Usuario, Pedido, Mesa, Caja, sequelize } = require('../../models');

async function listarConEstado(sucursal_id) {
  const cajas = await Caja.findAll({
    where: { sucursal_id, activo: 1 },
    order: [['nombre', 'ASC']],
  });
  const sesiones = await SesionCaja.findAll({
    where: { caja_id: cajas.map(c => c.id), estado: 'abierta' },
    include: [{ model: Usuario, as: 'usuario', attributes: ['id', 'nombre'] }],
  });
  return cajas.map(c => {
    const sesion = sesiones.find(s => s.caja_id === c.id) ?? null;
    return { id: c.id, nombre: c.nombre, sesion_abierta: sesion };
  });
}

async function listar(alcance = {}) {
  const where = alcance.acceso_todas ? {} : { sucursal_id: alcance.sucursal_id };
  return SesionCaja.findAll({
    where,
    include: [{ model: Usuario, as: 'usuario', attributes: ['id', 'nombre'] }],
    order: [['abierto_en', 'DESC']],
    limit: 50,
  });
}

function _verificarAlcance(sesion, alcance) {
  if (alcance && !alcance.acceso_todas && sesion.sucursal_id !== alcance.sucursal_id) {
    throw Object.assign(new Error('Sesión no encontrada'), { status: 404 });
  }
}

async function obtener(id, alcance) {
  const s = await SesionCaja.findByPk(id, {
    include: [
      { model: Usuario, as: 'usuario', attributes: ['id', 'nombre'] },
      { model: DetalleArqueo, as: 'detalle_arqueo' },
      { model: Gasto, as: 'gastos' },
    ],
  });
  if (!s) throw Object.assign(new Error('Sesión no encontrada'), { status: 404 });
  _verificarAlcance(s, alcance);

  const [ventasEfectivo, ventasQR] = await Promise.all([
    LibroCaja.sum('monto', { where: { sesion_caja_id: s.id, tipo: 'ingreso', metodo_pago: 'efectivo' } }),
    LibroCaja.sum('monto', { where: { sesion_caja_id: s.id, tipo: 'ingreso', metodo_pago: 'qr' } }),
  ]);

  const datos = s.toJSON();
  datos.ventas_efectivo = ventasEfectivo || 0;
  datos.ventas_qr       = ventasQR       || 0;
  return datos;
}

async function abrir(usuario_id, caja_id, monto_apertura = 0) {
  const caja = await Caja.findByPk(caja_id);
  if (!caja || !caja.activo) throw Object.assign(new Error('Caja no encontrada'), { status: 404 });

  const abierta = await SesionCaja.findOne({ where: { caja_id, estado: 'abierta' } });
  if (abierta) throw Object.assign(new Error('Esta caja ya tiene una sesión abierta'), { status: 409 });

  return SesionCaja.create({ usuario_id, caja_id, sucursal_id: caja.sucursal_id, monto_apertura });
}

async function registrarGasto(sesion_id, usuario_id, { descripcion, monto }, alcance) {
  const sesion = await SesionCaja.findByPk(sesion_id);
  if (!sesion) throw Object.assign(new Error('Sesión no encontrada'), { status: 404 });
  _verificarAlcance(sesion, alcance);
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

async function listarGastos(sesion_id, alcance) {
  const sesion = await SesionCaja.findByPk(sesion_id);
  if (!sesion) throw Object.assign(new Error('Sesión no encontrada'), { status: 404 });
  _verificarAlcance(sesion, alcance);
  return Gasto.findAll({
    where: { sesion_caja_id: sesion_id },
    include: [{ model: Usuario, as: 'usuario', attributes: ['id', 'nombre'] }],
    order: [['creado_en', 'DESC']],
  });
}

async function cerrar(sesion_id, usuario_id, denominaciones = [], alcance) {
  const sesion = await SesionCaja.findByPk(sesion_id);
  if (!sesion) throw Object.assign(new Error('Sesión no encontrada'), { status: 404 });
  _verificarAlcance(sesion, alcance);
  if (sesion.estado !== 'abierta') throw Object.assign(new Error('La sesión ya está cerrada'), { status: 409 });
  if (sesion.usuario_id !== usuario_id) throw Object.assign(new Error('Solo el cajero que abrió puede cerrar la sesión'), { status: 403 });

  const total_fisico = denominaciones.reduce((sum, d) => sum + (parseFloat(d.denominacion) * parseInt(d.cantidad)), 0);

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

  return obtener(sesion_id, alcance);
}

async function reporte(sesion_id, alcance) {
  const sesion = await obtener(sesion_id, alcance);

  const ventasPorMetodoArr = await sequelize.query(
    `SELECT metodo_pago, COUNT(*) as cantidad, SUM(monto) as total
     FROM libro_caja
     WHERE sesion_caja_id = ? AND tipo = 'ingreso'
     GROUP BY metodo_pago`,
    { replacements: [sesion_id], type: sequelize.QueryTypes.SELECT }
  );

  const pedidos = await Pedido.findAll({
    where: { sesion_caja_id: sesion_id, estado: 'completado' },
    include: [{ model: Mesa, as: 'mesa', attributes: ['id', 'nombre'] }],
    order: [['creado_en', 'DESC']],
  });

  const productosVendidos = await sequelize.query(
    `SELECT pr.nombre, SUM(dp.cantidad) AS total_cantidad, SUM(dp.cantidad * dp.precio) AS total
     FROM detalle_pedidos dp
     JOIN pedidos pe ON pe.id = dp.pedido_id
     JOIN productos pr ON pr.id = dp.producto_id
     WHERE pe.sesion_caja_id = ? AND pe.estado = 'completado'
     GROUP BY dp.producto_id, pr.nombre
     ORDER BY total_cantidad DESC`,
    { replacements: [sesion_id], type: sequelize.QueryTypes.SELECT }
  );

  const efectivoEsperado =
    parseFloat(sesion.monto_apertura) +
    parseFloat(ventasPorMetodoArr.find(v => v.metodo_pago === 'efectivo')?.total ?? 0) -
    parseFloat(sesion.total_gastos);

  return {
    sesion,
    ventas_por_metodo: ventasPorMetodoArr,
    pedidos,
    efectivo_esperado: efectivoEsperado,
    productos_vendidos: productosVendidos,
  };
}

module.exports = { listarConEstado, listar, obtener, abrir, registrarGasto, listarGastos, cerrar, reporte };
```

(`obtenerActiva` se elimina del export — reemplazada por
`listarConEstado`. `reporte` usa `sesion.monto_apertura`/`total_gastos`
que siguen viniendo de `obtener`, sin cambios de esos dos campos.)

- [ ] **Step 2: Reescribir `caja.controller.js`**

Reemplazar el contenido completo de
`backend/src/modules/caja/caja.controller.js`:

```javascript
const svc = require('./caja.service');
const { Caja } = require('../../models');

function _alcance(req) {
  return { sucursal_id: req.usuario.sucursal_id, acceso_todas: req.usuario.acceso_todas };
}

async function estado(req, res, next) {
  try {
    const sucursal_id = req.usuario.acceso_todas ? req.query.sucursal_id : req.usuario.sucursal_id;
    if (!sucursal_id) return res.status(400).json({ ok: false, mensaje: 'sucursal_id es requerido' });
    res.json({ ok: true, datos: await svc.listarConEstado(sucursal_id) });
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
    const { caja_id, monto_apertura } = req.body;
    if (!caja_id) return res.status(400).json({ ok: false, mensaje: 'caja_id es requerido' });

    const caja = await Caja.findByPk(caja_id);
    if (!caja) return res.status(404).json({ ok: false, mensaje: 'Caja no encontrada' });
    if (!req.usuario.acceso_todas && caja.sucursal_id !== req.usuario.sucursal_id) {
      return res.status(404).json({ ok: false, mensaje: 'Caja no encontrada' });
    }

    res.status(201).json({ ok: true, datos: await svc.abrir(req.usuario.id, caja_id, monto_apertura) });
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

module.exports = { estado, listar, obtener, abrir, registrarGasto, listarGastos, cerrar, reporte };
```

- [ ] **Step 3: Actualizar las rutas**

Reemplazar el contenido completo de
`backend/src/modules/caja/caja.routes.js`:

```javascript
const { Router } = require('express');
const ctrl = require('./caja.controller');
const auth = require('../../middlewares/auth');
const { verificarPermiso } = require('../../middlewares/permisos');

const router = Router();
router.use(auth);

router.get('/estado', verificarPermiso('caja', 'ver'), ctrl.estado);
router.get('/', verificarPermiso('caja', 'ver'), ctrl.listar);
router.post('/abrir', verificarPermiso('caja', 'abrir'), ctrl.abrir);
router.get('/:id', verificarPermiso('caja', 'ver'), ctrl.obtener);
router.get('/:id/gastos', verificarPermiso('caja', 'ver'), ctrl.listarGastos);
router.post('/:id/gastos', verificarPermiso('caja', 'ver'), ctrl.registrarGasto);
router.post('/:id/cerrar', verificarPermiso('caja', 'cerrar'), ctrl.cerrar);
router.get('/:id/reporte', verificarPermiso('caja', 'ver'), ctrl.reporte);

module.exports = router;
```

(`/estado` va antes de `/:id` en la lista de rutas para que Express no
la confunda con el parámetro `:id`.)

- [ ] **Step 4: Reescribir `backend/tests/caja.test.js` por completo**

Reemplazar el contenido completo del archivo:

```javascript
const request = require('supertest');
const app = require('../src/app');
const { SesionCaja, Caja, Sucursal, Usuario, Rol } = require('../src/models');
const bcrypt = require('bcryptjs');

describe('Caja API', () => {
  it('GET /api/v1/caja/estado sin token → 401', async () => {
    const res = await request(app).get('/api/v1/caja/estado');
    expect(res.status).toBe(401);
  });
});

describe('Caja — apertura por caja física', () => {
  let sucursalPropia, sucursalAjena, cajaPropia, cajaAjena, usuarioId, token;

  beforeAll(async () => {
    sucursalPropia = await Sucursal.create({ nombre: 'Sucursal Caja Fisica Propia Test' });
    sucursalAjena = await Sucursal.create({ nombre: 'Sucursal Caja Fisica Ajena Test' });
    cajaPropia = await Caja.create({ sucursal_id: sucursalPropia.id, nombre: 'Caja 1 Test' });
    cajaAjena = await Caja.create({ sucursal_id: sucursalAjena.id, nombre: 'Caja Ajena Test' });

    const rol = await Rol.findOne({ where: { nombre: 'Cajero' } });
    const hash = await bcrypt.hash('clave123', 10);
    const usuario = await Usuario.create({ rol_id: rol.id, nombre: 'Caja Fisica Test', email: 'caja-fisica-test@restaurante.com', contrasena: hash });
    await usuario.addSucursal(sucursalPropia);
    usuarioId = usuario.id;

    const login = await request(app).post('/api/v1/auth/login').send({ email: 'caja-fisica-test@restaurante.com', contrasena: 'clave123' });
    token = login.body.datos.token;
  });

  afterAll(async () => {
    await SesionCaja.destroy({ where: { usuario_id: usuarioId } });
    await Usuario.destroy({ where: { id: usuarioId } });
    await Caja.destroy({ where: { id: [cajaPropia.id, cajaAjena.id] } });
    await Sucursal.destroy({ where: { id: [sucursalPropia.id, sucursalAjena.id] } });
  });

  it('sin caja_id → 400', async () => {
    const res = await request(app)
      .post('/api/v1/caja/abrir')
      .set('Authorization', `Bearer ${token}`)
      .send({ monto_apertura: 100 });
    expect(res.status).toBe(400);
  });

  it('con caja_id inexistente → 404', async () => {
    const res = await request(app)
      .post('/api/v1/caja/abrir')
      .set('Authorization', `Bearer ${token}`)
      .send({ caja_id: 999999, monto_apertura: 100 });
    expect(res.status).toBe(404);
  });

  it('no puede abrir una caja de otra sucursal', async () => {
    const res = await request(app)
      .post('/api/v1/caja/abrir')
      .set('Authorization', `Bearer ${token}`)
      .send({ caja_id: cajaAjena.id, monto_apertura: 100 });
    expect(res.status).toBe(404);
  });

  it('abre su propia caja correctamente', async () => {
    const res = await request(app)
      .post('/api/v1/caja/abrir')
      .set('Authorization', `Bearer ${token}`)
      .send({ caja_id: cajaPropia.id, monto_apertura: 100 });
    expect(res.status).toBe(201);
    expect(res.body.datos.caja_id).toBe(cajaPropia.id);
    expect(res.body.datos.sucursal_id).toBe(sucursalPropia.id);
  });

  it('no se puede volver a abrir la misma caja mientras sigue abierta (aunque sea otro usuario)', async () => {
    const rol = await Rol.findOne({ where: { nombre: 'Cajero' } });
    const hash = await bcrypt.hash('clave123', 10);
    const otroUsuario = await Usuario.create({ rol_id: rol.id, nombre: 'Caja Fisica Otro Test', email: 'caja-fisica-otro-test@restaurante.com', contrasena: hash });
    await otroUsuario.addSucursal(sucursalPropia);
    const loginOtro = await request(app).post('/api/v1/auth/login').send({ email: 'caja-fisica-otro-test@restaurante.com', contrasena: 'clave123' });

    const res = await request(app)
      .post('/api/v1/caja/abrir')
      .set('Authorization', `Bearer ${loginOtro.body.datos.token}`)
      .send({ caja_id: cajaPropia.id, monto_apertura: 50 });
    expect(res.status).toBe(409);

    await Usuario.destroy({ where: { id: otroUsuario.id } });
  });

  it('GET /caja/estado devuelve la caja con su sesión abierta', async () => {
    const res = await request(app)
      .get('/api/v1/caja/estado')
      .query({ sucursal_id: sucursalPropia.id })
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    const propia = res.body.datos.find(c => c.id === cajaPropia.id);
    expect(propia.sesion_abierta).not.toBeNull();
    expect(propia.sesion_abierta.usuario_id).toBe(usuarioId);
  });
});

describe('Caja — acceso a todas las sucursales', () => {
  let sucursalX, cajaX, usuarioTodasId, tokenTodas;

  beforeAll(async () => {
    sucursalX = await Sucursal.create({ nombre: 'Sucursal Caja Todas X Test' });
    cajaX = await Caja.create({ sucursal_id: sucursalX.id, nombre: 'Caja Todas X Test' });

    const rol = await Rol.findOne({ where: { nombre: 'Administrador' } });
    const hash = await bcrypt.hash('clave123', 10);
    const todas = await Usuario.create({
      rol_id: rol.id, nombre: 'Caja Acceso Todas Fisica Test', email: 'caja-todas-fisica-test@restaurante.com',
      contrasena: hash, acceso_todas_sucursales: 1,
    });
    usuarioTodasId = todas.id;
    const login = await request(app).post('/api/v1/auth/login').send({ email: 'caja-todas-fisica-test@restaurante.com', contrasena: 'clave123' });
    const elegido = await request(app).post('/api/v1/auth/login/sucursal').send({ pre_token: login.body.datos.pre_token, sucursal_id: null });
    tokenTodas = elegido.body.datos.token;
  });

  afterAll(async () => {
    await SesionCaja.destroy({ where: { usuario_id: usuarioTodasId } });
    await Usuario.destroy({ where: { id: usuarioTodasId } });
    await Caja.destroy({ where: { id: cajaX.id } });
    await Sucursal.destroy({ where: { id: sucursalX.id } });
  });

  it('acceso-todas sin sucursal_id → 400 en /caja/estado', async () => {
    const res = await request(app)
      .get('/api/v1/caja/estado')
      .set('Authorization', `Bearer ${tokenTodas}`);
    expect(res.status).toBe(400);
  });

  it('acceso-todas puede ver el estado de cualquier sucursal', async () => {
    const res = await request(app)
      .get('/api/v1/caja/estado')
      .query({ sucursal_id: sucursalX.id })
      .set('Authorization', `Bearer ${tokenTodas}`);
    expect(res.status).toBe(200);
    expect(res.body.datos.some(c => c.id === cajaX.id)).toBe(true);
  });

  it('acceso-todas puede abrir cualquier caja de cualquier sucursal', async () => {
    const res = await request(app)
      .post('/api/v1/caja/abrir')
      .set('Authorization', `Bearer ${tokenTodas}`)
      .send({ caja_id: cajaX.id, monto_apertura: 100 });
    expect(res.status).toBe(201);
    expect(res.body.datos.caja_id).toBe(cajaX.id);
  });
});
```

- [ ] **Step 5: Correr los tests**

Run: `cd backend && npx jest caja.test.js -v`
Expected: PASS (todos).

Run: `cd backend && npx jest`
Expected: toda la suite pasa (incluye `ventas.test.js`, `reportes.test.js`,
`cajas.test.js` de las tareas anteriores).

- [ ] **Step 6: Commit**

```bash
git add backend/src/modules/caja backend/tests/caja.test.js
git commit -m "feat(caja): abrir/estado por caja física en vez de sucursal libre"
```

---

### Task 4: Frontend — Página "Cajas" (catálogo) + ruteo/menú

**Files:**
- Create: `frontend/src/api/cajas.js`
- Create: `frontend/src/pages/cajas/CajasPage.jsx`
- Modify: `frontend/src/router/index.jsx`
- Modify: `frontend/src/components/layout/Sidebar.jsx`

**Interfaces:**
- Consumes: `GET/POST/PUT/DELETE /api/v1/cajas` (Task 2),
  `getSucursales()` de `frontend/src/api/sucursales.js` (ya existe).

- [ ] **Step 1: API client**

Crear `frontend/src/api/cajas.js`:

```javascript
import api from './cliente';

export const getCajas       = (params = {}) => api.get('/cajas', { params }).then(r => r.data.datos);
export const crearCaja      = (datos)       => api.post('/cajas', datos).then(r => r.data.datos);
export const actualizarCaja = (id, datos)   => api.put(`/cajas/${id}`, datos).then(r => r.data.datos);
export const eliminarCaja   = (id)          => api.delete(`/cajas/${id}`).then(r => r.data.datos);
```

- [ ] **Step 2: Página de catálogo**

Crear `frontend/src/pages/cajas/CajasPage.jsx` (calco de
`frontend/src/pages/sucursales/SucursalesPage.jsx`, con `sucursal_id`
en vez de `direccion`/`telefono`, y una columna de sucursal):

```jsx
import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Landmark, Plus, Pencil, Trash2, AlertCircle, RefreshCw } from 'lucide-react';
import { getCajas, crearCaja, actualizarCaja, eliminarCaja } from '../../api/cajas';
import { getSucursales } from '../../api/sucursales';
import { usePermisos } from '../../hooks/usePermisos';
import Modal from '../../components/ui/Modal';

export default function CajasPage() {
  const { tienePermiso } = usePermisos();
  const qc = useQueryClient();

  const puedeVer      = tienePermiso('cajas', 'ver');
  const puedeCrear    = tienePermiso('cajas', 'crear');
  const puedeEditar   = tienePermiso('cajas', 'editar');
  const puedeEliminar = tienePermiso('cajas', 'eliminar');

  const [modalForm, setModalForm] = useState(null); // null | 'nuevo' | caja-object
  const [confirmar, setConfirmar] = useState(null); // null | caja-object

  const { data: cajas = [], isLoading } = useQuery({
    queryKey: ['cajas'],
    queryFn: () => getCajas(),
    enabled: puedeVer,
  });

  const { data: sucursales = [] } = useQuery({
    queryKey: ['sucursales'],
    queryFn: getSucursales,
    enabled: puedeVer,
  });

  const eliminar = useMutation({
    mutationFn: (id) => eliminarCaja(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['cajas'] });
      setConfirmar(null);
    },
    onError: (err) => alert(err?.response?.data?.mensaje ?? 'Error al eliminar la caja'),
  });

  if (!puedeVer) {
    return (
      <div className="flex flex-col items-center justify-center h-64 gap-3 text-gray-400 dark:text-gray-600">
        <AlertCircle className="w-10 h-10" />
        <p className="font-medium">No tienes permiso para ver las cajas</p>
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
          <h1 className="text-xl font-bold text-gray-800 dark:text-gray-100">Cajas</h1>
          <p className="text-sm text-gray-400 mt-0.5">{cajas.length} cajas registradas</p>
        </div>
        {puedeCrear && (
          <button
            onClick={() => setModalForm('nuevo')}
            disabled={sucursales.length === 0}
            className="flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 disabled:opacity-50 text-white rounded-xl text-sm font-semibold transition-colors"
            title={sucursales.length === 0 ? 'Primero crea una sucursal' : ''}
          >
            <Plus className="w-4 h-4" /> Nueva Caja
          </button>
        )}
      </div>

      <div className="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-2xl overflow-hidden">
        {cajas.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-16 gap-3 text-gray-400">
            <Landmark className="w-10 h-10" />
            <p className="text-sm">No hay cajas registradas</p>
          </div>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-gray-50 dark:bg-gray-700/50 border-b border-gray-200 dark:border-gray-700">
                <th className="px-5 py-3 text-left text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">Caja</th>
                <th className="px-5 py-3 text-left text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">Sucursal</th>
                <th className="px-5 py-3 text-center text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">Estado</th>
                <th className="px-5 py-3" />
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
              {cajas.map(c => (
                <tr key={c.id} className="hover:bg-gray-50 dark:hover:bg-gray-700/30 transition-colors">
                  <td className="px-5 py-3.5">
                    <div className="flex items-center gap-2.5">
                      <div className="w-8 h-8 rounded-lg bg-blue-100 dark:bg-blue-900/30 flex items-center justify-center shrink-0">
                        <Landmark className="w-4 h-4 text-blue-600 dark:text-blue-400" />
                      </div>
                      <span className="font-semibold text-gray-800 dark:text-gray-100">{c.nombre}</span>
                    </div>
                  </td>
                  <td className="px-5 py-3.5 text-gray-500 dark:text-gray-400">
                    {c.sucursal?.nombre ?? '—'}
                  </td>
                  <td className="px-5 py-3.5 text-center">
                    <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${c.activo ? 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-300' : 'bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-300'}`}>
                      {c.activo ? 'Activa' : 'Inactiva'}
                    </span>
                  </td>
                  <td className="px-5 py-3.5">
                    <div className="flex items-center justify-end gap-1">
                      {puedeEditar && (
                        <button
                          onClick={() => setModalForm(c)}
                          className="p-1.5 rounded-lg text-gray-400 hover:text-blue-600 hover:bg-blue-50 dark:hover:bg-blue-900/20 transition-colors"
                          title="Editar"
                        >
                          <Pencil className="w-4 h-4" />
                        </button>
                      )}
                      {puedeEliminar && (
                        <button
                          onClick={() => setConfirmar(c)}
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
        <ModalCaja
          caja={modalForm === 'nuevo' ? null : modalForm}
          sucursales={sucursales}
          onClose={() => setModalForm(null)}
          onExito={() => {
            setModalForm(null);
            qc.invalidateQueries({ queryKey: ['cajas'] });
          }}
        />
      )}

      {confirmar && (
        <Modal titulo="Eliminar caja" onClose={() => setConfirmar(null)} ancho="max-w-sm">
          <div className="space-y-4">
            <p className="text-sm text-gray-600 dark:text-gray-300">
              ¿Eliminar la caja <span className="font-semibold text-gray-800 dark:text-gray-100">"{confirmar.nombre}"</span>?
              Esta acción no se puede deshacer.
            </p>
            <div className="bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-xl px-4 py-3 text-xs text-amber-700 dark:text-amber-400">
              Solo se puede eliminar si no tiene sesiones asociadas.
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

function ModalCaja({ caja, sucursales, onClose, onExito }) {
  const esNuevo = !caja;
  const [sucursalId, setSucursalId] = useState(caja?.sucursal_id ?? (sucursales[0]?.id ?? ''));
  const [nombre, setNombre]         = useState(caja?.nombre ?? '');
  const [activo, setActivo]         = useState(caja?.activo ?? 1);
  const [error, setError]           = useState(null);

  const guardar = useMutation({
    mutationFn: () => {
      const datos = esNuevo
        ? { sucursal_id: parseInt(sucursalId), nombre: nombre.trim() }
        : { nombre: nombre.trim(), activo };
      return esNuevo ? crearCaja(datos) : actualizarCaja(caja.id, datos);
    },
    onSuccess: onExito,
    onError: (err) => setError(err?.response?.data?.mensaje ?? 'Error al guardar la caja'),
  });

  return (
    <Modal titulo={esNuevo ? 'Nueva Caja' : `Editar: ${caja.nombre}`} onClose={onClose} ancho="max-w-md">
      <div className="space-y-4">
        {esNuevo && (
          <div>
            <label className="block text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-1.5">
              Sucursal <span className="text-red-500">*</span>
            </label>
            <select
              value={sucursalId}
              onChange={e => setSucursalId(e.target.value)}
              className="w-full bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-gray-800 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              {sucursales.map(s => <option key={s.id} value={s.id}>{s.nombre}</option>)}
            </select>
          </div>
        )}
        <div>
          <label className="block text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-1.5">
            Nombre <span className="text-red-500">*</span>
          </label>
          <input
            autoFocus
            value={nombre}
            onChange={e => { setNombre(e.target.value); setError(null); }}
            placeholder="Ej: Caja 1, Caja Mostrador"
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
            disabled={guardar.isPending || !nombre.trim() || (esNuevo && !sucursalId)}
            className="px-5 py-2 rounded-xl text-sm bg-blue-600 hover:bg-blue-700 text-white font-semibold transition-colors disabled:opacity-60"
          >
            {guardar.isPending ? 'Guardando...' : esNuevo ? 'Crear Caja' : 'Guardar cambios'}
          </button>
        </div>
      </div>
    </Modal>
  );
}
```

- [ ] **Step 3: Ruteo y menú**

En `frontend/src/router/index.jsx`, agregar el import junto a
`SucursalesPage` (línea 12):

```javascript
import CajasPage from '../pages/cajas/CajasPage';
```

Y la ruta junto a `/sucursales` (línea 38):

```javascript
            { path: '/cajas',            element: <CajasPage /> },
```

En `frontend/src/components/layout/Sidebar.jsx`, agregar `Landmark` al
import de íconos (junto a `Building2`, línea 8) y la entrada de menú
junto a `/sucursales` (línea 24):

```javascript
  { to: '/cajas',        label: 'Cajas',         Icono: Landmark,        modulo: 'cajas',         accion: 'ver' },
```

- [ ] **Step 4: Verificar con build**

Run: `cd frontend && npx vite build`
Expected: build exitoso, sin errores de sintaxis ni de imports.

- [ ] **Step 5: Commit**

```bash
git add frontend/src/api/cajas.js frontend/src/pages/cajas/CajasPage.jsx frontend/src/router/index.jsx frontend/src/components/layout/Sidebar.jsx
git commit -m "feat(cajas): página de catálogo de cajas (crear/editar/eliminar) en el menú"
```

---

### Task 5: Frontend — Rediseño de la pantalla operativa "Caja" (grilla responsiva)

**Files:**
- Modify: `frontend/src/api/caja.js`
- Modify: `frontend/src/pages/caja/CajaPage.jsx`

**Interfaces:**
- Consumes: `GET /caja/estado?sucursal_id=` y `POST /caja/abrir { caja_id, monto_apertura }` (Task 3).

- [ ] **Step 1: Actualizar `frontend/src/api/caja.js`**

Reemplazar `getCajaActiva` por `getEstadoCajas`, y `abrirCaja` para que
reciba `caja_id`:

```javascript
export const getEstadoCajas = (sucursal_id) =>
  api.get('/caja/estado', { params: sucursal_id ? { sucursal_id } : {} }).then(r => r.data.datos).catch(() => []);

export const abrirCaja = (caja_id, monto_apertura) =>
  api.post('/caja/abrir', { caja_id, monto_apertura }).then(r => r.data.datos);
```

El resto del archivo (`getSesiones`, `getSesion`, `cerrarCaja`,
`getReporte`, `registrarGasto`, `getGastos`) no cambia.

- [ ] **Step 2: Reescribir `CajaPage.jsx`**

Reemplazar el contenido completo de
`frontend/src/pages/caja/CajaPage.jsx`:

```jsx
import { useState, useEffect, useCallback } from 'react';
import { useQuery, useQueryClient, useMutation } from '@tanstack/react-query';
import socket from '../../socket';
import {
  Wallet, Plus, X, AlertCircle, RefreshCw, CheckCircle2,
  TrendingUp, TrendingDown, DollarSign, ReceiptText, Clock,
  History, Eye, Loader2, User, Landmark,
} from 'lucide-react';
import {
  getEstadoCajas, getSesiones, getSesion, abrirCaja, cerrarCaja,
  getReporte, registrarGasto, getGastos,
} from '../../api/caja';
import { getSucursales } from '../../api/sucursales';
import { imprimirTicketCierreCaja } from '../../utils/ticketCierreCaja';
import { getConfiguracion } from '../../api/configuracion';
import { usePermisos } from '../../hooks/usePermisos';
import { useAuth } from '../../hooks/useAuth';
import Modal from '../../components/ui/Modal';

const DENOMINACIONES = [200, 100, 50, 20, 10, 5, 2, 1, 0.5, 0.2, 0.1];

function fmtFecha(f) {
  if (!f) return '—';
  return new Date(f).toLocaleDateString('es-BO', { day: '2-digit', month: '2-digit', year: 'numeric' });
}

function fmtHora(f) {
  if (!f) return '—';
  return new Date(f).toLocaleString('es-BO', {
    day: '2-digit', month: '2-digit', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  });
}

function duracion(desde) {
  if (!desde) return '—';
  const diff = Date.now() - new Date(desde).getTime();
  const h = Math.floor(diff / 3600000);
  const m = Math.floor((diff % 3600000) / 60000);
  return h > 0 ? `${h}h ${m}m` : `${m}m`;
}

function diferenciaColor(d) {
  if (Math.abs(d) < 0.01) return 'text-green-600 dark:text-green-400';
  return d > 0 ? 'text-blue-600 dark:text-blue-400' : 'text-red-600 dark:text-red-400';
}

/* ─────────────────────────────────────────────────────── página principal ── */

export default function CajaPage() {
  const { tienePermiso } = usePermisos();
  const { usuario } = useAuth();
  const qc = useQueryClient();

  const puedeVer    = tienePermiso('caja', 'ver');
  const puedeAbrir  = tienePermiso('caja', 'abrir');
  const puedeCerrar = tienePermiso('caja', 'cerrar');

  const accesoTodas = usuario?.sucursal_activa?.id == null;
  const [sucursalId, setSucursalId] = useState('');
  const [sesionSeleccionadaId, setSesionSeleccionadaId] = useState(null);
  const [modalAbrir, setModalAbrir] = useState(null); // null | caja-object
  const [modalCerrar, setModalCerrar] = useState(false);
  const [modalGasto, setModalGasto] = useState(false);
  const [reporteFinal, setReporteFinal] = useState(null);
  const [cargandoDet, setCargandoDet] = useState(null);

  const { data: sucursales = [] } = useQuery({
    queryKey: ['sucursales'],
    queryFn: getSucursales,
    enabled: accesoTodas,
  });

  const sucursalActivaId = accesoTodas ? sucursalId : usuario?.sucursal_activa?.id;

  const { data: cajas = [], isLoading } = useQuery({
    queryKey: ['caja-estado', sucursalActivaId],
    queryFn: () => getEstadoCajas(sucursalActivaId),
    enabled: puedeVer && !!sucursalActivaId,
  });

  const { data: config = {} } = useQuery({
    queryKey: ['configuracion'],
    queryFn: getConfiguracion,
    enabled: puedeVer,
  });

  const { data: sesion } = useQuery({
    queryKey: ['caja-sesion', sesionSeleccionadaId],
    queryFn: () => getSesion(sesionSeleccionadaId),
    enabled: !!sesionSeleccionadaId,
  });

  const { data: gastos = [] } = useQuery({
    queryKey: ['caja-gastos', sesion?.id],
    queryFn: () => getGastos(sesion.id),
    enabled: !!sesion?.id,
  });

  const { data: sesiones = [] } = useQuery({
    queryKey: ['caja-sesiones'],
    queryFn: getSesiones,
    enabled: puedeVer,
  });

  const historial = sesiones.filter(s => s.estado === 'cerrada');

  const verDetalle = async (id) => {
    setCargandoDet(id);
    try {
      const r = await getReporte(id);
      setReporteFinal(r);
    } finally {
      setCargandoDet(null);
    }
  };

  const invalidar = useCallback(() => {
    qc.invalidateQueries({ queryKey: ['caja-estado'] });
    qc.invalidateQueries({ queryKey: ['caja-sesiones'] });
    if (sesionSeleccionadaId) {
      qc.invalidateQueries({ queryKey: ['caja-sesion', sesionSeleccionadaId] });
      qc.invalidateQueries({ queryKey: ['caja-gastos', sesionSeleccionadaId] });
    }
  }, [qc, sesionSeleccionadaId]);

  useEffect(() => {
    socket.on('restaurante:actualizar', invalidar);
    return () => socket.off('restaurante:actualizar', invalidar);
  }, [invalidar]);

  if (!puedeVer) {
    return (
      <div className="flex flex-col items-center justify-center h-64 gap-3 text-gray-400 dark:text-gray-600">
        <AlertCircle className="w-10 h-10" />
        <p className="font-medium">No tienes permiso para ver la caja</p>
      </div>
    );
  }

  const selectorSucursal = accesoTodas && (
    <div className="flex items-center gap-3 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl px-4 py-3">
      <label className="text-sm font-medium text-gray-600 dark:text-gray-300 shrink-0">Sucursal</label>
      <select
        value={sucursalId}
        onChange={e => { setSucursalId(e.target.value); setSesionSeleccionadaId(null); }}
        className="flex-1 bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-lg px-3 py-1.5 text-sm text-gray-800 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500"
      >
        <option value="">Elegí una sucursal...</option>
        {sucursales.map(s => <option key={s.id} value={s.id}>{s.nombre}</option>)}
      </select>
    </div>
  );

  // vista de detalle de una sesión (abierta) seleccionada de la grilla
  if (sesionSeleccionadaId && sesion) {
    return (
      <div className="space-y-6 max-w-5xl">
        <div className="flex items-center gap-3">
          <button
            onClick={() => setSesionSeleccionadaId(null)}
            className="text-sm text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200"
          >
            ← Volver a las cajas
          </button>
        </div>

        <div className="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-2xl p-4 sm:p-5 space-y-4">
          <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3">
            <div className="space-y-1">
              <span className="inline-flex items-center gap-1.5 px-2.5 py-1 bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400 rounded-full text-xs font-semibold">
                <span className="w-1.5 h-1.5 bg-green-500 rounded-full animate-pulse" />
                Caja Abierta
              </span>
              <p className="text-sm text-gray-500 dark:text-gray-400">
                Abierta por{' '}
                <span className="font-medium text-gray-700 dark:text-gray-200">{sesion.usuario?.nombre}</span>
              </p>
              <p className="text-xs text-gray-400 flex items-center gap-1.5">
                <Clock className="w-3.5 h-3.5" />
                {fmtHora(sesion.abierto_en)} · {duracion(sesion.abierto_en)} en curso
              </p>
            </div>
            {puedeCerrar && (
              usuario?.id === sesion.usuario?.id ? (
                <button
                  onClick={() => setModalCerrar(true)}
                  className="self-start sm:self-auto flex items-center gap-2 px-4 py-2 border border-red-200 dark:border-red-900 text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-xl text-sm font-medium transition-colors"
                >
                  <X className="w-4 h-4" /> Cerrar Caja
                </button>
              ) : (
                <div className="self-start sm:self-auto flex items-center gap-2 px-3 py-2 bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-xl text-xs text-amber-700 dark:text-amber-400">
                  <AlertCircle className="w-3.5 h-3.5 shrink-0" />
                  Solo <span className="font-semibold mx-1">{sesion.usuario?.nombre}</span> puede cerrar esta caja
                </div>
              )
            )}
          </div>

          <div className="grid grid-cols-3 gap-2 sm:gap-3">
            <MetricCard label="Apertura" valor={parseFloat(sesion.monto_apertura)} icono={<DollarSign className="w-4 h-4" />} color="blue" />
            <MetricCard label="Ventas"   valor={parseFloat(sesion.total_ventas)}   icono={<TrendingUp  className="w-4 h-4" />} color="green" />
            <MetricCard label="Gastos"   valor={parseFloat(sesion.total_gastos)}   icono={<TrendingDown className="w-4 h-4" />} color="red" />
          </div>

          <div className="flex items-center justify-between bg-blue-50 dark:bg-blue-900/20 rounded-xl px-4 py-3">
            <span className="text-sm font-medium text-blue-700 dark:text-blue-400">Efectivo esperado en caja</span>
            <span className="text-base sm:text-lg font-bold text-blue-700 dark:text-blue-400">
              Bs {(parseFloat(sesion.monto_apertura) + parseFloat(sesion.ventas_efectivo ?? 0) - parseFloat(sesion.total_gastos)).toFixed(2)}
            </span>
          </div>
        </div>

        <div className="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-2xl overflow-hidden">
          <div className="flex items-center justify-between px-4 sm:px-5 py-3 border-b border-gray-100 dark:border-gray-700">
            <span className="font-semibold text-sm text-gray-700 dark:text-gray-200 flex items-center gap-2">
              <ReceiptText className="w-4 h-4" /> Gastos del turno
            </span>
            <button
              onClick={() => setModalGasto(true)}
              className="flex items-center gap-1.5 px-3 py-1.5 bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600 rounded-lg text-xs font-medium text-gray-600 dark:text-gray-300 transition-colors"
            >
              <Plus className="w-3.5 h-3.5" /> Registrar gasto
            </button>
          </div>
          {gastos.length === 0 ? (
            <div className="flex items-center justify-center h-20 text-sm text-gray-400 dark:text-gray-600">
              Sin gastos registrados
            </div>
          ) : (
            <div className="divide-y divide-gray-100 dark:divide-gray-700">
              {gastos.map(g => (
                <div key={g.id} className="flex items-center justify-between px-4 sm:px-5 py-3">
                  <div className="min-w-0 mr-3">
                    <p className="text-sm font-medium text-gray-800 dark:text-gray-100 truncate">{g.descripcion}</p>
                    <p className="text-xs text-gray-400">
                      {fmtHora(g.creado_en)}
                      {g.usuario?.nombre && <> · <span className="text-gray-500 dark:text-gray-400">{g.usuario.nombre}</span></>}
                    </p>
                  </div>
                  <span className="shrink-0 text-sm font-semibold text-red-600 dark:text-red-400">
                    -Bs {parseFloat(g.monto).toFixed(2)}
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>

        {modalCerrar && (
          <ModalCerrarCaja
            sesion={sesion}
            onClose={() => setModalCerrar(false)}
            onExito={(reporte) => {
              setModalCerrar(false);
              invalidar();
              setSesionSeleccionadaId(null);
              setReporteFinal(reporte);
            }}
          />
        )}

        {modalGasto && (
          <ModalGasto
            sesionId={sesion.id}
            onClose={() => setModalGasto(false)}
            onExito={() => {
              setModalGasto(false);
              qc.invalidateQueries({ queryKey: ['caja-sesion', sesion.id] });
              qc.invalidateQueries({ queryKey: ['caja-gastos', sesion.id] });
            }}
          />
        )}

        {reporteFinal && (
          <ModalReporte reporte={reporteFinal} config={config} onClose={() => setReporteFinal(null)} />
        )}
      </div>
    );
  }

  return (
    <div className="space-y-6 max-w-5xl">
      <h1 className="text-xl font-bold text-gray-800 dark:text-gray-100">Caja</h1>
      {selectorSucursal}

      {accesoTodas && !sucursalId ? (
        <div className="flex flex-col items-center justify-center py-16 gap-3 text-gray-400 dark:text-gray-600">
          <Wallet className="w-10 h-10" />
          <p className="text-sm">Elegí una sucursal para ver sus cajas</p>
        </div>
      ) : isLoading ? (
        <div className="flex items-center justify-center h-64 gap-3 text-gray-400">
          <RefreshCw className="w-5 h-5 animate-spin" /><span>Cargando...</span>
        </div>
      ) : cajas.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-16 gap-3 text-gray-400 dark:text-gray-600">
          <Landmark className="w-10 h-10" />
          <p className="text-sm">Esta sucursal todavía no tiene cajas creadas</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {cajas.map(c => (
            <TarjetaCaja
              key={c.id}
              caja={c}
              puedeAbrir={puedeAbrir}
              onAbrir={() => setModalAbrir(c)}
              onVerDetalle={() => setSesionSeleccionadaId(c.sesion_abierta.id)}
            />
          ))}
        </div>
      )}

      {historial.length > 0 && (
        <div className="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-2xl overflow-hidden">
          <div className="px-4 sm:px-5 py-3 border-b border-gray-100 dark:border-gray-700">
            <h2 className="font-semibold text-sm text-gray-700 dark:text-gray-200 flex items-center gap-2">
              <History className="w-4 h-4" /> Historial de cierres
              <span className="ml-1 px-1.5 py-0.5 rounded-full bg-gray-100 dark:bg-gray-700 text-xs font-bold text-gray-500 dark:text-gray-400">
                {historial.length}
              </span>
            </h2>
          </div>

          <div className="divide-y divide-gray-100 dark:divide-gray-700 sm:hidden">
            {historial.map(s => {
              const dif = parseFloat(s.diferencia ?? 0);
              return (
                <div key={s.id} className="px-4 py-3 space-y-2">
                  <div className="flex items-start justify-between gap-2">
                    <div>
                      <p className="text-sm font-semibold text-gray-800 dark:text-gray-100">{fmtFecha(s.abierto_en)}</p>
                      <p className="text-xs text-gray-400 flex items-center gap-1 mt-0.5">
                        <User className="w-3 h-3" /> {s.usuario?.nombre ?? '—'}
                      </p>
                    </div>
                    <span className={`text-sm font-bold ${diferenciaColor(dif)}`}>
                      {dif >= 0 ? '+' : ''}Bs {dif.toFixed(2)}
                    </span>
                  </div>
                  <div className="grid grid-cols-3 gap-2 text-xs text-center">
                    <div className="bg-blue-50 dark:bg-blue-900/20 rounded-lg px-2 py-1.5">
                      <p className="text-blue-500 font-medium mb-0.5">Apertura</p>
                      <p className="font-bold text-blue-700 dark:text-blue-300">Bs {parseFloat(s.monto_apertura).toFixed(2)}</p>
                    </div>
                    <div className="bg-green-50 dark:bg-green-900/20 rounded-lg px-2 py-1.5">
                      <p className="text-green-500 font-medium mb-0.5">Ventas</p>
                      <p className="font-bold text-green-700 dark:text-green-300">Bs {parseFloat(s.total_ventas).toFixed(2)}</p>
                    </div>
                    <div className="bg-gray-50 dark:bg-gray-700/50 rounded-lg px-2 py-1.5">
                      <p className="text-gray-400 font-medium mb-0.5">Cierre</p>
                      <p className="font-bold text-gray-700 dark:text-gray-200">Bs {parseFloat(s.monto_cierre ?? 0).toFixed(2)}</p>
                    </div>
                  </div>
                  <button
                    onClick={() => verDetalle(s.id)}
                    disabled={cargandoDet === s.id}
                    className="w-full flex items-center justify-center gap-1.5 py-1.5 rounded-lg border border-gray-200 dark:border-gray-600 text-xs font-medium text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors disabled:opacity-60"
                  >
                    {cargandoDet === s.id
                      ? <><Loader2 className="w-3.5 h-3.5 animate-spin" /> Cargando...</>
                      : <><Eye className="w-3.5 h-3.5" /> Ver detalle</>
                    }
                  </button>
                </div>
              );
            })}
          </div>

          <div className="hidden sm:block overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="bg-gray-50 dark:bg-gray-700/50">
                  {['Fecha', 'Cajero', 'Apertura', 'Ventas', 'Gastos', 'Diferencia', ''].map(h => (
                    <th
                      key={h}
                      className={`px-4 py-2.5 text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide ${
                        h && h !== 'Fecha' && h !== 'Cajero' ? 'text-right' : 'text-left'
                      }`}
                    >
                      {h}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
                {historial.map(s => {
                  const dif = parseFloat(s.diferencia ?? 0);
                  return (
                    <tr key={s.id} className="hover:bg-gray-50 dark:hover:bg-gray-700/30 transition-colors">
                      <td className="px-4 py-3">
                        <p className="font-medium text-gray-800 dark:text-gray-100">{fmtFecha(s.abierto_en)}</p>
                        <p className="text-xs text-gray-400 mt-0.5">{fmtHora(s.cerrado_en)}</p>
                      </td>
                      <td className="px-4 py-3">
                        <span className="text-gray-700 dark:text-gray-300">{s.usuario?.nombre ?? '—'}</span>
                      </td>
                      <td className="px-4 py-3 text-right text-gray-700 dark:text-gray-300">
                        Bs {parseFloat(s.monto_apertura).toFixed(2)}
                      </td>
                      <td className="px-4 py-3 text-right font-medium text-green-600 dark:text-green-400">
                        Bs {parseFloat(s.total_ventas).toFixed(2)}
                      </td>
                      <td className="px-4 py-3 text-right text-red-500 dark:text-red-400">
                        Bs {parseFloat(s.total_gastos).toFixed(2)}
                      </td>
                      <td className={`px-4 py-3 text-right font-bold ${diferenciaColor(dif)}`}>
                        {dif >= 0 ? '+' : ''}Bs {dif.toFixed(2)}
                      </td>
                      <td className="px-4 py-3 text-right">
                        <button
                          onClick={() => verDetalle(s.id)}
                          disabled={cargandoDet === s.id}
                          className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-gray-200 dark:border-gray-600 text-xs font-medium text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors disabled:opacity-60"
                        >
                          {cargandoDet === s.id
                            ? <Loader2 className="w-3.5 h-3.5 animate-spin" />
                            : <Eye className="w-3.5 h-3.5" />
                          }
                          {cargandoDet === s.id ? 'Cargando' : 'Detalle'}
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {modalAbrir && (
        <ModalAbrirCaja
          caja={modalAbrir}
          onClose={() => setModalAbrir(null)}
          onExito={(sesionCreada) => {
            setModalAbrir(null);
            invalidar();
            setSesionSeleccionadaId(sesionCreada.id);
          }}
        />
      )}

      {reporteFinal && (
        <ModalReporte reporte={reporteFinal} config={config} onClose={() => setReporteFinal(null)} />
      )}
    </div>
  );
}

/* ─── Tarjeta de caja (grilla) ──────────────────────────────────────────── */

function TarjetaCaja({ caja, puedeAbrir, onAbrir, onVerDetalle }) {
  const abierta = !!caja.sesion_abierta;
  return (
    <div className="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-2xl p-4 sm:p-5 flex flex-col gap-3">
      <div className="flex items-center gap-2.5">
        <div className="w-9 h-9 rounded-xl bg-blue-100 dark:bg-blue-900/30 flex items-center justify-center shrink-0">
          <Wallet className="w-4.5 h-4.5 text-blue-600 dark:text-blue-400" />
        </div>
        <span className="font-semibold text-gray-800 dark:text-gray-100">{caja.nombre}</span>
      </div>

      {abierta ? (
        <>
          <div className="space-y-1">
            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400 rounded-full text-xs font-semibold">
              <span className="w-1.5 h-1.5 bg-green-500 rounded-full animate-pulse" />
              Abierta
            </span>
            <p className="text-xs text-gray-500 dark:text-gray-400">
              Por <span className="font-medium text-gray-700 dark:text-gray-200">{caja.sesion_abierta.usuario?.nombre}</span>
            </p>
            <p className="text-xs text-gray-400 flex items-center gap-1.5">
              <Clock className="w-3.5 h-3.5" />
              {duracion(caja.sesion_abierta.abierto_en)} en curso
            </p>
          </div>
          <button
            onClick={onVerDetalle}
            className="flex items-center justify-center gap-2 py-2 rounded-xl border border-gray-200 dark:border-gray-600 text-sm font-medium text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
          >
            <Eye className="w-4 h-4" /> Ver detalle
          </button>
        </>
      ) : (
        <>
          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 bg-gray-100 dark:bg-gray-700 text-gray-500 dark:text-gray-400 rounded-full text-xs font-semibold w-fit">
            Disponible
          </span>
          {puedeAbrir && (
            <button
              onClick={onAbrir}
              className="flex items-center justify-center gap-2 py-2 rounded-xl bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold transition-colors"
            >
              <Plus className="w-4 h-4" /> Abrir
            </button>
          )}
        </>
      )}
    </div>
  );
}

/* ─── Métrica card ──────────────────────────────────────────────────────── */

function MetricCard({ label, valor, icono, color }) {
  const colores = {
    blue:  'bg-blue-50  dark:bg-blue-900/20  text-blue-600  dark:text-blue-400',
    green: 'bg-green-50 dark:bg-green-900/20 text-green-600 dark:text-green-400',
    red:   'bg-red-50   dark:bg-red-900/20   text-red-600   dark:text-red-400',
  };
  return (
    <div className={`rounded-xl p-2.5 sm:p-3 ${colores[color]}`}>
      <div className="flex items-center gap-1 mb-1 opacity-70">
        {icono}
        <span className="text-xs font-medium truncate">{label}</span>
      </div>
      <p className="text-sm sm:text-lg font-bold">Bs {valor.toFixed(2)}</p>
    </div>
  );
}

/* ─── Modal Abrir Caja ──────────────────────────────────────────────────── */

function ModalAbrirCaja({ caja, onClose, onExito }) {
  const [monto, setMonto] = useState('');
  const [error, setError] = useState(null);

  const abrir = useMutation({
    mutationFn: () => abrirCaja(caja.id, parseFloat(monto) || 0),
    onSuccess: onExito,
    onError: (err) => setError(err?.response?.data?.mensaje ?? 'Error al abrir la caja'),
  });

  return (
    <Modal titulo={`Abrir ${caja.nombre}`} onClose={onClose} ancho="max-w-sm">
      <div className="space-y-5">
        <div className="bg-blue-50 dark:bg-blue-900/20 rounded-xl p-4 text-sm text-blue-700 dark:text-blue-300">
          Ingresa el monto en efectivo con el que abres la caja (fondo inicial).
        </div>
        <div>
          <label className="block text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-1.5">
            Monto de apertura (Bs)
          </label>
          <input
            type="number" min="0" step="0.50" autoFocus
            value={monto}
            onChange={e => { setMonto(e.target.value); setError(null); }}
            placeholder="0.00"
            className="w-full bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-gray-800 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500 transition"
          />
        </div>
        {error && <p className="text-sm text-red-600">{error}</p>}
        <div className="flex justify-end gap-3">
          <button onClick={onClose} className="px-4 py-2 rounded-xl text-sm text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors">
            Cancelar
          </button>
          <button
            onClick={() => abrir.mutate()}
            disabled={abrir.isPending}
            className="px-5 py-2 rounded-xl text-sm bg-blue-600 hover:bg-blue-700 text-white font-semibold transition-colors disabled:opacity-60"
          >
            {abrir.isPending ? 'Abriendo...' : 'Abrir Caja'}
          </button>
        </div>
      </div>
    </Modal>
  );
}

/* ─── Modal Cerrar Caja ─────────────────────────────────────────────────── */

function ModalCerrarCaja({ sesion, onClose, onExito }) {
  const [cantidades, setCantidades] = useState(
    Object.fromEntries(DENOMINACIONES.map(d => [d, '']))
  );
  const [error, setError] = useState(null);

  const setCant = (den, val) => setCantidades(c => ({ ...c, [den]: val }));

  const totalFisico = DENOMINACIONES.reduce((sum, d) => {
    return sum + (parseInt(cantidades[d]) || 0) * d;
  }, 0);

  const cerrar = useMutation({
    mutationFn: () => {
      const denominaciones = DENOMINACIONES
        .filter(d => parseInt(cantidades[d]) > 0)
        .map(d => ({ denominacion: d, cantidad: parseInt(cantidades[d]) }));
      return cerrarCaja(sesion.id, denominaciones);
    },
    onSuccess: async () => {
      const reporte = await getReporte(sesion.id);
      onExito(reporte);
    },
    onError: (err) => setError(err?.response?.data?.mensaje ?? 'Error al cerrar la caja'),
  });

  const apertura       = parseFloat(sesion.monto_apertura);
  const ventasTotal    = parseFloat(sesion.total_ventas);
  const ventasEfectivo = parseFloat(sesion.ventas_efectivo ?? ventasTotal);
  const ventasQR       = parseFloat(sesion.ventas_qr ?? 0);
  const gastos         = parseFloat(sesion.total_gastos);
  const esperado       = apertura + ventasEfectivo - gastos;
  const diferencia     = totalFisico - esperado;

  return (
    <Modal titulo="Cerrar Caja — Arqueo" onClose={onClose} ancho="max-w-2xl">
      <div className="space-y-4">

        <div className="grid grid-cols-1 xs:grid-cols-3 sm:grid-cols-3 gap-2">
          <div className="bg-blue-50 dark:bg-blue-900/20 rounded-xl p-3 text-center">
            <p className="text-xs text-blue-600 dark:text-blue-400 font-medium mb-1">Apertura</p>
            <p className="text-base font-bold text-blue-700 dark:text-blue-300">Bs {apertura.toFixed(2)}</p>
          </div>
          <div className="bg-green-50 dark:bg-green-900/20 rounded-xl p-3 text-center">
            <p className="text-xs text-green-600 dark:text-green-400 font-medium mb-1">Ventas total</p>
            <p className="text-base font-bold text-green-700 dark:text-green-300">Bs {ventasTotal.toFixed(2)}</p>
            {ventasQR > 0 && (
              <p className="text-xs text-purple-500 dark:text-purple-400 mt-0.5">QR: Bs {ventasQR.toFixed(2)}</p>
            )}
          </div>
          <div className="bg-red-50 dark:bg-red-900/20 rounded-xl p-3 text-center">
            <p className="text-xs text-red-600 dark:text-red-400 font-medium mb-1">Gastos</p>
            <p className="text-base font-bold text-red-700 dark:text-red-300">Bs {gastos.toFixed(2)}</p>
          </div>
        </div>

        <div>
          <p className="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-3">
            Conteo de efectivo en caja
          </p>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-x-6 gap-y-2">
            {DENOMINACIONES.map(d => {
              const subtotal = (parseInt(cantidades[d]) || 0) * d;
              return (
                <div key={d} className="flex items-center gap-2">
                  <span className="w-14 text-sm font-medium text-gray-700 dark:text-gray-300 text-right shrink-0">
                    Bs {d}
                  </span>
                  <span className="text-gray-400 text-sm">×</span>
                  <input
                    type="number" min="0"
                    value={cantidades[d]}
                    onChange={e => setCant(d, e.target.value)}
                    className="w-16 bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-lg px-2 py-1.5 text-sm text-center text-gray-800 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500 transition"
                  />
                  {subtotal > 0 && (
                    <span className="text-xs text-gray-500 dark:text-gray-400">
                      = Bs {subtotal.toFixed(2)}
                    </span>
                  )}
                </div>
              );
            })}
          </div>
        </div>

        <div className="border-t border-gray-200 dark:border-gray-700 pt-4 space-y-2">
          {ventasQR > 0 && (
            <div className="flex justify-between text-sm text-purple-600 dark:text-purple-400">
              <span>Ventas cobradas por QR (no en caja)</span>
              <span className="font-semibold">Bs {ventasQR.toFixed(2)}</span>
            </div>
          )}
          <div className="flex justify-between text-sm text-gray-600 dark:text-gray-400">
            <span>Efectivo esperado en caja</span>
            <span className="font-semibold">Bs {esperado.toFixed(2)}</span>
          </div>
          <div className="flex justify-between text-sm text-gray-600 dark:text-gray-400">
            <span>Efectivo contado</span>
            <span className="font-semibold">Bs {totalFisico.toFixed(2)}</span>
          </div>
          <div className={`flex justify-between font-bold text-base rounded-xl px-3 py-2 ${
            Math.abs(diferencia) < 0.01
              ? 'bg-green-50 dark:bg-green-900/20 text-green-700 dark:text-green-400'
              : diferencia > 0
              ? 'bg-blue-50 dark:bg-blue-900/20 text-blue-700 dark:text-blue-400'
              : 'bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-400'
          }`}>
            <span>Diferencia</span>
            <span>{diferencia >= 0 ? '+' : ''}Bs {diferencia.toFixed(2)}</span>
          </div>
        </div>

        {totalFisico === 0 && (
          <div className="flex items-center gap-2 px-3 py-2.5 bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-xl text-sm text-amber-700 dark:text-amber-400">
            <AlertCircle className="w-4 h-4 shrink-0" />
            Ingresa el conteo de billetes y monedas antes de cerrar.
          </div>
        )}

        {error && <p className="text-sm text-red-600">{error}</p>}

        <div className="flex justify-end gap-3">
          <button onClick={onClose} className="px-4 py-2 rounded-xl text-sm text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors">
            Cancelar
          </button>
          <button
            onClick={() => cerrar.mutate()}
            disabled={cerrar.isPending || totalFisico === 0}
            className="px-5 py-2 rounded-xl text-sm bg-red-600 hover:bg-red-700 text-white font-semibold transition-colors disabled:opacity-60"
          >
            {cerrar.isPending ? 'Cerrando...' : 'Confirmar cierre'}
          </button>
        </div>
      </div>
    </Modal>
  );
}

/* ─── Modal Gasto ───────────────────────────────────────────────────────── */

function ModalGasto({ sesionId, onClose, onExito }) {
  const [form, setForm] = useState({ descripcion: '', monto: '' });
  const [error, setError] = useState(null);

  const guardar = useMutation({
    mutationFn: () => registrarGasto(sesionId, { descripcion: form.descripcion, monto: parseFloat(form.monto) }),
    onSuccess: onExito,
    onError: (err) => setError(err?.response?.data?.mensaje ?? 'Error al registrar gasto'),
  });

  return (
    <Modal titulo="Registrar Gasto" onClose={onClose} ancho="max-w-sm">
      <div className="space-y-4">
        <div>
          <label className="block text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-1.5">Descripción</label>
          <input
            autoFocus
            value={form.descripcion}
            onChange={e => setForm(f => ({ ...f, descripcion: e.target.value }))}
            placeholder="Ej: Compra de insumos, Gas, etc."
            className="w-full bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-gray-800 dark:text-gray-100 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 transition"
          />
        </div>
        <div>
          <label className="block text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-1.5">Monto (Bs)</label>
          <input
            type="number" min="0.01" step="0.01"
            value={form.monto}
            onChange={e => setForm(f => ({ ...f, monto: e.target.value }))}
            placeholder="0.00"
            className="w-full bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-gray-800 dark:text-gray-100 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 transition"
          />
        </div>
        {error && <p className="text-sm text-red-600">{error}</p>}
        <div className="flex justify-end gap-3 pt-1">
          <button onClick={onClose} className="px-4 py-2 rounded-xl text-sm text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors">
            Cancelar
          </button>
          <button
            onClick={() => guardar.mutate()}
            disabled={guardar.isPending || !form.descripcion.trim() || !form.monto}
            className="px-5 py-2 rounded-xl text-sm bg-blue-600 hover:bg-blue-700 text-white font-semibold transition-colors disabled:opacity-60"
          >
            {guardar.isPending ? 'Guardando...' : 'Registrar'}
          </button>
        </div>
      </div>
    </Modal>
  );
}

/* ─── Modal Reporte Final ───────────────────────────────────────────────── */

function ModalReporte({ reporte, config = {}, onClose }) {
  const { sesion, ventas_por_metodo = [], pedidos = [], efectivo_esperado } = reporte;

  const totalEfectivo = ventas_por_metodo.find(v => v.metodo_pago === 'efectivo');
  const totalQR       = ventas_por_metodo.find(v => v.metodo_pago === 'qr');
  const totalVentas   = parseFloat(sesion.total_ventas);
  const totalGastos   = parseFloat(sesion.total_gastos);
  const apertura      = parseFloat(sesion.monto_apertura);
  const cierre        = parseFloat(sesion.monto_cierre ?? 0);
  const diferencia    = parseFloat(sesion.diferencia ?? 0);

  return (
    <Modal titulo="Reporte de Cierre de Caja" onClose={onClose} ancho="max-w-lg">
      <div className="space-y-4">
        <div className="flex flex-col items-center gap-2 py-2">
          <CheckCircle2 className="w-12 h-12 text-green-500" />
          <p className="font-bold text-gray-800 dark:text-gray-100">Caja cerrada</p>
          <p className="text-xs text-gray-400 text-center">
            {new Date(sesion.abierto_en).toLocaleString('es-BO')}
            {' → '}
            {new Date(sesion.cerrado_en).toLocaleString('es-BO')}
          </p>
        </div>

        <div className="bg-gray-50 dark:bg-gray-700/50 rounded-xl p-4 space-y-2">
          <p className="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-3">Resumen de ventas</p>
          <div className="flex justify-between text-sm text-gray-600 dark:text-gray-300">
            <span>Total pedidos completados</span>
            <span className="font-medium">{pedidos.length}</span>
          </div>
          <div className="flex justify-between text-sm text-gray-600 dark:text-gray-300">
            <span className="flex items-center gap-1.5">
              <span className="w-2 h-2 rounded-full bg-green-500" /> Efectivo
            </span>
            <span className="font-medium">
              Bs {parseFloat(totalEfectivo?.total ?? 0).toFixed(2)}
              <span className="text-xs text-gray-400 ml-1">({totalEfectivo?.cantidad ?? 0} órdenes)</span>
            </span>
          </div>
          <div className="flex justify-between text-sm text-gray-600 dark:text-gray-300">
            <span className="flex items-center gap-1.5">
              <span className="w-2 h-2 rounded-full bg-blue-500" /> QR / Transferencia
            </span>
            <span className="font-medium">
              Bs {parseFloat(totalQR?.total ?? 0).toFixed(2)}
              <span className="text-xs text-gray-400 ml-1">({totalQR?.cantidad ?? 0} órdenes)</span>
            </span>
          </div>
          <div className="border-t border-gray-200 dark:border-gray-600 pt-2 flex justify-between font-bold text-gray-800 dark:text-gray-100">
            <span>Total ventas</span>
            <span>Bs {totalVentas.toFixed(2)}</span>
          </div>
        </div>

        <div className="bg-gray-50 dark:bg-gray-700/50 rounded-xl p-4 space-y-2">
          <p className="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-3">Arqueo de caja</p>
          {[
            { label: 'Monto apertura',    val: `Bs ${apertura.toFixed(2)}`,                      color: '' },
            { label: 'Ventas efectivo',   val: `+Bs ${parseFloat(totalEfectivo?.total ?? 0).toFixed(2)}`, color: 'text-green-600' },
            { label: 'Gastos',            val: `-Bs ${totalGastos.toFixed(2)}`,                   color: 'text-red-600' },
            { label: 'Esperado en caja',  val: `Bs ${efectivo_esperado.toFixed(2)}`,              color: '' },
            { label: 'Contado físicamente', val: `Bs ${cierre.toFixed(2)}`,                       color: '' },
          ].map(({ label, val, color }) => (
            <div key={label} className="flex justify-between text-sm text-gray-600 dark:text-gray-300">
              <span>{label}</span>
              <span className={`font-medium ${color}`}>{val}</span>
            </div>
          ))}
          <div className={`flex justify-between font-bold text-base border-t border-gray-200 dark:border-gray-600 pt-2 ${diferenciaColor(diferencia)}`}>
            <span>Diferencia</span>
            <span>{diferencia >= 0 ? '+' : ''}Bs {diferencia.toFixed(2)}</span>
          </div>
        </div>

        {pedidos.length > 0 && (
          <div>
            <p className="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-2">
              Pedidos del turno ({pedidos.length})
            </p>
            <div className="max-h-48 overflow-y-auto space-y-1.5 pr-1">
              {pedidos.map(p => (
                <div key={p.id} className="flex items-center justify-between text-sm bg-gray-50 dark:bg-gray-700/50 rounded-lg px-3 py-2">
                  <span className="text-gray-600 dark:text-gray-300">
                    #{p.id} · {p.mesa?.nombre ?? 'Mesa'}
                  </span>
                  <div className="flex items-center gap-2">
                    <span className={`text-xs px-1.5 py-0.5 rounded font-medium ${
                      p.metodo_pago === 'efectivo'
                        ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400'
                        : 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400'
                    }`}>{p.metodo_pago}</span>
                    <span className="font-semibold text-gray-800 dark:text-gray-100">Bs {parseFloat(p.total).toFixed(2)}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        <div className="flex gap-3">
          <button
            onClick={() => imprimirTicketCierreCaja(reporte, config)}
            className="flex-1 py-2.5 border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-200 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-xl text-sm font-semibold transition-colors flex items-center justify-center gap-2"
          >
            🖨 Imprimir resumen
          </button>
          <button
            onClick={onClose}
            className="flex-1 py-2.5 bg-blue-600 hover:bg-blue-700 text-white rounded-xl text-sm font-semibold transition-colors"
          >
            Cerrar reporte
          </button>
        </div>
      </div>
    </Modal>
  );
}
```

(Se agrega `getSesion` al import de `../../api/caja` — ya existe esa
función en el archivo, sin cambios de firma. `ModalAbrirCaja` ahora
recibe la `caja` completa en vez de un `sucursalId` suelto — al tener
éxito, `svc.abrir` devuelve la sesión creada con su `id`, que se usa
para navegar directo a la vista de detalle sin recargar la grilla.)

- [ ] **Step 3: Verificar con build**

Run: `cd frontend && npx vite build`
Expected: build exitoso, sin errores de sintaxis ni de imports.

Verificación manual (no hay test runner de frontend): trazar que
- la grilla usa `grid-cols-1 sm:grid-cols-2 lg:grid-cols-3` (responsiva);
- para un usuario de una sola sucursal, `sucursalActivaId` resuelve
  directo a `usuario.sucursal_activa.id` sin selector visible;
- `ModalAbrirCaja` manda `caja_id` fijo (el de la tarjeta clickeada), no
  pide elegir sucursal.

- [ ] **Step 4: Commit**

```bash
git add frontend/src/api/caja.js frontend/src/pages/caja/CajaPage.jsx
git commit -m "feat(caja): grilla responsiva de cajas por sucursal en vez de una sola sesión activa"
```
