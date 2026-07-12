# Multi-sucursal — Fase 2: Operación diaria por sucursal — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Each sucursal manages its own areas/mesas, caja sessions, orders and stock — a cashier or waiter in Sucursal B never sees or touches Sucursal A's floor plan, cash drawer, orders, or inventory (except a user with `acceso_todas_sucursales` in read-only "Todas" mode).

**Architecture:** Denormalize `sucursal_id` onto `areas`, `sesiones_caja`, `pedidos`, `compras` and `registros_inventario`; add a new `producto_stock_sucursal` table so stock quantity is tracked per branch while the product catalog (name/price/category) stays shared. A single centralized helper (`ajustarStockSucursal`) replaces three duplicated ad-hoc stock-mutation blocks in `ventas`, `compras` and `inventario`. Every read filters by the authenticated user's `sucursal_id` unless they're in `acceso_todas` mode; every write requires a concrete `sucursal_id` (rejects `acceso_todas`/`null`). Socket.io gains per-sucursal rooms so live order/print events don't cross branches.

**Tech Stack:** Node.js/Express, Sequelize (MySQL), Jest + Supertest (hits the real local dev DB — no mocking), React 18 + TanStack Query + Zustand, socket.io / socket.io-client.

## Global Constraints

- Migrations (`backend/database/migrations/*.sql`) are schema-only, applied manually with `mysql -u root -p bd_restaurante < database/migrations/0NN_x.sql` from `backend/` (empty password — press enter). No data/INSERT in migrations.
- All data provisioning/backfill lives in `backend/database/seeds/seed.js`, using `findOrCreate`/idempotent guards so it's safe to re-run. Run with `npm run seed` from `backend/`.
- API responses use the envelope `{ ok: true, datos }` / `{ ok: false, mensaje }`.
- Route protection: `router.use(auth)` then `verificarPermiso('modulo','accion')` per route (existing `backend/src/middlewares/permisos.js`, unchanged).
- `req.usuario.sucursal_id` (number or `null`) and `req.usuario.acceso_todas` (boolean) are already populated by `backend/src/middlewares/auth.js` on every authenticated request (built in Fase 1).
- Backend tests (`backend/tests/*.test.js`) use `supertest` against `backend/src/app.js`, authenticating as `admin@restaurante.com` / `process.env.ADMIN_PASSWORD || 'admin123'`. Run with `npm test` (`jest --runInBand`) from `backend/`. Current baseline before this plan: 15 suites / 37 tests passing.
- Sequelize models follow `backend/src/models/`'s style: `sequelize.define('Nombre', {...}, { tableName: 'snake_case', createdAt: 'creado_en', updatedAt: 'actualizado_en' })` (or `timestamps: false` for join/log tables that don't have those columns today — match each existing table's current setting, don't add timestamps that don't exist in the schema).
- The product catalog (`productos`: nombre, precio, categoria, imagen) stays shared across all sucursales — only stock quantity is split per branch. `productos.stock` remains the column name, but for products that track inventory (`stock IS NOT NULL`) its value becomes the sum of that product's rows in the new `producto_stock_sucursal` table.
- A write action requiring a concrete branch (create/edit area or mesa, abrir caja, crear/cobrar pedido, crear/recibir compra, entrada/salida/ajuste de inventario) must reject with `403 { ok: false, mensaje: 'Debes iniciar sesión en una sucursal específica para realizar esta acción' }` when `req.usuario.sucursal_id === null`.
- Frontend has no test runner; verification for frontend tasks is a Vite dev-server/`vite build` compile check plus careful manual code tracing (no browser automation available in this environment).

---

### Task 1: Esquema de base de datos — sucursal_id operativo + producto_stock_sucursal

**Files:**
- Create: `backend/database/migrations/013_sucursal_operativa.sql`

**Interfaces:**
- Produces: `areas.sucursal_id`, `sesiones_caja.sucursal_id`, `pedidos.sucursal_id`, `compras.sucursal_id`, `registros_inventario.sucursal_id` (all `INT UNSIGNED NOT NULL`, FK to `sucursales(id)`); new table `producto_stock_sucursal(producto_id, sucursal_id, stock, actualizado_en)` with composite PK `(producto_id, sucursal_id)` and `ON DELETE CASCADE` both directions. Task 2 depends on all of this existing.

- [ ] **Step 1: Write the migration file**

```sql
ALTER TABLE areas
  ADD COLUMN sucursal_id INT UNSIGNED NOT NULL AFTER id,
  ADD FOREIGN KEY (sucursal_id) REFERENCES sucursales(id);

ALTER TABLE sesiones_caja
  ADD COLUMN sucursal_id INT UNSIGNED NOT NULL AFTER usuario_id,
  ADD FOREIGN KEY (sucursal_id) REFERENCES sucursales(id);

ALTER TABLE pedidos
  ADD COLUMN sucursal_id INT UNSIGNED NOT NULL AFTER id,
  ADD FOREIGN KEY (sucursal_id) REFERENCES sucursales(id);

ALTER TABLE compras
  ADD COLUMN sucursal_id INT UNSIGNED NOT NULL AFTER id,
  ADD FOREIGN KEY (sucursal_id) REFERENCES sucursales(id);

ALTER TABLE registros_inventario
  ADD COLUMN sucursal_id INT UNSIGNED NOT NULL AFTER producto_id,
  ADD FOREIGN KEY (sucursal_id) REFERENCES sucursales(id);

CREATE TABLE IF NOT EXISTS producto_stock_sucursal (
  producto_id INT UNSIGNED NOT NULL,
  sucursal_id INT UNSIGNED NOT NULL,
  stock INT NOT NULL DEFAULT 0,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (producto_id, sucursal_id),
  FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE CASCADE,
  FOREIGN KEY (sucursal_id) REFERENCES sucursales(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- [ ] **Step 2: Apply it to the local dev DB**

Run: `mysql -u root -p bd_restaurante < database/migrations/013_sucursal_operativa.sql` (from `backend/`)
Expected: no output, exit code 0. (If `areas`, `sesiones_caja`, `pedidos` or `compras` already have rows, the `NOT NULL` ADD COLUMN will fail — that's expected and correct: Task 2's seed backfill must run in the same deploy step as this migration, never independently. Locally, if you have existing rows and this fails, add the column as nullable first, backfill via Task 2's seed, then a follow-up `ALTER TABLE ... MODIFY sucursal_id INT UNSIGNED NOT NULL` — but for a fresh local dev DB seeded only through Fase 1, these tables are likely still empty and the direct `NOT NULL` add will succeed immediately.)

- [ ] **Step 3: Verify the schema landed**

Run: `mysql -u root -p bd_restaurante -e "SHOW COLUMNS FROM areas LIKE 'sucursal_id'; SHOW COLUMNS FROM sesiones_caja LIKE 'sucursal_id'; SHOW COLUMNS FROM pedidos LIKE 'sucursal_id'; SHOW COLUMNS FROM compras LIKE 'sucursal_id'; SHOW COLUMNS FROM registros_inventario LIKE 'sucursal_id'; DESCRIBE producto_stock_sucursal;"`
Expected: one row per `SHOW COLUMNS` (confirming the column exists, `NOT NULL`), and `producto_stock_sucursal`'s 4 columns.

- [ ] **Step 4: Commit**

```bash
git add backend/database/migrations/013_sucursal_operativa.sql
git commit -m "feat(db): add sucursal_id to operational tables + producto_stock_sucursal"
```

---

### Task 2: Modelos Sequelize y backfill de datos existentes

**Files:**
- Create: `backend/src/models/ProductoStockSucursal.js`
- Modify: `backend/src/models/Area.js`
- Modify: `backend/src/models/SesionCaja.js`
- Modify: `backend/src/models/Pedido.js`
- Modify: `backend/src/models/Compra.js`
- Modify: `backend/src/models/RegistroInventario.js`
- Modify: `backend/src/models/index.js`
- Modify: `backend/database/seeds/seed.js`

**Interfaces:**
- Consumes: schema from Task 1; `Sucursal` model (from Fase 1).
- Produces: `Area`, `SesionCaja`, `Pedido`, `Compra`, `RegistroInventario` all gain a `sucursal_id` field and a `belongsTo(Sucursal, { as: 'sucursal' })` association. New `ProductoStockSucursal` model (`tableName: 'producto_stock_sucursal'`, `timestamps: false` except `actualizado_en` — see step 1) with `belongsTo(Producto)`/`belongsTo(Sucursal)` and `Producto.hasMany(ProductoStockSucursal, { as: 'stock_sucursales' })`. After the seed runs: every existing row in the five operational tables has `sucursal_id` pointing at "Sucursal Principal", and every product with `stock IS NOT NULL` has one `producto_stock_sucursal` row under "Sucursal Principal" matching its current `stock` value. Task 3+ rely on all of this.

- [ ] **Step 1: Create the `ProductoStockSucursal` model**

```javascript
// backend/src/models/ProductoStockSucursal.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const ProductoStockSucursal = sequelize.define('ProductoStockSucursal', {
  producto_id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true },
  sucursal_id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true },
  stock: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 0 },
}, {
  tableName: 'producto_stock_sucursal',
  timestamps: true,
  createdAt: false,
  updatedAt: 'actualizado_en',
});

module.exports = ProductoStockSucursal;
```

- [ ] **Step 2: Add `sucursal_id` to the five operational models**

In `backend/src/models/Area.js`, add after `id`:

```javascript
  sucursal_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
```

In `backend/src/models/SesionCaja.js`, add after `usuario_id`:

```javascript
  sucursal_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
```

In `backend/src/models/Pedido.js`, add after `id`:

```javascript
  sucursal_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
```

In `backend/src/models/Compra.js`, add after `id`:

```javascript
  sucursal_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
```

In `backend/src/models/RegistroInventario.js`, add after `producto_id`:

```javascript
  sucursal_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
```

- [ ] **Step 3: Wire associations in `models/index.js`**

Add the require near the other model requires:

```javascript
const ProductoStockSucursal = require('./ProductoStockSucursal');
```

Add this association block (anywhere after `Sucursal` is required and after `Area`/`SesionCaja`/`Pedido`/`Compra`/`RegistroInventario`/`Producto` are required):

```javascript
// Sucursal_id operativo (Fase 2)
Area.belongsTo(Sucursal, { foreignKey: 'sucursal_id', as: 'sucursal' });
SesionCaja.belongsTo(Sucursal, { foreignKey: 'sucursal_id', as: 'sucursal' });
Pedido.belongsTo(Sucursal, { foreignKey: 'sucursal_id', as: 'sucursal' });
Compra.belongsTo(Sucursal, { foreignKey: 'sucursal_id', as: 'sucursal' });
RegistroInventario.belongsTo(Sucursal, { foreignKey: 'sucursal_id', as: 'sucursal' });

