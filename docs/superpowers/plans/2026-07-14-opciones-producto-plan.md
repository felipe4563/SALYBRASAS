# Opciones/variantes por producto — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permitir que ciertos productos (ej. carnes con término de cocción, jugos con sabor) muestren un selector de opciones al agregarlos al pedido en Ventas, sin afectar al resto de productos.

**Architecture:** Dos tablas nuevas (`grupos_opciones`, `opciones`) + una columna nullable `productos.grupo_opciones_id`. La opción elegida se guarda como texto plano en el campo `nota` que ya existe en `detalle_pedidos` — no se toca el esquema de pedidos ni el ticket de cocina. El CRUD de grupos de opciones vive dentro del módulo `productos` existente (mismo patrón que `categorias`) y reutiliza el permiso `productos`.

**Tech Stack:** Node/Express/Sequelize/MySQL (backend), React/Vite + TanStack Query (frontend), Jest+Supertest contra la base de datos real de desarrollo (sin mocks).

## Global Constraints

- Un producto tiene **como máximo un** grupo de opciones asignado (no combinaciones de varios grupos).
- Elegir una opción es **opcional**: el mozo puede agregar el producto sin elegir ninguna.
- Ninguna opción cambia el **precio** del producto.
- La opción elegida se guarda en el campo `nota` ya existente de `detalle_pedidos` — **no se agrega columna nueva** ahí.
- La administración de grupos de opciones reutiliza el permiso `productos` (`ver`/`crear`/`editar`/`eliminar`) — no se crea un módulo de permisos nuevo.
- Productos sin grupo de opciones asignado deben comportarse **exactamente igual que hoy** en Ventas (un toque = se agrega directo, sin modal).
- Spec completo en `docs/superpowers/specs/2026-07-14-opciones-producto-design.md`.

---

### Task 1: Migración y modelos (`GrupoOpciones`, `Opcion`, `Producto.grupo_opciones_id`)

**Files:**
- Create: `backend/database/migrations/017_opciones_producto.sql`
- Create: `backend/src/models/GrupoOpciones.js`
- Create: `backend/src/models/Opcion.js`
- Modify: `backend/src/models/Producto.js`
- Modify: `backend/src/models/index.js`
- Test: `backend/tests/opciones.model.test.js`

**Interfaces:**
- Produces: `GrupoOpciones` (tabla `grupos_opciones`, campos `id`, `nombre`) y `Opcion` (tabla `opciones`, campos `id`, `grupo_opciones_id`, `nombre`, `orden`), exportados desde `backend/src/models/index.js` junto al resto. Asociaciones: `GrupoOpciones.hasMany(Opcion, { as: 'opciones' })`, `Opcion.belongsTo(GrupoOpciones, { as: 'grupo' })`, `Producto.belongsTo(GrupoOpciones, { as: 'grupo_opciones' })`, `GrupoOpciones.hasMany(Producto, { as: 'productos' })`. `Producto` gana el campo `grupo_opciones_id` (nullable).

- [ ] **Step 1: Escribir la migración**

`backend/database/migrations/017_opciones_producto.sql`:

```sql
CREATE TABLE IF NOT EXISTS grupos_opciones (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS opciones (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  grupo_opciones_id INT UNSIGNED NOT NULL,
  nombre VARCHAR(100) NOT NULL,
  orden INT NOT NULL DEFAULT 0,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (grupo_opciones_id) REFERENCES grupos_opciones(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE productos
  ADD COLUMN grupo_opciones_id INT UNSIGNED NULL AFTER categoria_id,
  ADD FOREIGN KEY (grupo_opciones_id) REFERENCES grupos_opciones(id) ON DELETE SET NULL;
```

- [ ] **Step 2: Aplicar la migración a la base de datos local**

`backend/.env` tiene `DB_NAME=bd_restaurante`, `DB_USER=root`, `DB_PASS=` (vacío):

```bash
cd backend
mysql -u root bd_restaurante < database/migrations/017_opciones_producto.sql
```

Verificar que no haya errores. Si el `ALTER TABLE productos` fallara por `sql_mode` (ya pasó antes con columnas de fecha en `sesiones_caja`), no debería ocurrir aquí porque `grupo_opciones_id` es `NULL` por defecto — no hace falta relajar `sql_mode`.

- [ ] **Step 3: Crear el modelo `GrupoOpciones`**

`backend/src/models/GrupoOpciones.js`:

```javascript
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const GrupoOpciones = sequelize.define('GrupoOpciones', {
  id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
  nombre: { type: DataTypes.STRING(100), allowNull: false },
}, {
  tableName: 'grupos_opciones',
  createdAt: 'creado_en',
  updatedAt: 'actualizado_en',
});

module.exports = GrupoOpciones;
```

- [ ] **Step 4: Crear el modelo `Opcion`**

`backend/src/models/Opcion.js`:

```javascript
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Opcion = sequelize.define('Opcion', {
  id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
  grupo_opciones_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
  nombre: { type: DataTypes.STRING(100), allowNull: false },
  orden: { type: DataTypes.INTEGER, defaultValue: 0 },
}, {
  tableName: 'opciones',
  createdAt: 'creado_en',
  updatedAt: 'actualizado_en',
});

module.exports = Opcion;
```

- [ ] **Step 5: Agregar `grupo_opciones_id` al modelo `Producto`**

En `backend/src/models/Producto.js`, agregar el campo justo después de `categoria_id`:

```javascript
  categoria_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
  grupo_opciones_id: { type: DataTypes.INTEGER.UNSIGNED },
```

- [ ] **Step 6: Registrar modelos y asociaciones en `index.js`**

En `backend/src/models/index.js`, agregar los requires junto a los demás (después de `const Producto = require('./Producto');`):

```javascript
const GrupoOpciones = require('./GrupoOpciones');
const Opcion = require('./Opcion');
```

Agregar las asociaciones junto al bloque `// Productos` existente:

```javascript
// Productos
Producto.belongsTo(Categoria, { foreignKey: 'categoria_id', as: 'categoria' });
Categoria.hasMany(Producto, { foreignKey: 'categoria_id', as: 'productos' });

// Opciones de producto
GrupoOpciones.hasMany(Opcion, { foreignKey: 'grupo_opciones_id', as: 'opciones' });
Opcion.belongsTo(GrupoOpciones, { foreignKey: 'grupo_opciones_id', as: 'grupo' });
Producto.belongsTo(GrupoOpciones, { foreignKey: 'grupo_opciones_id', as: 'grupo_opciones' });
GrupoOpciones.hasMany(Producto, { foreignKey: 'grupo_opciones_id', as: 'productos' });
```

Agregar ambos modelos al `module.exports` final:

```javascript
module.exports = {
  sequelize,
  Rol, Permiso, Usuario,
  Area, Mesa,
  Categoria, Producto,
  GrupoOpciones, Opcion,
  Cliente,
  ...
```

- [ ] **Step 7: Escribir el test de modelos**

`backend/tests/opciones.model.test.js`:

```javascript
const { GrupoOpciones, Opcion, Producto, Categoria } = require('../src/models');

describe('Modelos GrupoOpciones y Opcion', () => {
  let categoriaId;

  beforeAll(async () => {
    const cat = await Categoria.create({ nombre: 'Categoria Opciones Model Test' });
    categoriaId = cat.id;
  });

  afterAll(async () => {
    await Producto.destroy({ where: { categoria_id: categoriaId } });
    await Categoria.destroy({ where: { id: categoriaId } });
  });

  it('crea un grupo de opciones con sus opciones asociadas', async () => {
    const grupo = await GrupoOpciones.create({ nombre: 'Término de cocción Model Test' });
    await Opcion.bulkCreate([
      { grupo_opciones_id: grupo.id, nombre: 'Jugoso', orden: 1 },
      { grupo_opciones_id: grupo.id, nombre: 'Término medio', orden: 2 },
    ]);

    const recargado = await GrupoOpciones.findByPk(grupo.id, { include: [{ model: Opcion, as: 'opciones' }] });
    expect(recargado.opciones).toHaveLength(2);

    await Opcion.destroy({ where: { grupo_opciones_id: grupo.id } });
    await grupo.destroy();
  });

  it('un producto puede asignarse a un grupo de opciones, y al borrar el grupo queda sin asignar', async () => {
    const grupo = await GrupoOpciones.create({ nombre: 'Sabor Model Test' });
    const producto = await Producto.create({ categoria_id: categoriaId, nombre: 'Jugo Model Test', precio: 10, grupo_opciones_id: grupo.id });

    const recargado = await Producto.findByPk(producto.id, { include: [{ model: GrupoOpciones, as: 'grupo_opciones' }] });
    expect(recargado.grupo_opciones.nombre).toBe('Sabor Model Test');

    await grupo.destroy(); // ON DELETE SET NULL — no debe fallar por el producto asignado
    const productoRecargado = await Producto.findByPk(producto.id);
    expect(productoRecargado.grupo_opciones_id).toBeNull();
  });
});
```

- [ ] **Step 8: Correr el test**

```bash
cd backend
npx jest tests/opciones.model.test.js
```

Expected: 2 passed.

- [ ] **Step 9: Commit**

```bash
git add backend/database/migrations/017_opciones_producto.sql backend/src/models/GrupoOpciones.js backend/src/models/Opcion.js backend/src/models/Producto.js backend/src/models/index.js backend/tests/opciones.model.test.js
git commit -m "feat(productos): modelo de grupos de opciones y opciones por producto"
```

---

### Task 2: CRUD de grupos de opciones (`/api/v1/grupos-opciones`)

**Files:**
- Create: `backend/src/modules/productos/grupos-opciones.routes.js`
- Modify: `backend/src/modules/productos/productos.service.js`
- Modify: `backend/src/modules/productos/productos.controller.js`
- Modify: `backend/src/app.js`
- Test: `backend/tests/grupos-opciones.test.js`

**Interfaces:**
- Consumes: `GrupoOpciones`, `Opcion` de Task 1.
- Produces: `svc.listarGruposOpciones()`, `svc.crearGrupoOpciones({ nombre, opciones })`, `svc.actualizarGrupoOpciones(id, { nombre, opciones })`, `svc.eliminarGrupoOpciones(id)` en `productos.service.js`, usadas por `ctrl.listarGruposOpciones/crearGrupoOpciones/actualizarGrupoOpciones/eliminarGrupoOpciones` montados en `GET/POST /api/v1/grupos-opciones`, `PUT/DELETE /api/v1/grupos-opciones/:id`.

- [ ] **Step 1: Agregar funciones de servicio**

En `backend/src/modules/productos/productos.service.js`, agregar `GrupoOpciones, Opcion` al require existente:

```javascript
const { Categoria, Producto, Sucursal, GrupoOpciones, Opcion } = require('../../models');
```

Agregar, después del bloque `// --- Categorías ---` y antes de `// --- Productos ---`:

```javascript
// --- Grupos de opciones ---

async function listarGruposOpciones() {
  return GrupoOpciones.findAll({
    include: [{ model: Opcion, as: 'opciones', attributes: ['id', 'nombre', 'orden'] }],
    order: [['nombre', 'ASC'], [{ model: Opcion, as: 'opciones' }, 'orden', 'ASC']],
  });
}

async function _conOpciones(id, transaction) {
  return GrupoOpciones.findByPk(id, {
    include: [{ model: Opcion, as: 'opciones', attributes: ['id', 'nombre', 'orden'] }],
    order: [[{ model: Opcion, as: 'opciones' }, 'orden', 'ASC']],
    transaction,
  });
}

async function crearGrupoOpciones({ nombre, opciones = [] }) {
  return sequelize.transaction(async (t) => {
    const grupo = await GrupoOpciones.create({ nombre }, { transaction: t });
    if (opciones.length) {
      await Opcion.bulkCreate(
        opciones.map((o, i) => ({ grupo_opciones_id: grupo.id, nombre: o.nombre, orden: o.orden ?? i })),
        { transaction: t }
      );
    }
    return _conOpciones(grupo.id, t);
  });
}

async function actualizarGrupoOpciones(id, { nombre, opciones = [] }) {
  return sequelize.transaction(async (t) => {
    const grupo = await GrupoOpciones.findByPk(id, { transaction: t });
    if (!grupo) throw Object.assign(new Error('Grupo de opciones no encontrado'), { status: 404 });
    await grupo.update({ nombre }, { transaction: t });
    await Opcion.destroy({ where: { grupo_opciones_id: id }, transaction: t });
    if (opciones.length) {
      await Opcion.bulkCreate(
        opciones.map((o, i) => ({ grupo_opciones_id: id, nombre: o.nombre, orden: o.orden ?? i })),
        { transaction: t }
      );
    }
    return _conOpciones(id, t);
  });
}

async function eliminarGrupoOpciones(id) {
  const grupo = await GrupoOpciones.findByPk(id);
  if (!grupo) throw Object.assign(new Error('Grupo de opciones no encontrado'), { status: 404 });
  await Producto.update({ grupo_opciones_id: null }, { where: { grupo_opciones_id: id } });
  await grupo.destroy();
}
```

Agregar las 4 funciones al `module.exports` final del archivo.

- [ ] **Step 2: Agregar handlers de controller**

En `backend/src/modules/productos/productos.controller.js`, agregar después de `eliminarCategoria`:

```javascript
async function listarGruposOpciones(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listarGruposOpciones() }); }
  catch (err) { next(err); }
}

async function crearGrupoOpciones(req, res, next) {
  try {
    if (!req.body.nombre) return res.status(400).json({ ok: false, mensaje: 'nombre es requerido' });
    res.status(201).json({ ok: true, datos: await svc.crearGrupoOpciones(req.body) });
  } catch (err) { next(err); }
}

async function actualizarGrupoOpciones(req, res, next) {
  try { res.json({ ok: true, datos: await svc.actualizarGrupoOpciones(req.params.id, req.body) }); }
  catch (err) { next(err); }
}

async function eliminarGrupoOpciones(req, res, next) {
  try { await svc.eliminarGrupoOpciones(req.params.id); res.json({ ok: true, datos: null }); }
  catch (err) { next(err); }
}
```

Agregar las 4 funciones al `module.exports` final del archivo.

- [ ] **Step 3: Crear el archivo de rutas**

`backend/src/modules/productos/grupos-opciones.routes.js`:

```javascript
const { Router } = require('express');
const ctrl = require('./productos.controller');
const auth = require('../../middlewares/auth');
const { verificarPermiso } = require('../../middlewares/permisos');

const router = Router();
router.use(auth);

router.get('/', verificarPermiso('productos', 'ver'), ctrl.listarGruposOpciones);
router.post('/', verificarPermiso('productos', 'crear'), ctrl.crearGrupoOpciones);
router.put('/:id', verificarPermiso('productos', 'editar'), ctrl.actualizarGrupoOpciones);
router.delete('/:id', verificarPermiso('productos', 'eliminar'), ctrl.eliminarGrupoOpciones);

module.exports = router;
```

- [ ] **Step 4: Montar la ruta en `app.js`**

Agregar el require junto a `categoriasRoutes`:

```javascript
const gruposOpcionesRoutes = require('./modules/productos/grupos-opciones.routes');
```

Agregar el `app.use` junto a `/api/v1/categorias`:

```javascript
app.use('/api/v1/grupos-opciones', gruposOpcionesRoutes);
```

- [ ] **Step 5: Escribir los tests**

`backend/tests/grupos-opciones.test.js`:

```javascript
const request = require('supertest');
const app = require('../src/app');
const { GrupoOpciones, Opcion, Producto, Categoria } = require('../src/models');

describe('Grupos de opciones API', () => {
  let adminToken;

  beforeAll(async () => {
    const login = await request(app).post('/api/v1/auth/login').send({ email: 'admin@restaurante.com', contrasena: process.env.ADMIN_PASSWORD || 'admin123' });
    adminToken = login.body.datos.token;
  });

  it('GET /api/v1/grupos-opciones sin token → 401', async () => {
    const res = await request(app).get('/api/v1/grupos-opciones');
    expect(res.status).toBe(401);
  });

  it('crea un grupo con sus opciones', async () => {
    const res = await request(app)
      .post('/api/v1/grupos-opciones')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ nombre: 'Término de cocción Test', opciones: [{ nombre: 'Jugoso', orden: 1 }, { nombre: 'Término medio', orden: 2 }] });

    expect(res.status).toBe(201);
    expect(res.body.datos.opciones.map(o => o.nombre)).toEqual(['Jugoso', 'Término medio']);

    await Opcion.destroy({ where: { grupo_opciones_id: res.body.datos.id } });
    await GrupoOpciones.destroy({ where: { id: res.body.datos.id } });
  });

  it('rechaza crear sin nombre', async () => {
    const res = await request(app)
      .post('/api/v1/grupos-opciones')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ opciones: [] });
    expect(res.status).toBe(400);
  });

  it('editar reemplaza por completo la lista de opciones', async () => {
    const crear = await request(app)
      .post('/api/v1/grupos-opciones')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ nombre: 'Sabor Test', opciones: [{ nombre: 'Copoazú', orden: 1 }] });
    const id = crear.body.datos.id;

    const editar = await request(app)
      .put(`/api/v1/grupos-opciones/${id}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ nombre: 'Sabor Test', opciones: [{ nombre: 'Limonada', orden: 1 }, { nombre: 'Maracuyá', orden: 2 }] });

    expect(editar.status).toBe(200);
    expect(editar.body.datos.opciones.map(o => o.nombre)).toEqual(['Limonada', 'Maracuyá']);

    await Opcion.destroy({ where: { grupo_opciones_id: id } });
    await GrupoOpciones.destroy({ where: { id } });
  });

  it('eliminar un grupo asignado a un producto lo desasigna en vez de fallar', async () => {
    const categoria = await Categoria.create({ nombre: 'Categoria Grupos Opciones Test' });
    const crear = await request(app)
      .post('/api/v1/grupos-opciones')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ nombre: 'Grupo A Eliminar Test', opciones: [{ nombre: 'Opción 1', orden: 1 }] });
    const grupoId = crear.body.datos.id;

    const producto = await Producto.create({ categoria_id: categoria.id, nombre: 'Producto Con Grupo Test', precio: 10, grupo_opciones_id: grupoId });

    const eliminar = await request(app)
      .delete(`/api/v1/grupos-opciones/${grupoId}`)
      .set('Authorization', `Bearer ${adminToken}`);
    expect(eliminar.status).toBe(200);

    const productoRecargado = await Producto.findByPk(producto.id);
    expect(productoRecargado.grupo_opciones_id).toBeNull();

    await producto.destroy();
    await categoria.destroy();
  });
});
```

- [ ] **Step 6: Correr los tests**

```bash
cd backend
npx jest tests/grupos-opciones.test.js
```

Expected: 5 passed.

- [ ] **Step 7: Commit**

```bash
git add backend/src/modules/productos/grupos-opciones.routes.js backend/src/modules/productos/productos.service.js backend/src/modules/productos/productos.controller.js backend/src/app.js backend/tests/grupos-opciones.test.js
git commit -m "feat(productos): CRUD de grupos de opciones"
```

---

### Task 3: Extender `productos` para incluir/aceptar `grupo_opciones_id`

**Files:**
- Modify: `backend/src/modules/productos/productos.service.js`
- Modify: `backend/tests/productos.test.js`

**Interfaces:**
- Consumes: `GrupoOpciones`, `Opcion` de Task 1.
- Produces: `GET /productos` y `GET /productos/:id` devuelven `grupo_opciones: { id, nombre, opciones: [...] } | null`. `POST /productos` acepta `grupo_opciones_id` (nullable). `PUT /productos/:id` ya lo acepta sin cambios (usa spread de `resto`).

- [ ] **Step 1: Incluir `grupo_opciones` en los listados**

En `productos.service.js`, cambiar el `include` de `listarProductos`:

```javascript
  const productos = await Producto.findAll({
    where,
    include: [
      { model: Categoria, as: 'categoria', attributes: ['id', 'nombre'] },
      { model: GrupoOpciones, as: 'grupo_opciones', attributes: ['id', 'nombre'],
        include: [{ model: Opcion, as: 'opciones', attributes: ['id', 'nombre', 'orden'] }] },
    ],
    order,
  });
```

Y el de `obtenerProducto`:

```javascript
  const p = await Producto.findByPk(id, {
    include: [
      { model: Categoria, as: 'categoria', attributes: ['id', 'nombre'] },
      { model: GrupoOpciones, as: 'grupo_opciones', attributes: ['id', 'nombre'],
        include: [{ model: Opcion, as: 'opciones', attributes: ['id', 'nombre', 'orden'] }] },
    ],
  });
```

- [ ] **Step 2: Aceptar `grupo_opciones_id` al crear**

En `crearProducto`, agregar `grupo_opciones_id` a la desestructuración y al `Producto.create`:

```javascript
async function crearProducto({ categoria_id, nombre, codigo_barras, codigo, precio, costo, stock, sucursal_id, es_vendible, imagen, grupo_opciones_id }, alcance) {
  ...
  const producto = await Producto.create({ categoria_id, nombre, codigo_barras, codigo, precio, costo, stock: conStock ? 0 : null, es_vendible, imagen, grupo_opciones_id });
  ...
```

(`actualizarProducto` no necesita cambios: ya hace `const { stock, ...resto } = datos; await p.update(resto);`, y `resto` incluye `grupo_opciones_id` automáticamente si viene en el body.)

- [ ] **Step 3: Escribir los tests**

En `backend/tests/productos.test.js`, agregar `GrupoOpciones, Opcion` al require existente de modelos:

```javascript
const { Sucursal, ProductoStockSucursal, Categoria, Usuario, Rol, Producto, GrupoOpciones, Opcion } = require('../src/models');
```

Agregar, al final del archivo:

```javascript
describe('Productos — grupo de opciones', () => {
  let categoriaId, grupoId, adminToken;

  beforeAll(async () => {
    const login = await request(app).post('/api/v1/auth/login').send({ email: 'admin@restaurante.com', contrasena: process.env.ADMIN_PASSWORD || 'admin123' });
    adminToken = login.body.datos.token;

    const categoria = await Categoria.create({ nombre: 'Categoria Grupo Opciones Productos Test' });
    categoriaId = categoria.id;

    const grupo = await GrupoOpciones.create({ nombre: 'Término Productos Test' });
    await Opcion.create({ grupo_opciones_id: grupo.id, nombre: 'Jugoso', orden: 1 });
    grupoId = grupo.id;
  });

  afterAll(async () => {
    await Producto.destroy({ where: { categoria_id: categoriaId } });
    await Categoria.destroy({ where: { id: categoriaId } });
    await Opcion.destroy({ where: { grupo_opciones_id: grupoId } });
    await GrupoOpciones.destroy({ where: { id: grupoId } });
  });

  it('crea un producto con grupo_opciones_id y lo devuelve con sus opciones', async () => {
    const crear = await request(app)
      .post('/api/v1/productos')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ categoria_id: categoriaId, nombre: 'Picaña Test', precio: 85, grupo_opciones_id: grupoId });

    expect(crear.status).toBe(201);
    expect(crear.body.datos.grupo_opciones.nombre).toBe('Término Productos Test');
    expect(crear.body.datos.grupo_opciones.opciones.map(o => o.nombre)).toEqual(['Jugoso']);
  });

  it('GET /productos incluye grupo_opciones cuando está asignado', async () => {
    const res = await request(app).get('/api/v1/productos').set('Authorization', `Bearer ${adminToken}`);
    const creado = res.body.datos.find(p => p.nombre === 'Picaña Test');
    expect(creado.grupo_opciones.id).toBe(grupoId);
  });

  it('un producto sin grupo asignado devuelve grupo_opciones null', async () => {
    const crear = await request(app)
      .post('/api/v1/productos')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ categoria_id: categoriaId, nombre: 'Producto Sin Grupo Test', precio: 20 });

    expect(crear.body.datos.grupo_opciones).toBeNull();
  });
});
```

- [ ] **Step 4: Correr los tests**

```bash
cd backend
npx jest tests/productos.test.js
```

Expected: todos pasan (los previos + los 3 nuevos).

- [ ] **Step 5: Commit**

```bash
git add backend/src/modules/productos/productos.service.js backend/tests/productos.test.js
git commit -m "feat(productos): incluir y aceptar grupo_opciones_id en el CRUD de productos"
```

---

### Task 4: Administración — pestaña "Opciones" y selector en el formulario de producto

**Files:**
- Create: `frontend/src/api/gruposOpciones.js`
- Modify: `frontend/src/pages/productos/ProductosPage.jsx`

**Interfaces:**
- Consumes: `GET/POST /grupos-opciones`, `PUT/DELETE /grupos-opciones/:id` de Task 2; `grupo_opciones` en la respuesta de `GET /productos` de Task 3.
- Produces: `getGruposOpciones`, `crearGrupoOpciones`, `actualizarGrupoOpciones`, `eliminarGrupoOpciones` en `frontend/src/api/gruposOpciones.js`, usadas por la nueva pestaña "Opciones" y por el selector "Grupo de opciones" en `FormProductoModal`.

- [ ] **Step 1: Cliente API**

`frontend/src/api/gruposOpciones.js`:

```javascript
import api from './cliente';