// Stock por sucursal
Producto.hasMany(ProductoStockSucursal, { foreignKey: 'producto_id', as: 'stock_sucursales' });
ProductoStockSucursal.belongsTo(Producto, { foreignKey: 'producto_id', as: 'producto' });
ProductoStockSucursal.belongsTo(Sucursal, { foreignKey: 'sucursal_id', as: 'sucursal' });
```

Add `ProductoStockSucursal` to the final `module.exports` object.

- [ ] **Step 4: Verify the models load without error**

Run: `node -e "const m = require('./src/models'); m.sequelize.authenticate().then(() => m.Area.findOne({include:[{model:m.Sucursal,as:'sucursal'}]})).then(() => { console.log('OK'); process.exit(0); }).catch(e => { console.error(e.message); process.exit(1); });"` (from `backend/`)
Expected: prints `OK`, exit code 0.

- [ ] **Step 5: Backfill existing rows in `seed.js`**

In `backend/database/seeds/seed.js`, update the model import at the top to include the five new models plus `Sucursal` (it may already import `Sucursal` from the Fase 1 work — check first and only add what's missing):

```javascript
const { sequelize, Rol, Permiso, Usuario, Sucursal, Area, SesionCaja, Pedido, Compra, RegistroInventario, Producto, ProductoStockSucursal } = require('../../src/models');
```

Add this block right after the existing "Sucursal por defecto" block from Fase 1 (the one that does `Sucursal.findOrCreate({ where: { nombre: 'Sucursal Principal' } ...})` and backfills `usuarios_sucursales`):

```javascript
  // Backfill operativo Fase 2 — todo lo existente queda en la Sucursal Principal
  await Area.update({ sucursal_id: principal.id }, { where: { sucursal_id: null } });
  await sequelize.query('UPDATE areas SET sucursal_id = ? WHERE sucursal_id IS NULL OR sucursal_id = 0', { replacements: [principal.id] });
  await sequelize.query('UPDATE sesiones_caja SET sucursal_id = ? WHERE sucursal_id IS NULL OR sucursal_id = 0', { replacements: [principal.id] });
  await sequelize.query('UPDATE pedidos SET sucursal_id = ? WHERE sucursal_id IS NULL OR sucursal_id = 0', { replacements: [principal.id] });
  await sequelize.query('UPDATE compras SET sucursal_id = ? WHERE sucursal_id IS NULL OR sucursal_id = 0', { replacements: [principal.id] });
  await sequelize.query('UPDATE registros_inventario SET sucursal_id = ? WHERE sucursal_id IS NULL OR sucursal_id = 0', { replacements: [principal.id] });

  const productosConStock = await Producto.findAll({ where: { stock: { [require('sequelize').Op.ne]: null } } });
  for (const p of productosConStock) {
    await ProductoStockSucursal.findOrCreate({
      where: { producto_id: p.id, sucursal_id: principal.id },
      defaults: { stock: p.stock },
    });
  }
```

(Note: the direct `sequelize.query('UPDATE ...')` calls are used instead of `Model.update` because Task 1's migration adds these columns as `NOT NULL` with no default — on a fresh empty local DB there will be zero rows to update, so these are no-ops there, but this same seed script is what backfills a populated production DB where Task 1's migration must be applied as nullable-then-backfill-then-NOT-NULL, per Task 1 Step 2's note. The redundant `Area.update` line above is superseded by the raw query and can be removed — keep only the five `sequelize.query` UPDATE statements plus the `ProductoStockSucursal` loop.)

- [ ] **Step 6: Run the seed against the local dev DB**

Run: `npm run seed` (from `backend/`)
Expected: ends with `Seed completado`, exit code 0.

- [ ] **Step 7: Verify the backfill**

Run: `mysql -u root -p bd_restaurante -e "SELECT COUNT(*) FROM areas WHERE sucursal_id IS NULL; SELECT COUNT(*) FROM producto_stock_sucursal;"`
Expected: first count is `0` (no orphaned areas); second count matches however many products currently have non-null `stock`.

- [ ] **Step 8: Run the full test suite to check for regressions**

Run: `npm test` (from `backend/`)
Expected: all 15 suites / 37 tests still pass (this task only added columns/associations, no behavior changed yet).

- [ ] **Step 9: Commit**

```bash
git add backend/src/models backend/database/seeds/seed.js
git commit -m "feat(db): add sucursal_id models and backfill existing operational data"
```

---

### Task 3: Servicio centralizado de stock por sucursal + guard de escritura

**Files:**
- Create: `backend/src/modules/inventario/stock.service.js`
- Create: `backend/src/middlewares/sucursalActiva.js`
- Test: `backend/tests/stock.service.test.js`

**Interfaces:**
- Consumes: `ProductoStockSucursal`, `Producto`, `RegistroInventario` models (Task 2).
- Produces: `ajustarStockSucursal({ producto_id, sucursal_id, tipo, cantidad, usuario_id, nota })` → `Promise<{ stock_anterior, stock_nuevo }>`, throws `Object.assign(new Error(...), { status: 409 })` on insufficient stock for `salida`/`venta`. `tipo` is one of `'entrada' | 'salida' | 'venta' | 'compra' | 'ajuste'` (same semantics as the current `inventario.service.js`'s `_movimiento`: entrada/compra add, salida/venta subtract with a stock-sufficiency check, ajuste sets the absolute value). Also produces `mezclarStockPorSucursal(productos, { sucursal_id, acceso_todas })` → returns the same array of plain product objects with `stock` overridden to that sucursal's quantity (when not `acceso_todas`) or left as the aggregate total plus a `stock_por_sucursal: [{sucursal_id, nombre, stock}]` array (when `acceso_todas`) — Task 9 consumes this. `requiereSucursalActiva` is an Express middleware — `(req, res, next)` — that responds `403 { ok:false, mensaje: 'Debes iniciar sesión en una sucursal específica para realizar esta acción' }` when `req.usuario.sucursal_id === null`, otherwise calls `next()`. Tasks 4-8 apply it to write routes.

- [ ] **Step 1: Write the failing tests**

```javascript
// backend/tests/stock.service.test.js
const { Producto, Categoria, Sucursal, ProductoStockSucursal, Usuario } = require('../src/models');
const { ajustarStockSucursal } = require('../src/modules/inventario/stock.service');

let categoria, producto, sucursalA, sucursalB, admin;

beforeAll(async () => {
  categoria = await Categoria.create({ nombre: 'Categoria Stock Test' });
  producto = await Producto.create({ categoria_id: categoria.id, nombre: 'Producto Stock Test', precio: 10, stock: 0 });
  sucursalA = await Sucursal.create({ nombre: 'Sucursal Stock Test A' });
  sucursalB = await Sucursal.create({ nombre: 'Sucursal Stock Test B' });
  admin = await Usuario.findOne({ where: { email: 'admin@restaurante.com' } });
});

afterAll(async () => {
  await ProductoStockSucursal.destroy({ where: { producto_id: producto.id } });
  await Producto.destroy({ where: { id: producto.id } });
  await Categoria.destroy({ where: { id: categoria.id } });
  await Sucursal.destroy({ where: { id: [sucursalA.id, sucursalB.id] } });
});