export const getGruposOpciones = () => api.get('/grupos-opciones').then(r => r.data.datos);
export const crearGrupoOpciones = (datos) => api.post('/grupos-opciones', datos).then(r => r.data.datos);
export const actualizarGrupoOpciones = (id, datos) => api.put(`/grupos-opciones/${id}`, datos).then(r => r.data.datos);
export const eliminarGrupoOpciones = (id) => api.delete(`/grupos-opciones/${id}`).then(r => r.data.datos);
```

- [ ] **Step 2: Importar API y agregar la pestaña "Opciones"**

En `frontend/src/pages/productos/ProductosPage.jsx`:

Cambiar el import de iconos (agregar `ListChecks, ChevronUp, ChevronDown`):

```javascript
import { Plus, Pencil, Trash2, Package, Tag, ListChecks, ChevronUp, ChevronDown, AlertCircle, RefreshCw, ImagePlus, X } from 'lucide-react';
```

Agregar el import de la nueva API junto a los de categorías/productos:

```javascript
import { getGruposOpciones, crearGrupoOpciones, actualizarGrupoOpciones, eliminarGrupoOpciones } from '../../api/gruposOpciones';
```

Agregar la pestaña al arreglo `TABS`:

```javascript
const TABS = [
  { id: 'categorias', label: 'Categorías', Icono: Tag },
  { id: 'productos',  label: 'Productos',  Icono: Package },
  { id: 'opciones',   label: 'Opciones',   Icono: ListChecks },
];
```

Agregar el render condicional junto a los otros dos:

```javascript
{tab === 'opciones' && <TabOpciones puedeCrear={puedeCrear} puedeEditar={puedeEditar} puedeEliminar={puedeEliminar} />}
```

- [ ] **Step 3: Componente `TabOpciones` y `FormGrupoOpcionesModal`**

Agregar al final del archivo (después de `FormProductoModal`):

```javascript
/* ─── Tab Opciones ───────────────────────────────────────────────────────── */

function TabOpciones({ puedeCrear, puedeEditar, puedeEliminar }) {
  const qc = useQueryClient();
  const [modal, setModal] = useState(null);
  const [confirmEliminar, setConfirmEliminar] = useState(null);

  const { data: grupos = [], isLoading } = useQuery({ queryKey: ['grupos-opciones'], queryFn: getGruposOpciones });

  const guardar = useMutation({
    mutationFn: ({ grupo, datos }) => grupo ? actualizarGrupoOpciones(grupo.id, datos) : crearGrupoOpciones(datos),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['grupos-opciones'] }); setModal(null); },
  });

  const eliminar = useMutation({
    mutationFn: (id) => eliminarGrupoOpciones(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['grupos-opciones'] });
      qc.invalidateQueries({ queryKey: ['productos'] });
      setConfirmEliminar(null);
    },
  });

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <p className="text-sm text-gray-500 dark:text-gray-400">{grupos.length} grupo(s) de opciones</p>
        {puedeCrear && (
          <button
            onClick={() => setModal({ modo: 'crear' })}
            className="flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-xl text-sm font-medium transition-colors"
          >
            <Plus className="w-4 h-4" /> Nuevo Grupo
          </button>
        )}
      </div>

      {isLoading && (
        <div className="flex items-center gap-2 text-gray-400">
          <RefreshCw className="w-4 h-4 animate-spin" /><span className="text-sm">Cargando...</span>
        </div>
      )}

      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-3">
        {grupos.map(grupo => (
          <div key={grupo.id} className="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl p-4">
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0">
                <p className="font-semibold text-gray-800 dark:text-gray-100 truncate">{grupo.nombre}</p>
                <p className="text-xs text-gray-400 mt-1">
                  {grupo.opciones.map(o => o.nombre).join(' · ') || 'Sin opciones'}
                </p>
              </div>
              <div className="flex gap-1 shrink-0">
                {puedeEditar && (
                  <button onClick={() => setModal({ modo: 'editar', grupo })} className="p-1.5 rounded-lg text-gray-400 hover:text-blue-600 hover:bg-blue-50 dark:hover:bg-blue-900/20 transition-colors">
                    <Pencil className="w-3.5 h-3.5" />
                  </button>
                )}
                {puedeEliminar && (
                  <button onClick={() => setConfirmEliminar(grupo)} className="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors">
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                )}
              </div>
            </div>
          </div>
        ))}
      </div>

      {!isLoading && grupos.length === 0 && (
        <div className="flex flex-col items-center justify-center h-40 gap-2 text-gray-400 dark:text-gray-600">
          <ListChecks className="w-8 h-8" />
          <p className="text-sm">No hay grupos de opciones. Crea el primero.</p>
        </div>
      )}

      {modal && (
        <FormGrupoOpcionesModal
          grupo={modal.grupo}
          onClose={() => setModal(null)}
          onGuardar={(datos) => guardar.mutate({ grupo: modal.grupo, datos })}
          guardando={guardar.isPending}
          error={guardar.error?.response?.data?.mensaje}
        />
      )}

      {confirmEliminar && (
        <Modal titulo="Eliminar Grupo de Opciones" onClose={() => setConfirmEliminar(null)}>
          <p className="text-sm text-gray-600 dark:text-gray-300 mb-4">
            ¿Eliminar <strong>{confirmEliminar.nombre}</strong>? Los productos que lo tengan asignado quedarán sin grupo de opciones.
          </p>
          <div className="flex justify-end gap-3">
            <button onClick={() => setConfirmEliminar(null)} className="px-4 py-2 rounded-xl text-sm text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors">
              Cancelar
            </button>
            <button
              onClick={() => eliminar.mutate(confirmEliminar.id)}
              disabled={eliminar.isPending}
              className="px-4 py-2 rounded-xl text-sm bg-red-600 hover:bg-red-700 text-white transition-colors disabled:opacity-60"
            >
              {eliminar.isPending ? 'Eliminando...' : 'Eliminar'}
            </button>
          </div>
        </Modal>
      )}
    </div>
  );
}