describe('ajustarStockSucursal', () => {
  it('crea la fila de stock por sucursal en la primera entrada y suma', async () => {
    const r = await ajustarStockSucursal({ producto_id: producto.id, sucursal_id: sucursalA.id, tipo: 'entrada', cantidad: 10, usuario_id: admin.id, nota: 'test' });
    expect(r.stock_anterior).toBe(0);
    expect(r.stock_nuevo).toBe(10);

    const fila = await ProductoStockSucursal.findOne({ where: { producto_id: producto.id, sucursal_id: sucursalA.id } });
    expect(fila.stock).toBe(10);
  });

  it('las sucursales no comparten stock entre sí', async () => {
    await ajustarStockSucursal({ producto_id: producto.id, sucursal_id: sucursalB.id, tipo: 'entrada', cantidad: 15, usuario_id: admin.id });

    const filaA = await ProductoStockSucursal.findOne({ where: { producto_id: producto.id, sucursal_id: sucursalA.id } });
    const filaB = await ProductoStockSucursal.findOne({ where: { producto_id: producto.id, sucursal_id: sucursalB.id } });
    expect(filaA.stock).toBe(10);
    expect(filaB.stock).toBe(15);
  });

  it('una venta en A descuenta solo de A y no toca B', async () => {
    await ajustarStockSucursal({ producto_id: producto.id, sucursal_id: sucursalA.id, tipo: 'venta', cantidad: 3, usuario_id: admin.id });

    const filaA = await ProductoStockSucursal.findOne({ where: { producto_id: producto.id, sucursal_id: sucursalA.id } });
    const filaB = await ProductoStockSucursal.findOne({ where: { producto_id: producto.id, sucursal_id: sucursalB.id } });
    expect(filaA.stock).toBe(7);
    expect(filaB.stock).toBe(15);
  });

  it('rechaza una venta/salida sin stock suficiente en esa sucursal', async () => {
    await expect(
      ajustarStockSucursal({ producto_id: producto.id, sucursal_id: sucursalA.id, tipo: 'salida', cantidad: 999, usuario_id: admin.id })
    ).rejects.toMatchObject({ status: 409 });
  });

  it('recalcula productos.stock como la suma de todas las sucursales', async () => {
    const p = await Producto.findByPk(producto.id);
    expect(p.stock).toBe(22); // 7 (A) + 15 (B)
  });

  it('un ajuste fija el valor absoluto de esa sucursal', async () => {
    await ajustarStockSucursal({ producto_id: producto.id, sucursal_id: sucursalA.id, tipo: 'ajuste', cantidad: 50, usuario_id: admin.id });
    const filaA = await ProductoStockSucursal.findOne({ where: { producto_id: producto.id, sucursal_id: sucursalA.id } });
    expect(filaA.stock).toBe(50);
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npx jest tests/stock.service.test.js` (from `backend/`)
Expected: FAIL — `Cannot find module '../src/modules/inventario/stock.service'`.

- [ ] **Step 3: Write `stock.service.js`**

```javascript
// backend/src/modules/inventario/stock.service.js
const { Producto, ProductoStockSucursal, RegistroInventario } = require('../../models');

async function ajustarStockSucursal({ producto_id, sucursal_id, tipo, cantidad, usuario_id, nota, transaction }) {
  const [fila] = await ProductoStockSucursal.findOrCreate({
    where: { producto_id, sucursal_id },
    defaults: { stock: 0 },
    transaction,
  });

  const stock_anterior = fila.stock;
  let stock_nuevo;

  if (tipo === 'entrada' || tipo === 'compra') {
    stock_nuevo = stock_anterior + cantidad;
  } else if (tipo === 'salida' || tipo === 'venta') {
    if (stock_anterior < cantidad) {
      throw Object.assign(new Error('Stock insuficiente en esta sucursal'), { status: 409 });
    }
    stock_nuevo = stock_anterior - cantidad;
  } else if (tipo === 'ajuste') {
    stock_nuevo = cantidad;
  } else {
    throw Object.assign(new Error(`Tipo de movimiento inválido: ${tipo}`), { status: 400 });
  }

  await fila.update({ stock: stock_nuevo }, { transaction });

  const total = await ProductoStockSucursal.sum('stock', { where: { producto_id }, transaction });
  await Producto.update({ stock: total || 0 }, { where: { id: producto_id }, transaction });

  await RegistroInventario.create({
    producto_id, sucursal_id, usuario_id, tipo, cantidad, stock_anterior, stock_nuevo, nota,
  }, { transaction });

  return { stock_anterior, stock_nuevo };
}

async function mezclarStockPorSucursal(productos, { sucursal_id, acceso_todas }) {
  const productoIds = productos.map(p => p.id ?? p.dataValues?.id);
  const filas = await ProductoStockSucursal.findAll({
    where: { producto_id: productoIds },
    include: [{ model: require('../../models').Sucursal, as: 'sucursal', attributes: ['id', 'nombre'] }],
  });

  return productos.map(p => {
    const plano = typeof p.toJSON === 'function' ? p.toJSON() : { ...p };
    if (plano.stock === null || plano.stock === undefined) return plano; // no trackea inventario

    const filasProducto = filas.filter(f => f.producto_id === plano.id);

    if (acceso_todas) {
      plano.stock_por_sucursal = filasProducto.map(f => ({
        sucursal_id: f.sucursal_id,
        nombre: f.sucursal?.nombre,
        stock: f.stock,
      }));
      return plano; // stock queda como el total agregado
    }

    const propia = filasProducto.find(f => f.sucursal_id === sucursal_id);
    plano.stock = propia ? propia.stock : 0;
    return plano;
  });
}

module.exports = { ajustarStockSucursal, mezclarStockPorSucursal };
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npx jest tests/stock.service.test.js` (from `backend/`)
Expected: PASS, 6/6.

- [ ] **Step 5: Write `requiereSucursalActiva`**

```javascript
// backend/src/middlewares/sucursalActiva.js
function requiereSucursalActiva(req, res, next) {
  if (req.usuario.sucursal_id === null) {
    return res.status(403).json({
      ok: false,
      mensaje: 'Debes iniciar sesión en una sucursal específica para realizar esta acción',
    });
  }
  next();
}

module.exports = { requiereSucursalActiva };
```

- [ ] **Step 6: Run the full suite to check for regressions**

Run: `npm test` (from `backend/`)
Expected: 16 suites / 43 tests passing (37 baseline + 6 new), zero regressions — this task added new files but didn't wire them into any existing route yet.

- [ ] **Step 7: Commit**

```bash
git add backend/src/modules/inventario/stock.service.js backend/src/middlewares/sucursalActiva.js backend/tests/stock.service.test.js
git commit -m "feat(inventario): centralized per-sucursal stock adjustment + write guard"
```

---

### Task 4: Áreas y mesas por sucursal

**Files:**
- Modify: `backend/src/modules/mesas/mesas.service.js`
- Modify: `backend/src/modules/mesas/mesas.controller.js`
- Modify: `backend/src/modules/mesas/mesas.routes.js`
- Modify: `backend/src/modules/mesas/areas.routes.js`
- Test: `backend/tests/mesas.test.js`

**Interfaces:**
- Consumes: `requiereSucursalActiva` (Task 3).
- Produces: `listarAreas(filtro)`/`listarMesas(area_id, filtro)` accept `{ sucursal_id, acceso_todas }` and filter accordingly. `crearArea({ nombre }, sucursal_id)` ignores any `sucursal_id` in the request body and always uses the authenticated user's. `crearMesa` validates the target area belongs to the caller's sucursal.

- [ ] **Step 1: Write the failing tests**

```javascript
// backend/tests/mesas.test.js — append to the existing file (keep the existing describe block)
const { Area, Sucursal } = require('../src/models');

describe('Mesas y áreas por sucursal', () => {
  let adminToken, sucursalOtra;

  beforeAll(async () => {
    const login = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'admin@restaurante.com', contrasena: process.env.ADMIN_PASSWORD || 'admin123' });
    adminToken = login.body.datos.token;
    sucursalOtra = await Sucursal.create({ nombre: 'Sucursal Mesas Test' });
  });

  afterAll(async () => {
    await Area.destroy({ where: { sucursal_id: sucursalOtra.id } });
    await Sucursal.destroy({ where: { id: sucursalOtra.id } });
  });

  it('crea un área usando la sucursal del usuario autenticado, ignorando sucursal_id del body', async () => {
    const res = await request(app)
      .post('/api/v1/areas')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ nombre: 'Area Test Sucursal', sucursal_id: sucursalOtra.id });

    expect(res.status).toBe(201);
    expect(res.body.datos.sucursal_id).not.toBe(sucursalOtra.id);

    await Area.destroy({ where: { id: res.body.datos.id } });
  });

  it('lista solo las áreas de la sucursal activa del usuario', async () => {
    const area = await Area.create({ nombre: 'Area Otra Sucursal Test', sucursal_id: sucursalOtra.id });

    const res = await request(app)
      .get('/api/v1/areas')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(200);
    expect(res.body.datos.find(a => a.id === area.id)).toBeUndefined();

    await area.destroy();
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npx jest tests/mesas.test.js` (from `backend/`)
Expected: FAIL — `crear` responds with the requested `sucursal_id` unchanged (feature not implemented), and the list includes the other sucursal's area (no filter yet).

- [ ] **Step 3: Update `mesas.service.js`**

```javascript
// backend/src/modules/mesas/mesas.service.js
const { Area, Mesa } = require('../../models');

// --- Áreas ---

function _filtroSucursal({ sucursal_id, acceso_todas }) {
  return acceso_todas ? {} : { sucursal_id };
}

async function listarAreas(alcance) {
  return Area.findAll({ where: _filtroSucursal(alcance), include: [{ model: Mesa, as: 'mesas' }], order: [['nombre', 'ASC']] });
}

async function crearArea({ nombre }, sucursal_id) {
  return Area.create({ nombre, sucursal_id });
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

async function listarMesas(area_id, alcance) {
  const where = area_id ? { area_id } : {};
  return Mesa.findAll({
    where,
    include: [{ model: Area, as: 'area', attributes: ['id', 'nombre', 'sucursal_id'], where: _filtroSucursal(alcance) }],
    order: [['nombre', 'ASC']],
  });
}

async function obtenerMesa(id) {
  const mesa = await Mesa.findByPk(id, { include: [{ model: Area, as: 'area', attributes: ['id', 'nombre', 'sucursal_id'] }] });
  if (!mesa) throw Object.assign(new Error('Mesa no encontrada'), { status: 404 });
  return mesa;
}

async function crearMesa({ area_id, nombre, asientos = 4, pos_x = 0, pos_y = 0 }, sucursal_id) {
  const area = await Area.findByPk(area_id);
  if (!area) throw Object.assign(new Error('Área no encontrada'), { status: 404 });
  if (area.sucursal_id !== sucursal_id) {
    throw Object.assign(new Error('El área no pertenece a tu sucursal'), { status: 404 });
  }
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

- [ ] **Step 4: Update `mesas.controller.js`**

```javascript
// backend/src/modules/mesas/mesas.controller.js
const svc = require('./mesas.service');

function _alcance(req) {
  return { sucursal_id: req.usuario.sucursal_id, acceso_todas: req.usuario.acceso_todas };
}

async function listarAreas(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listarAreas(_alcance(req)) }); }
  catch (err) { next(err); }
}

async function crearArea(req, res, next) {
  try {
    if (!req.body.nombre) return res.status(400).json({ ok: false, mensaje: 'nombre es requerido' });
    res.status(201).json({ ok: true, datos: await svc.crearArea(req.body, req.usuario.sucursal_id) });
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
  try { res.json({ ok: true, datos: await svc.listarMesas(req.query.area_id, _alcance(req)) }); }
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
    res.status(201).json({ ok: true, datos: await svc.crearMesa(req.body, req.usuario.sucursal_id) });
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

- [ ] **Step 5: Add `requiereSucursalActiva` to the write routes**

In `backend/src/modules/mesas/areas.routes.js`, import and apply to `POST '/'`:

```javascript
const { Router } = require('express');
const ctrl = require('./mesas.controller');
const auth = require('../../middlewares/auth');
const { verificarPermiso } = require('../../middlewares/permisos');
const { requiereSucursalActiva } = require('../../middlewares/sucursalActiva');

const router = Router();
router.use(auth);

router.get('/', verificarPermiso('ventas', 'ver'), ctrl.listarAreas);
router.post('/', verificarPermiso('configuracion', 'editar'), requiereSucursalActiva, ctrl.crearArea);
router.put('/:id', verificarPermiso('configuracion', 'editar'), ctrl.actualizarArea);
router.delete('/:id', verificarPermiso('configuracion', 'editar'), ctrl.eliminarArea);

module.exports = router;
```

In `backend/src/modules/mesas/mesas.routes.js`, import and apply to `POST '/'`:

```javascript
const { Router } = require('express');
const ctrl = require('./mesas.controller');
const auth = require('../../middlewares/auth');
const { verificarPermiso } = require('../../middlewares/permisos');
const { requiereSucursalActiva } = require('../../middlewares/sucursalActiva');

const router = Router();
router.use(auth);

router.get('/', verificarPermiso('ventas', 'ver'), ctrl.listarMesas);
router.post('/', verificarPermiso('configuracion', 'editar'), requiereSucursalActiva, ctrl.crearMesa);
router.get('/:id', verificarPermiso('ventas', 'ver'), ctrl.obtenerMesa);
router.put('/:id', verificarPermiso('configuracion', 'editar'), ctrl.actualizarMesa);
router.patch('/:id/posicion', verificarPermiso('configuracion', 'editar'), ctrl.actualizarPosicion);
router.delete('/:id', verificarPermiso('configuracion', 'editar'), ctrl.eliminarMesa);

module.exports = router;
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `npx jest tests/mesas.test.js` (from `backend/`)
Expected: PASS.

- [ ] **Step 7: Run the full suite to check for regressions**

Run: `npm test` (from `backend/`)
Expected: all suites pass.

- [ ] **Step 8: Commit**

```bash
git add backend/src/modules/mesas backend/tests/mesas.test.js
git commit -m "feat(mesas): scope areas and mesas by sucursal"
```

---

### Task 5: Caja por sucursal

**Files:**
- Modify: `backend/src/modules/caja/caja.service.js`
- Modify: `backend/src/modules/caja/caja.controller.js`
- Modify: `backend/src/modules/caja/caja.routes.js`
- Test: `backend/tests/caja.test.js`

**Interfaces:**
- Consumes: `requiereSucursalActiva` (Task 3).
- Produces: `obtenerActiva(usuario_id, sucursal_id)` — a user's "open session" check is now per-branch, not global. `abrir(usuario_id, sucursal_id, monto_apertura)` records `sucursal_id`. `listar(alcance)` filters unless `acceso_todas`.

- [ ] **Step 1: Write the failing tests**

```javascript
// backend/tests/caja.test.js — append to the existing file
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npx jest tests/caja.test.js` (from `backend/`)
Expected: FAIL — `abrir` doesn't set `sucursal_id` (missing/`undefined` in the response), route registration `Object.assign` errors from a `NOT NULL` column not being provided.

- [ ] **Step 3: Update `caja.service.js`**

Only the two functions below change; keep every other function (`listarGastos`, `cerrar`, `reporte`, etc.) exactly as-is:

```javascript
async function obtenerActiva(usuario_id, sucursal_id) {
  const sesion = await SesionCaja.findOne({
    where: { usuario_id, sucursal_id, estado: 'abierta' },
    include: [{ model: Usuario, as: 'usuario', attributes: ['id', 'nombre'] }],
  });
  if (!sesion) return null;

  const [ventasEfectivo, ventasQR] = await Promise.all([
    LibroCaja.sum('monto', { where: { sesion_caja_id: sesion.id, tipo: 'ingreso', metodo_pago: 'efectivo' } }),
    LibroCaja.sum('monto', { where: { sesion_caja_id: sesion.id, tipo: 'ingreso', metodo_pago: 'qr' } }),
  ]);

  const datos = sesion.toJSON();
  datos.ventas_efectivo = ventasEfectivo || 0;
  datos.ventas_qr       = ventasQR       || 0;
  return datos;
}
```

```javascript
async function abrir(usuario_id, sucursal_id, monto_apertura = 0) {
  const activa = await obtenerActiva(usuario_id, sucursal_id);
  if (activa) throw Object.assign(new Error('Ya tienes una sesión de caja abierta en esta sucursal'), { status: 409 });
  return SesionCaja.create({ usuario_id, sucursal_id, monto_apertura });
}
```

Also update `listar()` to accept and apply the scope:

```javascript
async function listar(alcance = {}) {
  const where = alcance.acceso_todas ? {} : { sucursal_id: alcance.sucursal_id };
  return SesionCaja.findAll({
    where,
    include: [{ model: Usuario, as: 'usuario', attributes: ['id', 'nombre'] }],
    order: [['abierto_en', 'DESC']],
    limit: 50,
  });
}
```

Update the final export line to keep exporting the same function names (no signature changes to the export list itself, only to `obtenerActiva`/`abrir`/`listar`'s parameters — already covered above).

- [ ] **Step 4: Update `caja.controller.js`**

```javascript
// backend/src/modules/caja/caja.controller.js
const svc = require('./caja.service');

async function obtenerActiva(req, res, next) {
  try {
    const sesion = await svc.obtenerActiva(req.usuario.id, req.usuario.sucursal_id);
    res.json({ ok: true, datos: sesion });
  } catch (err) { next(err); }
}

async function listar(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listar({ sucursal_id: req.usuario.sucursal_id, acceso_todas: req.usuario.acceso_todas }) }); }
  catch (err) { next(err); }
}

async function obtener(req, res, next) {
  try { res.json({ ok: true, datos: await svc.obtener(req.params.id) }); }
  catch (err) { next(err); }
}

async function abrir(req, res, next) {
  try {
    const { monto_apertura } = req.body;
    res.status(201).json({ ok: true, datos: await svc.abrir(req.usuario.id, req.usuario.sucursal_id, monto_apertura) });
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

async function reporte(req, res, next) {
  try { res.json({ ok: true, datos: await svc.reporte(req.params.id) }); }
  catch (err) { next(err); }
}

module.exports = { obtenerActiva, listar, obtener, abrir, registrarGasto, listarGastos, cerrar, reporte };
```

- [ ] **Step 5: Add `requiereSucursalActiva` to `caja.routes.js`**

```javascript
// backend/src/modules/caja/caja.routes.js
const { Router } = require('express');
const ctrl = require('./caja.controller');
const auth = require('../../middlewares/auth');
const { verificarPermiso } = require('../../middlewares/permisos');
const { requiereSucursalActiva } = require('../../middlewares/sucursalActiva');

const router = Router();
router.use(auth);

router.get('/activa', verificarPermiso('caja', 'ver'), ctrl.obtenerActiva);
router.get('/', verificarPermiso('caja', 'ver'), ctrl.listar);
router.post('/abrir', verificarPermiso('caja', 'abrir'), requiereSucursalActiva, ctrl.abrir);
router.get('/:id', verificarPermiso('caja', 'ver'), ctrl.obtener);
router.get('/:id/gastos', verificarPermiso('caja', 'ver'), ctrl.listarGastos);
router.post('/:id/gastos', verificarPermiso('caja', 'ver'), ctrl.registrarGasto);
router.post('/:id/cerrar', verificarPermiso('caja', 'cerrar'), ctrl.cerrar);
router.get('/:id/reporte', verificarPermiso('caja', 'ver'), ctrl.reporte);

module.exports = router;
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `npx jest tests/caja.test.js` (from `backend/`)
Expected: PASS.

- [ ] **Step 7: Run the full suite to check for regressions**

Run: `npm test` (from `backend/`)
Expected: all suites pass. (`obtenerActiva`'s signature changed from 1 to 2 params — confirm no other module calls it; `ventas.service.js` doesn't call it directly, it receives `sesion_caja_id` from the frontend/controller, so this is safe.)

- [ ] **Step 8: Commit**

```bash
git add backend/src/modules/caja backend/tests/caja.test.js
git commit -m "feat(caja): scope cash sessions by sucursal, one open session per branch"
```

---

### Task 6: Ventas por sucursal + salas de socket.io

**Files:**
- Modify: `backend/src/modules/ventas/ventas.service.js`
- Modify: `backend/src/modules/ventas/ventas.controller.js`
- Modify: `backend/src/modules/ventas/ventas.routes.js`
- Modify: `backend/src/socket.js`
- Test: `backend/tests/ventas.test.js`

**Interfaces:**
- Consumes: `ajustarStockSucursal` (Task 3), `requiereSucursalActiva` (Task 3).
- Produces: `emitir(evento, datos, sucursal_id)` — new third parameter; when provided, scopes the emit to socket room `sucursal:<id>`. `crear()`/`crearCompleta()`/`cobrar()` copy `sucursal_id` from the pedido's cash session and use it both for the stock check/adjustment and for scoping the socket emit.

- [ ] **Step 1: Write the failing tests**

```javascript
// backend/tests/ventas.test.js — append to the existing file
const { Sucursal, Area, Mesa, Categoria, Producto, ProductoStockSucursal, Usuario, Rol, SesionCaja } = require('../src/models');
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npx jest tests/ventas.test.js` (from `backend/`)
Expected: FAIL — `pedidos.sucursal_id` not set (column is `NOT NULL`, `Pedido.create` throws or the field is missing from the response), stock in `producto_stock_sucursal` unchanged (the sale still writes to `productos.stock` directly).

- [ ] **Step 3: Update `ventas.service.js`**

Replace the imports at the top:

```javascript
const { Op } = require('sequelize');
const { Pedido, DetallePedido, Mesa, Producto, Cliente, SesionCaja, LibroCaja, Configuracion, sequelize } = require('../../models');
const { emitir } = require('../../socket');
const { ajustarStockSucursal } = require('../inventario/stock.service');
```

(`RegistroInventario` is no longer imported directly here — `ajustarStockSucursal` creates it.)

Update `listar`/`listarCocina` to accept and apply scope:

```javascript
async function listar({ estado, mesa_id, sucursal_id, acceso_todas } = {}) {
  const where = {};
  if (estado) {
    where.estado = estado.includes(',') ? { [Op.in]: estado.split(',') } : estado;
  }
  if (mesa_id) where.mesa_id = mesa_id;
  if (!acceso_todas) where.sucursal_id = sucursal_id;
  return Pedido.findAll({ where, include: INCLUDE_PEDIDO_COMPLETO, order: [['creado_en', 'DESC']] });
}

async function listarCocina({ sucursal_id, acceso_todas } = {}) {
  const where = { estado: { [Op.in]: ['pendiente', 'listo'] } };
  if (!acceso_todas) where.sucursal_id = sucursal_id;
  return Pedido.findAll({
    where,
    include: INCLUDE_PEDIDO_COMPLETO,
    order: [['creado_en', 'ASC']],
  });
}
```

In `crear()`, after the existing `sesionActiva` validation (which stays as-is), read `sesionActiva.sucursal_id` and pass it into both `Pedido.create` calls (mesa and llevar branches) and into the `emitir` calls:

```javascript
async function crear({ mesa_id, tipo = 'mesa', usuario_id, cliente_id, sesion_caja_id, notas, nombre_cliente, documento_cliente, tipo_documento }) {
  if (!sesion_caja_id) {
    throw Object.assign(new Error('No hay caja abierta. Abre la caja antes de crear una orden.'), { status: 409 });
  }
  const sesionActiva = await SesionCaja.findByPk(sesion_caja_id);
  if (!sesionActiva || sesionActiva.estado !== 'abierta') {
    throw Object.assign(new Error('La sesión de caja no está abierta.'), { status: 409 });
  }
  const sucursal_id = sesionActiva.sucursal_id;

  if (tipo === 'mesa') {
    const mesa = await Mesa.findByPk(mesa_id);
    if (!mesa) throw Object.assign(new Error('Mesa no encontrada'), { status: 404 });

    const pedido = await Pedido.create({
      mesa_id, tipo: 'mesa', usuario_id, cliente_id, sesion_caja_id, sucursal_id, notas,
      nombre_cliente: nombre_cliente || 'Público General',
      documento_cliente,
      tipo_documento: tipo_documento || 'Ticket',
    });
    await mesa.update({ estado: 'ocupada' });
    const resultado = await obtener(pedido.id);
    emitir('restaurante:actualizar', { tipo: 'pedido_nuevo' }, sucursal_id);
    return resultado;
  }

  // tipo === 'llevar'
  const numero_llevar = await _siguienteNumeroLlevar();
  const pedido = await Pedido.create({
    mesa_id: null, tipo: 'llevar', numero_llevar, usuario_id, cliente_id, sesion_caja_id, sucursal_id, notas,
    nombre_cliente: nombre_cliente || 'Cliente',
    documento_cliente,
    tipo_documento: tipo_documento || 'Ticket',
  });
  const resultado = await obtener(pedido.id);
  emitir('restaurante:actualizar', { tipo: 'pedido_nuevo' }, sucursal_id);
  return resultado;
}
```

In `crearCompleta()`: replace the stock-sufficiency pre-check loop, the `Pedido.create` call, the per-item stock-deduction block inside the transaction, and the `emitir` calls:

```javascript
async function crearCompleta({ tipo, mesa_id, nombre_cliente, documento_cliente, tipo_documento, items, metodo_pago, monto_recibido, descuento = 0, propina = 0, sesion_caja_id, usuario_id }) {
  if (!sesion_caja_id) {
    throw Object.assign(new Error('No hay caja abierta. Abre la caja antes de crear una orden.'), { status: 409 });
  }
  const sesionActiva = await SesionCaja.findByPk(sesion_caja_id);
  if (!sesionActiva || sesionActiva.estado !== 'abierta') {
    throw Object.assign(new Error('La sesión de caja no está abierta.'), { status: 409 });
  }
  const sucursal_id = sesionActiva.sucursal_id;

  if (!items || items.length === 0) {
    throw Object.assign(new Error('El pedido no tiene productos'), { status: 409 });
  }

  const productos = [];
  for (const item of items) {
    const producto = await Producto.findByPk(item.producto_id);
    if (!producto) throw Object.assign(new Error('Producto no encontrado'), { status: 404 });
    if (!producto.activo || !producto.es_vendible) throw Object.assign(new Error('Producto no disponible'), { status: 409 });
    productos.push({ item, producto });
  }

  let mesa = null;
  if (tipo === 'mesa') {
    if (!mesa_id) throw Object.assign(new Error('mesa_id es requerido'), { status: 400 });
    mesa = await Mesa.findByPk(mesa_id);
    if (!mesa) throw Object.assign(new Error('Mesa no encontrada'), { status: 404 });
    if (mesa.estado !== 'disponible') throw Object.assign(new Error('Mesa ya ocupada'), { status: 409 });
  } else if (tipo !== 'llevar') {
    throw Object.assign(new Error("tipo debe ser 'mesa' o 'llevar'"), { status: 400 });
  }

  const total = productos.reduce((sum, { item, producto }) => sum + item.cantidad * parseFloat(producto.precio), 0);
  const monto_neto = total - parseFloat(descuento) + parseFloat(propina);

  if (metodo_pago === 'efectivo') {
    if (!monto_recibido || parseFloat(monto_recibido) < monto_neto) {
      throw Object.assign(new Error('Monto recibido insuficiente'), { status: 400 });
    }
  }
  const cambio = metodo_pago === 'efectivo' ? parseFloat(monto_recibido) - monto_neto : 0;

  const numero_llevar = tipo === 'llevar' ? await _siguienteNumeroLlevar() : null;

  const pedidoId = await sequelize.transaction(async (t) => {
    const pedido = await Pedido.create({
      mesa_id: tipo === 'mesa' ? mesa_id : null,
      tipo, numero_llevar, usuario_id, sesion_caja_id, sucursal_id,
      estado: 'completado', total, descuento, propina, metodo_pago,
      monto_recibido: monto_recibido || monto_neto, cambio,
      nombre_cliente: nombre_cliente || (tipo === 'llevar' ? 'Cliente' : 'Público General'),
      documento_cliente,
      tipo_documento: tipo_documento || 'Ticket',
    }, { transaction: t });

    for (const { item, producto } of productos) {
      await DetallePedido.create({
        pedido_id: pedido.id, producto_id: item.producto_id, cantidad: item.cantidad, precio: producto.precio, nota: item.nota,
      }, { transaction: t });

      if (producto.stock !== null) {
        await ajustarStockSucursal({
          producto_id: item.producto_id, sucursal_id, tipo: 'venta', cantidad: item.cantidad,
          usuario_id, nota: `Venta #${pedido.id}`, transaction: t,
        });
      }
    }

    await LibroCaja.create({
      sesion_caja_id, usuario_id, tipo: 'ingreso', concepto: `Venta #${pedido.id}`, monto: monto_neto, metodo_pago, referencia_id: pedido.id,
    }, { transaction: t });

    await SesionCaja.increment('total_ventas', { by: monto_neto, where: { id: sesion_caja_id }, transaction: t });

    return pedido.id;
  });

  const creado = await obtener(pedidoId);
  emitir('restaurante:actualizar', { tipo: 'pedido_cobrado' }, sucursal_id);

  const cfgRows = await Configuracion.findAll({ where: { clave: ['nombre_negocio', 'simbolo_moneda', 'direccion', 'telefono', 'flujo_cocina'] } });
  const cfg = cfgRows.reduce((o, r) => { o[r.clave] = r.valor; return o; }, {});

  const inicioDia = new Date(); inicioDia.setHours(0, 0, 0, 0);
  const finDia    = new Date(); finDia.setHours(23, 59, 59, 999);
  const numero_orden_diario = await Pedido.count({
    where: { creado_en: { [Op.between]: [inicioDia, finDia] }, estado: { [Op.ne]: 'cancelado' } },
  });

  emitir('print:caja', { pedido: creado.toJSON(), metodo_pago, cambio, config: cfg, numero_orden_diario }, sucursal_id);
  if (cfg.flujo_cocina === 'fisico') {
    emitir('print:cocina', { pedido: creado.toJSON(), config: cfg, numero_orden_diario }, sucursal_id);
  }
  return creado;
}
```

**Important:** `crearCompleta`'s pre-check loop no longer validates `producto.stock < item.cantidad` against the global column (removed) — the insufficiency check now happens inside `ajustarStockSucursal` itself (it throws 409 when the branch's row doesn't have enough), which runs inside the same `sequelize.transaction` (note the `transaction: t` passed above — this keeps the stock adjustment atomic with the rest of the sale, same as the original code's behavior). This is a deliberate, correct behavior change: stock sufficiency must be checked against the *branch's* quantity, not the global total.

In `cobrar()`: replace the stock pre-check loop and the per-item stock-deduction block inside the transaction, and add `sucursal_id` (read from `pedido.sucursal_id`, already loaded via `INCLUDE_PEDIDO_COMPLETO`... actually `sucursal_id` is a plain column on `Pedido`, available directly as `pedido.sucursal_id` without needing an include) to every `emitir` call:

```javascript
async function cobrar(pedido_id, usuario_id, { metodo_pago, monto_recibido, descuento = 0, propina = 0 }) {
  const pedido = await Pedido.findByPk(pedido_id, { include: INCLUDE_PEDIDO_COMPLETO });
  if (!pedido) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  if (!['pendiente', 'listo'].includes(pedido.estado)) throw Object.assign(new Error('El pedido no puede cobrarse'), { status: 409 });
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

  await sequelize.transaction(async (t) => {
    await pedido.update({
      estado: 'completado', metodo_pago, monto_recibido: monto_recibido || monto_neto, cambio, descuento, propina,
    }, { transaction: t });

    if (pedido.tipo !== 'llevar' && pedido.mesa_id) {
      const pendientes = await Pedido.count({ where: { mesa_id: pedido.mesa_id, estado: 'pendiente' }, transaction: t });
      if (pendientes === 0) {
        await Mesa.update({ estado: 'disponible' }, { where: { id: pedido.mesa_id }, transaction: t });
      }
    }

    await LibroCaja.create({
      sesion_caja_id: pedido.sesion_caja_id, usuario_id, tipo: 'ingreso', concepto: `Venta #${pedido.id}`, monto: monto_neto, metodo_pago, referencia_id: pedido.id,
    }, { transaction: t });

    await SesionCaja.increment('total_ventas', { by: monto_neto, where: { id: pedido.sesion_caja_id }, transaction: t });

    for (const detalle of pedido.detalles) {
      const producto = await Producto.findByPk(detalle.producto_id, { transaction: t });
      if (producto && producto.stock !== null) {
        await ajustarStockSucursal({
          producto_id: detalle.producto_id, sucursal_id: pedido.sucursal_id, tipo: 'venta', cantidad: detalle.cantidad,
          usuario_id, nota: `Venta #${pedido.id}`, transaction: t,
        });
      }
    }
  });

  const cobrado = await obtener(pedido_id);
  emitir('restaurante:actualizar', { tipo: 'pedido_cobrado' }, pedido.sucursal_id);

  const cfgRows = await Configuracion.findAll({ where: { clave: ['nombre_negocio', 'simbolo_moneda', 'direccion', 'telefono', 'flujo_cocina'] } });
  const cfg = cfgRows.reduce((o, r) => { o[r.clave] = r.valor; return o; }, {});

  const inicioDia = new Date(); inicioDia.setHours(0, 0, 0, 0);
  const finDia    = new Date(); finDia.setHours(23, 59, 59, 999);
  const numero_orden_diario = await Pedido.count({
    where: { creado_en: { [Op.between]: [inicioDia, finDia] }, estado: { [Op.ne]: 'cancelado' } },
  });

  emitir('print:caja', { pedido: cobrado.toJSON(), metodo_pago, cambio, config: cfg, numero_orden_diario }, pedido.sucursal_id);
  if (cfg.flujo_cocina === 'fisico') {
    emitir('print:cocina', { pedido: cobrado.toJSON(), config: cfg, numero_orden_diario }, pedido.sucursal_id);
  }
  return cobrado;
}
```

**Note:** every `ajustarStockSucursal` call inside `crearCompleta`'s and `cobrar`'s `sequelize.transaction(...)` blocks passes `transaction: t` (see the code above), so the stock adjustment commits or rolls back atomically with the rest of the sale — same atomicity guarantee as the original pre-Fase-2 code (which called `producto.update({ stock }, { transaction: t })` directly).

Leave `agregarItem`, `actualizarItem`, `eliminarItem`, `cancelar`, `marcarListo`, `_recalcularTotal` exactly as they are — none of them touch stock or sucursal_id.

- [ ] **Step 4: Update `ventas.controller.js`**

Only `listar`, `crear`, and `crearCompleta` need the scope threaded through; `listarCocina` too:

```javascript
async function listar(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listar({ ...req.query, sucursal_id: req.usuario.sucursal_id, acceso_todas: req.usuario.acceso_todas }) }); }
  catch (err) { next(err); }
}
```

```javascript
async function listarCocina(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listarCocina({ sucursal_id: req.usuario.sucursal_id, acceso_todas: req.usuario.acceso_todas }) }); }
  catch (err) { next(err); }
}
```

`crear` and `crearCompleta` don't need changes — `sucursal_id` is now derived server-side inside the service from the cash session, never from `req.body`/`req.usuario` directly in the controller. Leave the rest of `ventas.controller.js` untouched.

- [ ] **Step 5: Add `requiereSucursalActiva` to the write routes in `ventas.routes.js`**

```javascript
// backend/src/modules/ventas/ventas.routes.js
const { Router } = require('express');
const ctrl = require('./ventas.controller');
const auth = require('../../middlewares/auth');
const { verificarPermiso } = require('../../middlewares/permisos');
const { requiereSucursalActiva } = require('../../middlewares/sucursalActiva');

const router = Router();
router.use(auth);

router.get('/cocina', verificarPermiso('ventas', 'ver'), ctrl.listarCocina);
router.get('/', verificarPermiso('ventas', 'ver'), ctrl.listar);
router.post('/', verificarPermiso('ventas', 'crear'), requiereSucursalActiva, ctrl.crear);
router.post('/completa', verificarPermiso('ventas', 'crear'), requiereSucursalActiva, ctrl.crearCompleta);
router.get('/:id', verificarPermiso('ventas', 'ver'), ctrl.obtener);
router.post('/:id/items', verificarPermiso('ventas', 'crear'), ctrl.agregarItem);
router.put('/:id/items/:item_id', verificarPermiso('ventas', 'crear'), ctrl.actualizarItem);
router.delete('/:id/items/:item_id', verificarPermiso('ventas', 'crear'), ctrl.eliminarItem);
router.post('/:id/cobrar', verificarPermiso('ventas', 'cobrar'), requiereSucursalActiva, ctrl.cobrar);
router.post('/:id/cancelar', verificarPermiso('ventas', 'cancelar'), ctrl.cancelar);
router.patch('/:id/listo', verificarPermiso('ventas', 'ver'), ctrl.marcarListo);

module.exports = router;
```

- [ ] **Step 6: Add socket.io rooms in `socket.js`**

```javascript
// backend/src/socket.js
const { Server } = require('socket.io');

let _io = null;

function init(server) {
  const allowedOrigins = (process.env.CORS_ORIGIN || 'http://localhost:5173')
    .split(',')
    .map(o => o.trim());

  _io = new Server(server, {
    cors: {
      origin: (origin, cb) => {
        if (!origin || allowedOrigins.includes(origin)) return cb(null, true);
        cb(new Error('socket.io CORS: ' + origin));
      },
      methods: ['GET', 'POST'],
    },
  });
  _io.on('connection', (socket) => {
    console.log('Socket conectado:', socket.id);
    socket.on('unirse_sucursal', (sucursal_id) => {
      if (sucursal_id) socket.join(`sucursal:${sucursal_id}`);
    });
    socket.on('disconnect', () => console.log('Socket desconectado:', socket.id));
  });
  return _io;
}

function emitir(evento, datos = {}, sucursal_id = null) {
  if (!_io) return;
  if (sucursal_id) {
    _io.to(`sucursal:${sucursal_id}`).emit(evento, datos);
  } else {
    _io.emit(evento, datos);
  }
}

module.exports = { init, emitir };
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `npx jest tests/ventas.test.js` (from `backend/`)
Expected: PASS.

- [ ] **Step 8: Run the full suite to check for regressions**

Run: `npm test` (from `backend/`)
Expected: all suites pass. Pay attention to any other test file that creates a `Pedido`, `SesionCaja` or `Compra` row directly (bypassing the API) — it must now also pass `sucursal_id` or the `NOT NULL` constraint will throw. Search: `grep -rn "SesionCaja.create\|Pedido.create\|Compra.create" backend/tests/` and fix any pre-existing test fixture that doesn't already supply `sucursal_id` (this plan's own new tests already do; check for others from earlier suites, e.g. `reservaciones.test.js` or `configuracion.test.js`, that might incidentally create these rows).

- [ ] **Step 9: Commit**

```bash
git add backend/src/modules/ventas backend/src/socket.js backend/tests/ventas.test.js
git commit -m "feat(ventas): scope orders by sucursal, per-branch stock deduction, socket rooms"
```

---

### Task 7: Compras por sucursal

**Files:**
- Modify: `backend/src/modules/compras/compras.service.js`
- Modify: `backend/src/modules/compras/compras.controller.js`
- Modify: `backend/src/modules/compras/compras.routes.js`
- Test: `backend/tests/compras.test.js`

**Interfaces:**
- Consumes: `ajustarStockSucursal` (Task 3), `requiereSucursalActiva` (Task 3).
- Produces: `crearCompra(usuario_id, sucursal_id, datos)` records `sucursal_id`. `listarCompras(alcance)` filters unless `acceso_todas`. `recibirCompra` adjusts stock via `ajustarStockSucursal` against the compra's own `sucursal_id`.

- [ ] **Step 1: Write the failing tests**

```javascript
// backend/tests/compras.test.js — append to the existing file
const { Sucursal, Proveedor, Categoria, Producto, ProductoStockSucursal } = require('../src/models');

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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npx jest tests/compras.test.js` (from `backend/`)
Expected: FAIL — `compras.sucursal_id` `NOT NULL` violation on `Compra.create` (column not populated yet).