function FormGrupoOpcionesModal({ grupo, onClose, onGuardar, guardando, error }) {
  const [nombre, setNombre] = useState(grupo?.nombre ?? '');
  const [opciones, setOpciones] = useState(
    grupo?.opciones?.length ? grupo.opciones.map(o => ({ nombre: o.nombre })) : [{ nombre: '' }]
  );

  function setOpcionNombre(i, valor) {
    setOpciones(prev => prev.map((o, idx) => idx === i ? { nombre: valor } : o));
  }

  function agregarOpcion() {
    setOpciones(prev => [...prev, { nombre: '' }]);
  }

  function quitarOpcion(i) {
    setOpciones(prev => prev.filter((_, idx) => idx !== i));
  }

  function moverOpcion(i, direccion) {
    setOpciones(prev => {
      const destino = i + direccion;
      if (destino < 0 || destino >= prev.length) return prev;
      const copia = [...prev];
      [copia[i], copia[destino]] = [copia[destino], copia[i]];
      return copia;
    });
  }

  function handleGuardar() {
    const opcionesValidas = opciones
      .map(o => o.nombre.trim())
      .filter(Boolean)
      .map((nombre, orden) => ({ nombre, orden }));
    onGuardar({ nombre, opciones: opcionesValidas });
  }

  const nombreValido = nombre.trim().length > 0;
  const hayOpcionValida = opciones.some(o => o.nombre.trim().length > 0);

  return (
    <Modal titulo={grupo ? 'Editar Grupo de Opciones' : 'Nuevo Grupo de Opciones'} onClose={onClose}>
      <div className="space-y-4">
        <div>
          <label className="block text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-1.5">Nombre del grupo</label>
          <input
            autoFocus
            value={nombre}
            onChange={e => setNombre(e.target.value)}
            placeholder="Ej: Término de cocción, Sabor"
            className="w-full bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-gray-800 dark:text-gray-100 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 transition"
          />
        </div>

        <div>
          <label className="block text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-1.5">Opciones</label>
          <div className="space-y-2">
            {opciones.map((o, i) => (
              <div key={i} className="flex items-center gap-1.5">
                <input
                  value={o.nombre}
                  onChange={e => setOpcionNombre(i, e.target.value)}
                  placeholder={`Opción ${i + 1}`}
                  className="flex-1 bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-xl px-3 py-2 text-sm text-gray-800 dark:text-gray-100 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 transition"
                />
                <button type="button" onClick={() => moverOpcion(i, -1)} disabled={i === 0} className="p-1.5 rounded-lg text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 disabled:opacity-30 transition-colors">
                  <ChevronUp className="w-4 h-4" />
                </button>
                <button type="button" onClick={() => moverOpcion(i, 1)} disabled={i === opciones.length - 1} className="p-1.5 rounded-lg text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 disabled:opacity-30 transition-colors">
                  <ChevronDown className="w-4 h-4" />
                </button>
                <button type="button" onClick={() => quitarOpcion(i)} disabled={opciones.length === 1} className="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 disabled:opacity-30 transition-colors">
                  <X className="w-4 h-4" />
                </button>
              </div>
            ))}
          </div>
          <button type="button" onClick={agregarOpcion} className="mt-2 flex items-center gap-2 text-sm text-blue-600 dark:text-blue-400 hover:text-blue-700 dark:hover:text-blue-300 transition-colors">
            <Plus className="w-4 h-4" /> Agregar opción
          </button>
        </div>

        {error && <p className="text-sm text-red-600">{error}</p>}

        <div className="flex justify-end gap-3 pt-2">
          <button onClick={onClose} className="px-4 py-2 rounded-xl text-sm text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors">
            Cancelar
          </button>
          <button
            onClick={handleGuardar}
            disabled={guardando || !nombreValido || !hayOpcionValida}
            className="px-4 py-2 rounded-xl text-sm bg-blue-600 hover:bg-blue-700 text-white transition-colors disabled:opacity-60"
          >
            {guardando ? 'Guardando...' : 'Guardar'}
          </button>
        </div>
      </div>
    </Modal>
  );
}
```

- [ ] **Step 4: Selector "Grupo de opciones" en `FormProductoModal`**

En `TabProductos`, cargar los grupos y pasarlos al modal:

```javascript
  const { data: categorias = [] } = useQuery({ queryKey: ['categorias'], queryFn: getCategorias });
  const { data: gruposOpciones = [] } = useQuery({ queryKey: ['grupos-opciones'], queryFn: getGruposOpciones });