- [ ] **Step 3: Update `compras.service.js`**

Replace the imports and the three affected functions; leave `listarProveedores`, `crearProveedor`, `actualizarProveedor`, `desactivarProveedor`, `obtenerCompra`, `actualizarCompra` exactly as they are:

```javascript
const { Proveedor, Compra, DetalleCompra, Producto, sequelize } = require('../../models');
const { ajustarStockSucursal } = require('../inventario/stock.service');
```

```javascript
async function listarCompras(alcance = {}) {
  const where = alcance.acceso_todas ? {} : { sucursal_id: alcance.sucursal_id };
  return Compra.findAll({ where, include: INCLUDE_COMPRA, order: [['creado_en', 'DESC']] });
}
```

```javascript
async function crearCompra(usuario_id, sucursal_id, { proveedor_id, notas, items = [] }) {
  const proveedor = await Proveedor.findByPk(proveedor_id);
  if (!proveedor) throw Object.assign(new Error('Proveedor no encontrado'), { status: 404 });

  const total = items.reduce((sum, i) => sum + (parseFloat(i.costo_unitario) * parseInt(i.cantidad)), 0);

  const compra = await Compra.create({ proveedor_id, usuario_id, sucursal_id, total, notas });

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
```

```javascript
async function recibirCompra(id, usuario_id) {
  const compra = await Compra.findByPk(id, { include: INCLUDE_COMPRA });
  if (!compra) throw Object.assign(new Error('Compra no encontrada'), { status: 404 });
  if (compra.estado !== 'pendiente') throw Object.assign(new Error('La compra ya fue recibida'), { status: 409 });

  await sequelize.transaction(async (t) => {
    for (const detalle of compra.detalles) {
      await ajustarStockSucursal({
        producto_id: detalle.producto_id, sucursal_id: compra.sucursal_id, tipo: 'compra', cantidad: detalle.cantidad,
        usuario_id, nota: `Compra #${compra.id}`, transaction: t,
      });
    }
    await compra.update({ estado: 'recibido' }, { transaction: t });
  });

  return obtenerCompra(id);
}
```

Note: `recibirCompra` keeps wrapping its work in `sequelize.transaction`, same as the original pre-Fase-2 code — `ajustarStockSucursal` now accepts an optional `transaction` (Task 3), so every stock adjustment commits or rolls back atomically with the compra's `estado: 'recibido'` update.

- [ ] **Step 4: Update `compras.controller.js`**

Only `listarCompras` and `crearCompra` change:

```javascript
async function listarCompras(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listarCompras({ sucursal_id: req.usuario.sucursal_id, acceso_todas: req.usuario.acceso_todas }) }); }
  catch (err) { next(err); }
}
```

```javascript
async function crearCompra(req, res, next) {
  try {
    const { proveedor_id, items } = req.body;
    if (!proveedor_id || !items || !items.length) {
      return res.status(400).json({ ok: false, mensaje: 'proveedor_id e items son requeridos' });
    }
    res.status(201).json({ ok: true, datos: await svc.crearCompra(req.usuario.id, req.usuario.sucursal_id, req.body) });
  } catch (err) { next(err); }
}
```

Leave the rest of `compras.controller.js` untouched.

- [ ] **Step 5: Add `requiereSucursalActiva` to `compras.routes.js`**

```javascript
// backend/src/modules/compras/compras.routes.js
const { Router } = require('express');
const ctrl = require('./compras.controller');
const auth = require('../../middlewares/auth');
const { verificarPermiso } = require('../../middlewares/permisos');
const { requiereSucursalActiva } = require('../../middlewares/sucursalActiva');

const router = Router();
router.use(auth);

router.get('/', verificarPermiso('compras', 'ver'), ctrl.listarCompras);
router.post('/', verificarPermiso('compras', 'crear'), requiereSucursalActiva, ctrl.crearCompra);
router.get('/:id', verificarPermiso('compras', 'ver'), ctrl.obtenerCompra);
router.put('/:id', verificarPermiso('compras', 'editar'), ctrl.actualizarCompra);
router.put('/:id/recibir', verificarPermiso('compras', 'recibir'), requiereSucursalActiva, ctrl.recibirCompra);

module.exports = router;
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `npx jest tests/compras.test.js` (from `backend/`)
Expected: PASS.

- [ ] **Step 7: Run the full suite to check for regressions**

Run: `npm test` (from `backend/`)
Expected: all suites pass.

- [ ] **Step 8: Commit**

```bash
git add backend/src/modules/compras backend/tests/compras.test.js
git commit -m "feat(compras): scope purchases by sucursal, receive into branch stock"
```

---

### Task 8: Inventario manual por sucursal

**Files:**
- Modify: `backend/src/modules/inventario/inventario.service.js`
- Modify: `backend/src/modules/inventario/inventario.controller.js`
- Modify: `backend/src/modules/inventario/inventario.routes.js`
- Test: `backend/tests/inventario.test.js`

**Interfaces:**
- Consumes: `ajustarStockSucursal` (Task 3), `requiereSucursalActiva` (Task 3).
- Produces: `entrada`/`salida`/`ajuste` take `sucursal_id` from the authenticated user and delegate to `ajustarStockSucursal` (removing the duplicated `_movimiento` logic). `listar`/`listarPorProducto` filter by sucursal unless `acceso_todas`.

- [ ] **Step 1: Write the failing tests**

```javascript
// backend/tests/inventario.test.js — append to the existing file
const { Sucursal, Categoria, Producto, ProductoStockSucursal } = require('../src/models');

describe('Inventario manual por sucursal', () => {
  let adminToken, producto;

  beforeAll(async () => {
    const login = await request(app).post('/api/v1/auth/login').send({ email: 'admin@restaurante.com', contrasena: process.env.ADMIN_PASSWORD || 'admin123' });
    adminToken = login.body.datos.token;

    const categoria = await Categoria.create({ nombre: 'Categoria Inventario Test' });
    producto = await Producto.create({ categoria_id: categoria.id, nombre: 'Producto Inventario Test', precio: 4, stock: 0 });
  });

  afterAll(async () => {
    await ProductoStockSucursal.destroy({ where: { producto_id: producto.id } });
    await Producto.destroy({ where: { id: producto.id } });
  });

  it('una entrada manual va al stock de la sucursal activa del admin', async () => {
    const res = await request(app)
      .post('/api/v1/inventario/entrada')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ producto_id: producto.id, cantidad: 20, nota: 'Entrada test' });

    expect(res.status).toBe(201);

    const principal = await Sucursal.findOne({ where: { nombre: 'Sucursal Principal' } });
    const fila = await ProductoStockSucursal.findOne({ where: { producto_id: producto.id, sucursal_id: principal.id } });
    expect(fila.stock).toBe(20);
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npx jest tests/inventario.test.js` (from `backend/`)
Expected: FAIL — `producto_stock_sucursal` row not created (the endpoint still writes to `productos.stock` directly via the old `_movimiento`).

- [ ] **Step 3: Rewrite `inventario.service.js`**

```javascript
// backend/src/modules/inventario/inventario.service.js
const { RegistroInventario, Producto, Usuario } = require('../../models');
const { ajustarStockSucursal } = require('./stock.service');

const INCLUDE_REGISTRO = [
  { model: Producto, as: 'producto', attributes: ['id', 'nombre', 'stock'] },
  { model: Usuario, as: 'usuario', attributes: ['id', 'nombre'] },
];

async function listar({ producto_id, sucursal_id, acceso_todas } = {}) {
  const where = {};
  if (producto_id) where.producto_id = producto_id;
  if (!acceso_todas) where.sucursal_id = sucursal_id;
  return RegistroInventario.findAll({ where, include: INCLUDE_REGISTRO, order: [['creado_en', 'DESC']], limit: 200 });
}

async function listarPorProducto(producto_id, { sucursal_id, acceso_todas } = {}) {
  const producto = await Producto.findByPk(producto_id);
  if (!producto) throw Object.assign(new Error('Producto no encontrado'), { status: 404 });
  const where = { producto_id };
  if (!acceso_todas) where.sucursal_id = sucursal_id;
  return RegistroInventario.findAll({
    where,
    include: INCLUDE_REGISTRO,
    order: [['creado_en', 'DESC']],
  });
}

async function entrada(usuario_id, sucursal_id, { producto_id, cantidad, nota }) {
  return ajustarStockSucursal({ producto_id, sucursal_id, tipo: 'entrada', cantidad, usuario_id, nota });
}

async function salida(usuario_id, sucursal_id, { producto_id, cantidad, nota }) {
  return ajustarStockSucursal({ producto_id, sucursal_id, tipo: 'salida', cantidad, usuario_id, nota });
}

async function ajuste(usuario_id, sucursal_id, { producto_id, cantidad, nota }) {
  return ajustarStockSucursal({ producto_id, sucursal_id, tipo: 'ajuste', cantidad, usuario_id, nota });
}

module.exports = { listar, listarPorProducto, entrada, salida, ajuste };
```