```

Y en el JSX donde se renderiza `FormProductoModal`, agregar el prop:

```javascript
        <FormProductoModal
          prod={modal.prod}
          categorias={categorias}
          gruposOpciones={gruposOpciones}
          accesoTodas={accesoTodas}
          sucursales={sucursales}
          ...
```

En `FormProductoModal`, agregar el parámetro `gruposOpciones` a la firma de la función, agregar `grupo_opciones_id` al estado inicial de `form`:

```javascript
function FormProductoModal({ prod, categorias, gruposOpciones, accesoTodas, sucursales, onClose, onGuardar, guardando, error }) {
  const [form, setForm] = useState({
    categoria_id: prod?.categoria_id ?? (categorias[0]?.id ?? ''),
    grupo_opciones_id: prod?.grupo_opciones?.id ?? '',
    nombre:       prod?.nombre ?? '',
    ...
```

Agregar el campo a `handleGuardar`:

```javascript
  function handleGuardar() {
    const datos = {
      categoria_id: parseInt(form.categoria_id),
      grupo_opciones_id: form.grupo_opciones_id ? parseInt(form.grupo_opciones_id) : null,
      nombre: form.nombre,
      ...
```

Agregar el `<select>` en el JSX, justo después del bloque de "Categoría *":

```jsx
          <div className="col-span-2">
            <label className="block text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-1.5">Grupo de opciones</label>
            <select
              value={form.grupo_opciones_id}
              onChange={e => set('grupo_opciones_id', e.target.value)}
              className="w-full bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-gray-800 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="">Ninguno</option>
              {gruposOpciones.map(g => <option key={g.id} value={g.id}>{g.nombre}</option>)}
            </select>
          </div>
```

- [ ] **Step 5: Verificación manual**

Con `npm run dev` corriendo en `backend/` y `frontend/`:

1. Ir a Productos → pestaña "Opciones" → crear un grupo "Término de cocción" con opciones "Jugoso", "Término medio", "Bien cocido".
2. Editarlo: reordenar con las flechas, quitar una opción, guardar — verificar que la lista mostrada se actualiza.
3. Ir a la pestaña "Productos", editar (o crear) un producto (ej. "Picaña") y asignarle el grupo "Término de cocción" en el nuevo selector. Guardar.
4. Volver a "Opciones" y eliminar ese grupo — confirmar que no falla, y que al reabrir el producto su "Grupo de opciones" quedó en "Ninguno".

- [ ] **Step 6: Commit**

```bash
git add frontend/src/api/gruposOpciones.js frontend/src/pages/productos/ProductosPage.jsx
git commit -m "feat(productos): administración de grupos de opciones y selector en el formulario de producto"
```

---

### Task 5: Selector de opción y carrito multi-línea en Ventas

**Files:**
- Create: `frontend/src/pages/ventas/components/SelectorOpcionModal.jsx`
- Modify: `frontend/src/pages/ventas/VentasPage.jsx`

**Interfaces:**
- Consumes: `prod.grupo_opciones` en los productos devueltos por `getProductos` (Task 3): `{ id, nombre, opciones: [{ id, nombre, orden }] }` o `null`.
- Produces: en `VentasPage.jsx`, el carrito pasa a tener como clave lógica `producto_id + nota` en vez de solo `producto_id`; `handleProducto` abre el selector solo si el producto tiene `grupo_opciones`.

- [ ] **Step 1: Componente `SelectorOpcionModal`**

`frontend/src/pages/ventas/components/SelectorOpcionModal.jsx`:

```jsx
import Modal from '../../../components/ui/Modal';

export default function SelectorOpcionModal({ producto, onElegir, onClose }) {
  const grupo = producto.grupo_opciones;

  return (
    <Modal titulo={`${producto.nombre} — ${grupo.nombre}`} onClose={onClose}>
      <div className="space-y-4">
        <div className="flex flex-wrap gap-2">
          {grupo.opciones.map((opcion) => (
            <button
              key={opcion.id}
              type="button"
              onClick={() => onElegir(opcion.nombre)}
              className="px-4 py-2 rounded-full text-sm font-semibold bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-400 hover:border-blue-400 dark:hover:border-blue-500 hover:text-blue-600 dark:hover:text-blue-400 transition-all"
            >
              {opcion.nombre}
            </button>
          ))}
        </div>
        <button
          type="button"
          onClick={() => onElegir(null)}
          className="text-sm text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 transition-colors"
        >
          Agregar sin especificar
        </button>
      </div>
    </Modal>
  );
}
```

- [ ] **Step 2: Importar el selector y agregar el estado**

En `VentasPage.jsx`, agregar el import junto a `ModalPagoQr`:

```javascript
import SelectorOpcionModal from './components/SelectorOpcionModal';
```

Agregar el estado junto a `carrito`:

```javascript
  const [selectorOpcion, setSelectorOpcion] = useState(null); // producto con grupo_opciones, o null
```

- [ ] **Step 3: Reescribir `handleProducto` y el agregado al carrito**

Reemplazar el bloque actual de `handleProducto` (líneas ~96-105):

```javascript
  function agregarAlCarrito(prod, nota) {
    setCarrito((prev) => {
      const existente = prev.find((it) => it.producto_id === prod.id && it.nota === nota);
      if (existente) {
        return prev.map((it) => it === existente ? { ...it, cantidad: it.cantidad + 1 } : it);
      }
      return [...prev, { producto_id: prod.id, nombre: prod.nombre, precio: parseFloat(prod.precio), cantidad: 1, nota }];
    });
  }

  function handleProducto(prod) {
    if (!puedeCrear) return;
    if (prod.grupo_opciones) {
      setSelectorOpcion(prod);
      return;
    }
    agregarAlCarrito(prod, null);
  }

  function elegirOpcion(nota) {
    agregarAlCarrito(selectorOpcion, nota);
    setSelectorOpcion(null);
  }
```

- [ ] **Step 4: Actualizar `incrementar`/`decrementar`/`quitar` para distinguir por nota**

Reemplazar las tres funciones:

```javascript
  function incrementar(producto_id, nota) {
    setCarrito((prev) => prev.map((it) => it.producto_id === producto_id && it.nota === nota ? { ...it, cantidad: it.cantidad + 1 } : it));
  }

  function decrementar(producto_id, nota) {
    setCarrito((prev) => {
      const item = prev.find((it) => it.producto_id === producto_id && it.nota === nota);
      if (item.cantidad <= 1) return prev.filter((it) => it !== item);
      return prev.map((it) => it === item ? { ...it, cantidad: it.cantidad - 1 } : it);
    });
  }

  function quitar(producto_id, nota) {
    setCarrito((prev) => prev.filter((it) => !(it.producto_id === producto_id && it.nota === nota)));
  }
```

- [ ] **Step 5: Cambiar el agregado por producto usado en el badge de las tarjetas**

Reemplazar `itemsPorProducto` (líneas ~88-90) por una suma de cantidades por producto, ya que ahora puede haber varias líneas del mismo producto:

```javascript
  const cantidadPorProducto = useMemo(() => {
    return carrito.reduce((acc, it) => { acc[it.producto_id] = (acc[it.producto_id] ?? 0) + it.cantidad; return acc; }, {});
  }, [carrito]);
```

En el render de las tarjetas de producto (línea ~211), cambiar:

```javascript
                {productos.map((prod) => {
                  const cantidadEnCarrito = cantidadPorProducto[prod.id];
                  return (
                    <button
                      key={prod.id}
                      onClick={() => handleProducto(prod)}
                      disabled={!puedeCrear}
                      className={`relative flex flex-col rounded-xl border transition-all text-left overflow-hidden ${
                        !puedeCrear
                          ? 'opacity-50 cursor-not-allowed'
                          : cantidadEnCarrito
                          ? 'border-blue-400 dark:border-blue-500 bg-blue-50 dark:bg-blue-900/20 hover:bg-blue-100 dark:hover:bg-blue-900/30'
                          : 'border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 hover:border-blue-300 dark:hover:border-blue-600 hover:shadow-sm'
                      }`}
                    >
```

Y el badge de cantidad (línea ~238-242):

```javascript
                      {cantidadEnCarrito && (
                        <span className="absolute top-2 right-2 w-6 h-6 bg-blue-600 text-white text-xs font-bold rounded-full flex items-center justify-center shadow">
                          {cantidadEnCarrito}
                        </span>
                      )}
```

- [ ] **Step 6: Actualizar el render del carrito para que cada nota sea una línea propia**

En el `carrito.map((it) => ...)` (líneas ~272-289 aprox.), cambiar la `key` y pasar `it.nota` a los handlers, y mostrar la nota si existe:

```jsx
                carrito.map((it) => (
                  <div key={`${it.producto_id}|${it.nota ?? ''}`} className="px-4 py-2.5 flex items-center gap-2">
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-gray-800 dark:text-gray-100 truncate">{it.nombre}</p>
                      {it.nota && <p className="text-xs text-amber-600 dark:text-amber-400 truncate">{it.nota}</p>}
                      <p className="text-xs text-gray-400">Bs {it.precio.toFixed(2)} c/u</p>
                    </div>
                    <div className="flex items-center gap-1 shrink-0">
                      <button onClick={() => decrementar(it.producto_id, it.nota)} className="w-6 h-6 rounded-lg bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600 flex items-center justify-center">
                        <Minus className="w-3 h-3" />
                      </button>
                      <span className="w-5 text-center text-sm font-semibold text-gray-800 dark:text-gray-100">{it.cantidad}</span>
                      <button onClick={() => incrementar(it.producto_id, it.nota)} className="w-6 h-6 rounded-lg bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600 flex items-center justify-center">
                        <Plus className="w-3 h-3" />
                      </button>
```

Y el botón de quitar (que sigue un poco más abajo en el mismo bloque):

```javascript
                    <button onClick={() => quitar(it.producto_id, it.nota)} className="shrink-0 p-1 text-gray-300 dark:text-gray-600 hover:text-red-500">
```

- [ ] **Step 7: Renderizar el selector de opciones**

Agregar junto a los demás modales condicionales (cerca de `<ModalPagoQr ... />`):

```jsx
      {selectorOpcion && (
        <SelectorOpcionModal
          producto={selectorOpcion}
          onElegir={elegirOpcion}
          onClose={() => setSelectorOpcion(null)}
        />
      )}
```

- [ ] **Step 8: Verificación manual**

Con `npm run dev` corriendo en `backend/` y `frontend/`, y con el grupo "Término de cocción" ya asignado a un producto (Task 4):

1. Ir a Ventas, tocar un producto **sin** grupo de opciones → se agrega directo al carrito, igual que antes.
2. Tocar el producto **con** grupo de opciones → se abre el selector; elegir "Jugoso" → se agrega al carrito mostrando "Jugoso" como nota.
3. Tocar el mismo producto de nuevo y elegir "Término medio" → debe aparecer como una **segunda línea separada** en el carrito (no debe sumarse a la de "Jugoso").
4. Tocar "Agregar sin especificar" con el mismo producto → una tercera línea, sin nota.
5. Confirmar que el número en la insignia de la tarjeta del producto es la suma de las tres líneas.
6. Cobrar el pedido y verificar en el detalle del pedido (`PedidoPage.jsx`) que cada línea muestra su nota correcta y es editable como ya funcionaba antes.

- [ ] **Step 9: Commit**

```bash
git add frontend/src/pages/ventas/components/SelectorOpcionModal.jsx frontend/src/pages/ventas/VentasPage.jsx
git commit -m "feat(ventas): selector de opciones por producto y carrito multi-línea por nota"
```

---

## Revisión final

Al terminar las 5 tareas: correr toda la suite de backend (`cd backend && npm test`) y confirmar que no hay regresiones fuera de las fallas preexistentes ya conocidas (falta de seed "Sucursal Principal" en algunas suites, no relacionado con este trabajo). Probar a mano el flujo completo end-to-end descrito en el Step de verificación manual de la Task 5.