- [ ] **Step 4: Update `inventario.controller.js`**

```javascript
// backend/src/modules/inventario/inventario.controller.js
const svc = require('./inventario.service');

function _alcance(req) {
  return { sucursal_id: req.usuario.sucursal_id, acceso_todas: req.usuario.acceso_todas };
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
    res.status(201).json({ ok: true, datos: await svc.entrada(req.usuario.id, req.usuario.sucursal_id, req.body) });
  } catch (err) { next(err); }
}

async function salida(req, res, next) {
  try {
    const { producto_id, cantidad } = req.body;
    if (!producto_id || !cantidad) return res.status(400).json({ ok: false, mensaje: 'producto_id y cantidad son requeridos' });
    res.status(201).json({ ok: true, datos: await svc.salida(req.usuario.id, req.usuario.sucursal_id, req.body) });
  } catch (err) { next(err); }
}

async function ajuste(req, res, next) {
  try {
    const { producto_id, cantidad } = req.body;
    if (!producto_id || cantidad === undefined) return res.status(400).json({ ok: false, mensaje: 'producto_id y cantidad son requeridos' });
    res.status(201).json({ ok: true, datos: await svc.ajuste(req.usuario.id, req.usuario.sucursal_id, req.body) });
  } catch (err) { next(err); }
}

module.exports = { listar, listarPorProducto, entrada, salida, ajuste };
```

- [ ] **Step 5: Add `requiereSucursalActiva` to `inventario.routes.js`**

```javascript
// backend/src/modules/inventario/inventario.routes.js
const { Router } = require('express');
const ctrl = require('./inventario.controller');
const auth = require('../../middlewares/auth');
const { verificarPermiso } = require('../../middlewares/permisos');
const { requiereSucursalActiva } = require('../../middlewares/sucursalActiva');

const router = Router();
router.use(auth);

router.get('/', verificarPermiso('inventario', 'ver'), ctrl.listar);
router.get('/producto/:id', verificarPermiso('inventario', 'ver'), ctrl.listarPorProducto);
router.post('/entrada', verificarPermiso('inventario', 'entrada'), requiereSucursalActiva, ctrl.entrada);
router.post('/salida', verificarPermiso('inventario', 'salida'), requiereSucursalActiva, ctrl.salida);
router.post('/ajuste', verificarPermiso('inventario', 'ajustar'), requiereSucursalActiva, ctrl.ajuste);

module.exports = router;
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `npx jest tests/inventario.test.js` (from `backend/`)
Expected: PASS.

- [ ] **Step 7: Run the full suite to check for regressions**

Run: `npm test` (from `backend/`)
Expected: all suites pass.

- [ ] **Step 8: Commit**

```bash
git add backend/src/modules/inventario/inventario.service.js backend/src/modules/inventario/inventario.controller.js backend/src/modules/inventario/inventario.routes.js backend/tests/inventario.test.js
git commit -m "feat(inventario): manual stock movements scoped by sucursal, reuse centralized adjuster"
```

---

### Task 9: Productos — stock por sucursal en listados y alta

**Files:**
- Modify: `backend/src/modules/productos/productos.service.js`
- Modify: `backend/src/modules/productos/productos.controller.js`
- Test: `backend/tests/productos.test.js`

**Interfaces:**
- Consumes: `ajustarStockSucursal`, `mezclarStockPorSucursal` (Task 3).
- Produces: `listarProductos(filtros, alcance)`/`obtenerProducto(id, alcance)` return each product's `stock` overridden to the caller's branch quantity (or the aggregate + `stock_por_sucursal` breakdown in `acceso_todas` mode). `crearProducto` routes any initial `stock` through `ajustarStockSucursal` instead of writing the column directly; ignores it in `acceso_todas` mode.

- [ ] **Step 1: Write the failing tests**

```javascript
// backend/tests/productos.test.js — append to the existing file (check the file first for its current imports/describe structure and compose accordingly)
const { Sucursal, ProductoStockSucursal } = require('../src/models');

describe('Stock de productos por sucursal', () => {
  let adminToken, categoriaId, sucursalPrincipalId;

  beforeAll(async () => {
    const login = await request(app).post('/api/v1/auth/login').send({ email: 'admin@restaurante.com', contrasena: process.env.ADMIN_PASSWORD || 'admin123' });
    adminToken = login.body.datos.token;
    const principal = await Sucursal.findOne({ where: { nombre: 'Sucursal Principal' } });
    sucursalPrincipalId = principal.id;

    const catRes = await request(app)
      .post('/api/v1/categorias')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ nombre: 'Categoria Stock Productos Test' });
    categoriaId = catRes.body.datos.id;
  });

  it('crear un producto con stock inicial lo asigna a la sucursal activa del creador', async () => {
    const res = await request(app)
      .post('/api/v1/productos')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ categoria_id: categoriaId, nombre: 'Producto Stock Inicial Test', precio: 12, stock: 30 });

    expect(res.status).toBe(201);

    const fila = await ProductoStockSucursal.findOne({ where: { producto_id: res.body.datos.id, sucursal_id: sucursalPrincipalId } });
    expect(fila.stock).toBe(30);
  });

  it('el listado muestra el stock de la sucursal activa del usuario que consulta', async () => {
    const res = await request(app)
      .get('/api/v1/productos')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(200);
    const creado = res.body.datos.find(p => p.nombre === 'Producto Stock Inicial Test');
    expect(creado.stock).toBe(30);
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npx jest tests/productos.test.js` (from `backend/`)
Expected: FAIL — no `producto_stock_sucursal` row is created (stock still goes straight into `productos.stock`).

- [ ] **Step 3: Update `productos.service.js`**

Only the `Producto` section changes; leave `listarCategorias`, `crearCategoria`, `actualizarCategoria`, `eliminarCategoria` untouched. Update the imports and the four affected functions:

```javascript
const { Categoria, Producto } = require('../../models');
const sequelize = require('../../config/database');
const { ajustarStockSucursal, mezclarStockPorSucursal } = require('../inventario/stock.service');
```

```javascript
async function listarProductos({ categoria_id, solo_vendibles, order_by } = {}, alcance) {
  const where = { activo: 1 };
  if (categoria_id) where.categoria_id = categoria_id;
  if (solo_vendibles === 'true' || solo_vendibles === true) where.es_vendible = 1;

  const order = order_by === 'mas_vendido'
    ? [
        [sequelize.literal('(SELECT COALESCE(SUM(cantidad), 0) FROM detalle_pedidos WHERE producto_id = `Producto`.`id`)'), 'DESC'],
        ['nombre', 'ASC'],
      ]
    : [['nombre', 'ASC']];

  const productos = await Producto.findAll({
    where,
    include: [{ model: Categoria, as: 'categoria', attributes: ['id', 'nombre'] }],
    order,
  });

  return mezclarStockPorSucursal(productos, alcance);
}

async function obtenerProducto(id, alcance) {
  const p = await Producto.findByPk(id, {
    include: [{ model: Categoria, as: 'categoria', attributes: ['id', 'nombre'] }],
  });
  if (!p) throw Object.assign(new Error('Producto no encontrado'), { status: 404 });
  const [conStock] = await mezclarStockPorSucursal([p], alcance);
  return conStock;
}

async function crearProducto({ categoria_id, nombre, codigo_barras, codigo, precio, costo, stock, es_vendible, imagen }, alcance) {
  const producto = await Producto.create({ categoria_id, nombre, codigo_barras, codigo, precio, costo, stock: stock !== undefined ? 0 : null, es_vendible, imagen });

  if (stock !== undefined && stock !== null && !alcance.acceso_todas) {
    await ajustarStockSucursal({ producto_id: producto.id, sucursal_id: alcance.sucursal_id, tipo: 'ajuste', cantidad: stock, usuario_id: alcance.usuario_id, nota: 'Stock inicial' });
  }

  return obtenerProducto(producto.id, alcance);
}
```

Leave `actualizarProducto` and `eliminarProducto` as they are (editing price/name/category doesn't touch stock in this phase — stock changes only via entrada/salida/ajuste/venta/compra).

- [ ] **Step 4: Update `productos.controller.js`**

Read the current file first (not shown in this brief) to find `listarProductos`, `obtenerProducto`, `crearProducto` — thread the scope through each:

```javascript
function _alcance(req) {
  return { sucursal_id: req.usuario.sucursal_id, acceso_todas: req.usuario.acceso_todas, usuario_id: req.usuario.id };
}
```

```javascript
async function listarProductos(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listarProductos(req.query, _alcance(req)) }); }
  catch (err) { next(err); }
}
```

```javascript
async function obtenerProducto(req, res, next) {
  try { res.json({ ok: true, datos: await svc.obtenerProducto(req.params.id, _alcance(req)) }); }
  catch (err) { next(err); }
}
```

```javascript
async function crearProducto(req, res, next) {
  try {
    if (!req.body.nombre || !req.body.categoria_id || req.body.precio === undefined) {
      return res.status(400).json({ ok: false, mensaje: 'nombre, categoria_id y precio son requeridos' });
    }
    res.status(201).json({ ok: true, datos: await svc.crearProducto(req.body, _alcance(req)) });
  } catch (err) { next(err); }
}
```

Leave every other exported controller function (categorías, `actualizarProducto`, `eliminarProducto`) exactly as-is — only replace the three functions above and add the `_alcance` helper at the top of the file (above the first function that uses it).

- [ ] **Step 5: Run the tests to verify they pass**

Run: `npx jest tests/productos.test.js` (from `backend/`)
Expected: PASS.

- [ ] **Step 6: Run the full suite to check for regressions**

Run: `npm test` (from `backend/`)
Expected: all suites pass — pay special attention to any pre-existing `productos.test.js` assertions about `stock` shape/value, since `crearProducto`'s behavior for `stock` changed (it's no longer written straight to the column when a sucursal is active).

- [ ] **Step 7: Commit**

```bash
git add backend/src/modules/productos backend/tests/productos.test.js
git commit -m "feat(productos): per-sucursal stock in listings and on creation"
```

---

### Task 10: Reportes de ventas e inventario filtrados por sucursal

**Files:**
- Modify: `backend/src/modules/reportes/reportes.service.js`
- Modify: `backend/src/modules/reportes/reportes.controller.js`
- Test: `backend/tests/reportes.test.js` (create if it doesn't exist — check first)

**Interfaces:**
- Consumes: nothing new from earlier tasks besides `req.usuario.sucursal_id`/`acceso_todas` (Fase 1).
- Produces: `ventas(filtros, alcance)` and `inventario(filtros, alcance)` filter by `sucursal_id` unless `acceso_todas`. `compras` and `caja` reports are NOT touched in this task (out of scope per spec — flag any additional report functions you find in the file that also read from `Pedido`/`RegistroInventario` and weren't covered by the two named above, and ask before extending scope).

- [ ] **Step 1: Check for an existing `reportes.test.js`**

Run: `ls backend/tests/reportes.test.js` (from `backend/`) — if it exists, read it and append; if not, create it with the `describe`/`beforeAll` boilerplate matching the other test files in this plan (supertest + app + admin login).

- [ ] **Step 2: Write the failing tests**

```javascript
// backend/tests/reportes.test.js
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
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `npx jest tests/reportes.test.js` (from `backend/`)
Expected: FAIL — the report includes the other sucursal's pedido (no filter yet).

- [ ] **Step 4: Update `reportes.service.js`**

Only `ventas` and `inventario` change. Read the current file first to see the other functions (`compras`, `caja`) and leave them untouched:

```javascript
async function ventas({ desde, hasta, sucursal_id, acceso_todas } = {}) {
  const where = { estado: 'completado', ...filtroFecha(desde, hasta) };
  if (!acceso_todas) where.sucursal_id = sucursal_id;
  return Pedido.findAll({
    where,
    include: [
      { model: Mesa,    as: 'mesa',    attributes: ['id', 'nombre'] },
      { model: Cliente, as: 'cliente', attributes: ['id', 'nombre'] },
      { model: Usuario, as: 'usuario', attributes: ['id', 'nombre'] },
      {
        model: DetallePedido, as: 'detalles',
        include: [{ model: Producto, as: 'producto', attributes: ['id', 'nombre'] }],
      },
    ],
    order: [['creado_en', 'DESC']],
  });
}

async function inventario({ desde, hasta, sucursal_id, acceso_todas } = {}) {
  const where = filtroFecha(desde, hasta);
  if (!acceso_todas) where.sucursal_id = sucursal_id;
  return RegistroInventario.findAll({
    where,
    include: [
      { model: Producto, as: 'producto', attributes: ['id', 'nombre', 'stock'] },
      { model: Usuario,  as: 'usuario',  attributes: ['id', 'nombre'] },
    ],
    order: [['creado_en', 'DESC']],
  });
}
```

- [ ] **Step 5: Update `reportes.controller.js`**

```javascript
// backend/src/modules/reportes/reportes.controller.js
const svc = require('./reportes.service');

function _alcance(req) {
  return { sucursal_id: req.usuario.sucursal_id, acceso_todas: req.usuario.acceso_todas };
}

async function getVentas(req, res, next) {
  try { res.json({ ok: true, datos: await svc.ventas({ ...req.query, ..._alcance(req) }) }); } catch (e) { next(e); }
}

async function getInventario(req, res, next) {
  try { res.json({ ok: true, datos: await svc.inventario({ ...req.query, ..._alcance(req) }) }); } catch (e) { next(e); }
}

async function getCompras(req, res, next) {
  try { res.json({ ok: true, datos: await svc.compras(req.query) }); } catch (e) { next(e); }
}

async function getCaja(req, res, next) {
  try { res.json({ ok: true, datos: await svc.caja(req.query) }); } catch (e) { next(e); }
}

module.exports = { getVentas, getInventario, getCompras, getCaja };
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `npx jest tests/reportes.test.js` (from `backend/`)
Expected: PASS.

- [ ] **Step 7: Run the full suite to check for regressions**

Run: `npm test` (from `backend/`)
Expected: all suites pass.

- [ ] **Step 8: Commit**

```bash
git add backend/src/modules/reportes backend/tests/reportes.test.js
git commit -m "feat(reportes): scope sales and inventory reports by sucursal"
```

---

### Task 11: Frontend — unirse a la sala de sucursal por socket.io tras el login

**Files:**
- Modify: `frontend/src/socket.js`

**Interfaces:**
- Consumes: `useAuthStore` (existing), backend's `unirse_sucursal` event handler (Task 6).
- Produces: the shared socket instance automatically joins `sucursal:<id>` whenever a user with a concrete `sucursal_activa.id` is authenticated (on login and on page reload with an existing session), and does nothing in `acceso_todas` mode.

- [ ] **Step 1: Update `frontend/src/socket.js`**

```javascript
// frontend/src/socket.js
import { io } from 'socket.io-client';
import { BASE_URL } from './api/configuracion';
import { useAuthStore } from './store/authStore';

const socket = io(BASE_URL, {
  autoConnect: true,
  reconnection: true,
  reconnectionDelay: 1000,
  reconnectionAttempts: Infinity,
});

function unirseSucursalActiva() {
  const sucursalId = useAuthStore.getState().usuario?.sucursal_activa?.id;
  if (sucursalId) socket.emit('unirse_sucursal', sucursalId);
}

// Al reconectar (incluye la primera conexión) y cada vez que cambia el usuario logueado
socket.on('connect', unirseSucursalActiva);
useAuthStore.subscribe((state, prevState) => {
  if (state.usuario?.sucursal_activa?.id !== prevState.usuario?.sucursal_activa?.id) {
    unirseSucursalActiva();
  }
});

export default socket;
```

- [ ] **Step 2: Verify with a compile check**

Run: `npx vite build` (from `frontend/`)
Expected: build succeeds, no errors (confirms `useAuthStore` import/usage and `zustand`'s `.subscribe` API are used correctly — `useAuthStore.subscribe` is available on every zustand store created with `create()`, no extra middleware needed).

- [ ] **Step 3: Commit**

```bash
git add frontend/src/socket.js
git commit -m "feat(frontend): join sucursal socket room on login"
```

---

### Task 12: Frontend — stock por sucursal en ProductosPage

**Files:**
- Modify: `frontend/src/pages/productos/ProductosPage.jsx`

**Interfaces:**
- Consumes: the `stock`/`stock_por_sucursal` shape produced by `mezclarStockPorSucursal` (Task 3/9) in the `GET /productos` response.
- Produces: no visual change for a normal (non-`acceso_todas`) user — `prod.stock` already shows their branch's quantity, same as today. In `acceso_todas` mode, shows a per-branch breakdown instead of a single number.

- [ ] **Step 1: Read the current stock display and the surrounding table cell**

Read `frontend/src/pages/productos/ProductosPage.jsx` around line 316 (`{prod.stock ?? '∞'}`) to see the exact JSX structure of that table cell (column header, surrounding `<td>`, any existing className) before editing — this brief only describes the change, the exact current markup must be confirmed in the real file.

- [ ] **Step 2: Add the per-branch breakdown for `acceso_todas` mode**

Import `useAuthStore` at the top of the file if it isn't already imported:

```javascript
import { useAuthStore } from '../../store/authStore';
```

Inside the component function, near the top (alongside other hooks), read whether the current user is in consolidated mode:

```javascript
  const accesoTodas = useAuthStore((s) => s.usuario?.sucursal_activa?.id == null);
```

Replace the stock cell's content (`{prod.stock ?? '∞'}`) with:

```jsx
{prod.stock === null
  ? '∞'
  : accesoTodas && prod.stock_por_sucursal?.length
    ? (
      <div className="flex flex-col gap-0.5 text-xs">
        {prod.stock_por_sucursal.map(s => (
          <span key={s.sucursal_id}>{s.nombre}: {s.stock}</span>
        ))}
      </div>
    )
    : prod.stock
}
```

(Match this against the actual surrounding JSX/className from Step 1 — the snippet above is the logic to insert, adapt indentation/wrapping `<td>` to what's already there.)

- [ ] **Step 3: Verify with a compile check**

Run: `npx vite build` (from `frontend/`)
Expected: build succeeds, no errors.

- [ ] **Step 4: Commit**

```bash
git add frontend/src/pages/productos/ProductosPage.jsx
git commit -m "feat(frontend): show per-sucursal stock breakdown in acceso-todas mode"
```

---

### Task 13: print-agent — sucursal_id en config y unión a sala

**Files:**
- Modify: `print-agent/config.json`
- Modify: `print-agent/agent.js`

**Interfaces:**
- Consumes: backend's `unirse_sucursal` event handler (Task 6).
- Produces: each print-agent installation, once configured with its `sucursal_id`, only receives `print:caja`/`print:cocina` events for that branch.

- [ ] **Step 1: Add `sucursal_id` to `config.json`**

```json
{
  "servidor": "https://spclizenita.codewave.com.bo",
  "impresora_caja": "POS80 Printer",
  "impresora_cocina": "EPSON TM-T20IV Receipt",
  "sucursal_id": 1
}
```

(The value `1` is a placeholder for local/dev config — the real deployed value for each physical location's `config.json` is whatever numeric id that branch has in the `sucursales` table, set during that location's installation. Read the current `print-agent/config.json` first — the value above must preserve whatever `servidor`/`impresora_*` values are already there, only adding the new key.)

- [ ] **Step 2: Emit `unirse_sucursal` on connect in `agent.js`**

Read `print-agent/agent.js` around the `socket.on('connect', ...)` line (already located at line 60 in the current file) and add the join call immediately after the existing connect handler:

```javascript
socket.on('connect', () => {
  console.log(`[${ts()}] ✓ Conectado (id: ${socket.id})`);
  if (config.sucursal_id) {
    socket.emit('unirse_sucursal', config.sucursal_id);
    console.log(`[${ts()}] → Unido a la sala de la sucursal ${config.sucursal_id}`);
  } else {
    console.log(`[${ts()}] ⚠ config.json no tiene sucursal_id — este agente recibirá eventos de todas las sucursales`);
  }
});
```

(This replaces the existing single-line `socket.on('connect', () => console.log(...))` — read the exact current line first since the brief's earlier context quoted it as one-liner; convert it to the multi-line handler above, keeping the same log message text for the connected case.)

- [ ] **Step 3: Verify with a syntax check**

Run: `node --check agent.js` (from `print-agent/`)
Expected: no output, exit code 0 (confirms valid JS syntax — this project doesn't run the agent automatically in CI, so this is the extent of automated verification available).

- [ ] **Step 4: Commit**

```bash
git add print-agent/config.json print-agent/agent.js
git commit -m "feat(print-agent): join sucursal room so prints stay branch-scoped"
```

---

## Post-plan note (deploy)

Same as Fase 1: this plan only touches the local dev DB. Before this reaches production, migration `013_sucursal_operativa.sql` and `npm run seed` must run against the production DB too. Because Task 1's `ALTER TABLE ... ADD COLUMN ... NOT NULL` will fail on tables that already have rows (which production's `areas`, `sesiones_caja`, `pedidos`, `compras`, `registros_inventario` will), the production deploy sequence must be: (1) apply the migration with the five new columns as nullable, (2) run `npm run seed` to backfill every existing row to "Sucursal Principal", (3) apply a follow-up `ALTER TABLE ... MODIFY sucursal_id INT UNSIGNED NOT NULL` on each of the five tables. Call this out explicitly when Fase 2 is ready to ship — it's a different sequence than Fase 1's deploy (which had no pre-existing rows to worry about on `usuarios_sucursales`, only additive rows).

Also before shipping: each physical location's print-agent `config.json` needs its real `sucursal_id` filled in (matching that branch's row in the `sucursales` table) as part of that location's agent installation/update.
