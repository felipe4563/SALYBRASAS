# Multi-sucursal — Fase 4: Reportes consolidados — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A user in "acceso a todas las sucursales" mode can see which branch each row of Ventas/Inventario/Compras/Caja belongs to, filter any of the four reports down to one branch, and see a per-branch comparison table for each — while a normal single-branch user sees no change at all.

**Architecture:** Backend: the three report queries that already filter by `sucursal_id` (ventas, inventario, compras) get a `Sucursal` include added; the `caja` report (which never filtered — `LibroCaja` has no direct `sucursal_id`) gets rewritten to join through `sesion_caja.sucursal_id` and flatten the result to a top-level `sucursal` field, matching the other three. Frontend: each of the four report tabs gets the same three additions — a "Sucursal" column, a "Sucursal" filter dropdown, and a per-branch summary table — all computed client-side from data already loaded (reports load a full date range in one request; no new endpoints).

**Tech Stack:** Node.js/Express/Sequelize (backend), React 18 + TanStack Query + Zustand (frontend). Backend tests via Jest+Supertest against the real dev DB. No frontend test runner — verification is `vite build` plus manual code tracing.

## Global Constraints

- API envelope `{ ok: true, datos }` / `{ ok: false, mensaje }`.
- `req.usuario.sucursal_id` (number or `null`) / `req.usuario.acceso_todas` (boolean) are already populated on every authenticated request.
- `Pedido`, `RegistroInventario`, `Compra`, `SesionCaja` already have `belongsTo(Sucursal, { foreignKey: 'sucursal_id', as: 'sucursal' })` associations (from an earlier phase) — no model changes needed in this plan.
- `LibroCaja.belongsTo(SesionCaja, { foreignKey: 'sesion_caja_id', as: 'sesion_caja' })` already exists.
- The Sucursal column/filter/summary must only render when `usuario?.sucursal_activa?.id == null` (i.e. `acceso_todas` mode) — a single-branch user sees zero UI changes.
- Backend tests hit the real local dev DB via supertest, no mocking. Run with `npm test` (`jest --runInBand`) from `backend/`. Current baseline: 17 suites / 62 tests passing.
- Frontend verification: `npx vite build` from `frontend/` (no test runner exists in this project).

---

### Task 1: Backend — sucursal en los 4 reportes

**Files:**
- Modify: `backend/src/modules/reportes/reportes.service.js`
- Modify: `backend/src/modules/reportes/reportes.controller.js`
- Test: `backend/tests/reportes.test.js`

**Interfaces:**
- Consumes: existing `Sucursal`/`SesionCaja`/`LibroCaja` associations.
- Produces: every row returned by `ventas`/`inventario`/`compras`/`caja` now includes a top-level `sucursal: { id, nombre }` field (or `null` if somehow missing). `caja(filtros)` now also accepts `sucursal_id`/`acceso_todas` and filters like the other three. Task 2-5 (frontend) consume this `sucursal` field uniformly across all four reports.

- [ ] **Step 1: Write the failing tests**

Append to `backend/tests/reportes.test.js` (the file already has a `describe('Reportes filtrados por sucursal', ...)` block with a `beforeAll` that creates `sucursalOtra`, a `Pedido` in it, and logs in as admin — reuse those fixtures, add to the same `afterAll`):

```javascript
  it('el reporte de ventas incluye el objeto sucursal en cada fila', async () => {
    const res = await request(app)
      .get('/api/v1/reportes/ventas')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(200);
    expect(res.body.datos.length).toBeGreaterThan(0);
    expect(res.body.datos[0].sucursal).toHaveProperty('id');
    expect(res.body.datos[0].sucursal).toHaveProperty('nombre');
  });

  it('el reporte de caja filtra por sucursal e incluye el objeto sucursal en cada fila', async () => {
    const sesionOtra = await SesionCaja.create({ usuario_id: 1, sucursal_id: sucursalOtra.id, monto_apertura: 0 });
    const registroOtra = await LibroCaja.create({
      sesion_caja_id: sesionOtra.id, usuario_id: 1, tipo: 'ingreso', concepto: 'Test caja otra sucursal', monto: 50, metodo_pago: 'efectivo',
    });

    const res = await request(app)
      .get('/api/v1/reportes/caja')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(200);
    expect(res.body.datos.find(r => r.id === registroOtra.id)).toBeUndefined();

    if (res.body.datos.length > 0) {
      expect(res.body.datos[0].sucursal).toHaveProperty('id');
      expect(res.body.datos[0].sucursal).toHaveProperty('nombre');
    }

    await LibroCaja.destroy({ where: { id: registroOtra.id } });
    await SesionCaja.destroy({ where: { id: sesionOtra.id } });
  });
```

Add `SesionCaja` and `LibroCaja` to the file's existing model import line (`const { Sucursal, Area, Mesa, Categoria, Producto, SesionCaja, Pedido } = require('../src/models');` already imports `SesionCaja` — add `LibroCaja` to it).

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npx jest tests/reportes.test.js` (from `backend/`)
Expected: FAIL — `res.body.datos[0].sucursal` is `undefined` (ventas doesn't include it yet); the caja test's `GET /reportes/caja` returns the other-branch registro too (no filter yet).

- [ ] **Step 3: Update `reportes.service.js`**

Replace the file's imports and all four functions:

```javascript
const { Op } = require('sequelize');
const {
  Pedido, DetallePedido, Mesa, Cliente, Producto, Usuario,
  RegistroInventario, Compra, Proveedor, LibroCaja, SesionCaja, Sucursal,
} = require('../../models');

function filtroFecha(desde, hasta) {
  if (!desde && !hasta) return {};
  const range = {};
  if (desde) range[Op.gte] = new Date(desde + 'T00:00:00');
  if (hasta) range[Op.lte] = new Date(hasta + 'T23:59:59');
  return { creado_en: range };
}

const INCLUDE_SUCURSAL = { model: Sucursal, as: 'sucursal', attributes: ['id', 'nombre'] };

async function ventas({ desde, hasta, sucursal_id, acceso_todas } = {}) {
  const where = { estado: 'completado', ...filtroFecha(desde, hasta) };
  if (!acceso_todas) where.sucursal_id = sucursal_id;
  return Pedido.findAll({
    where,
    include: [
      { model: Mesa,    as: 'mesa',    attributes: ['id', 'nombre'] },
      { model: Cliente, as: 'cliente', attributes: ['id', 'nombre'] },
      { model: Usuario, as: 'usuario', attributes: ['id', 'nombre'] },
      INCLUDE_SUCURSAL,
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
      INCLUDE_SUCURSAL,
    ],
    order: [['creado_en', 'DESC']],
  });
}

async function compras({ desde, hasta, sucursal_id, acceso_todas } = {}) {
  const where = filtroFecha(desde, hasta);
  if (!acceso_todas) where.sucursal_id = sucursal_id;
  return Compra.findAll({
    where,
    include: [
      { model: Proveedor, as: 'proveedor', attributes: ['id', 'nombre'] },
      { model: Usuario,   as: 'usuario',   attributes: ['id', 'nombre'] },
      INCLUDE_SUCURSAL,
    ],
    order: [['creado_en', 'DESC']],
  });
}

async function caja({ desde, hasta, sucursal_id, acceso_todas } = {}) {
  const includeSesion = {
    model: SesionCaja,
    as: 'sesion_caja',
    attributes: [],
    include: [INCLUDE_SUCURSAL],
  };
  if (!acceso_todas) includeSesion.where = { sucursal_id };

  const registros = await LibroCaja.findAll({
    where: filtroFecha(desde, hasta),
    include: [
      { model: Usuario, as: 'usuario', attributes: ['id', 'nombre'] },
      includeSesion,
    ],
    order: [['creado_en', 'DESC']],
  });

  return registros.map(r => {
    const plano = r.toJSON();
    plano.sucursal = plano.sesion_caja?.sucursal ?? null;
    delete plano.sesion_caja;
    return plano;
  });
}

module.exports = { ventas, inventario, compras, caja };
```

(Setting `includeSesion.where = { sucursal_id }` makes Sequelize treat that include as `required: true` automatically, so it behaves as an inner join filter — same mechanism already used implicitly by the `where.sucursal_id = sucursal_id` filters on the other three functions' top-level `where`.)

- [ ] **Step 4: Update `reportes.controller.js`**

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
  try { res.json({ ok: true, datos: await svc.compras({ ...req.query, ..._alcance(req) }) }); } catch (e) { next(e); }
}

async function getCaja(req, res, next) {
  try { res.json({ ok: true, datos: await svc.caja({ ...req.query, ..._alcance(req) }) }); } catch (e) { next(e); }
}

module.exports = { getVentas, getInventario, getCompras, getCaja };
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `npx jest tests/reportes.test.js` (from `backend/`)
Expected: PASS.

- [ ] **Step 6: Run the full suite to check for regressions**

Run: `npm test` (from `backend/`)
Expected: all suites pass — the `INCLUDE_SUCURSAL` addition and the `caja` rewrite only add data to responses/apply an existing filter pattern; no existing consumer of these four functions breaks.

- [ ] **Step 7: Commit**

```bash
git add backend/src/modules/reportes backend/tests/reportes.test.js
git commit -m "feat(reportes): include sucursal in all 4 reports, scope caja by branch"
```

---

### Task 2: Frontend — Ventas: columna, filtro y resumen por sucursal

**Files:**
- Modify: `frontend/src/pages/reportes/tabs/TabVentas.jsx`

**Interfaces:**
- Consumes: `sucursal: { id, nombre }` on each row from Task 1's `GET /reportes/ventas`.
- Produces: no visible change for single-branch users; a "Sucursal" filter, column, and comparison table for `acceso_todas` users.

- [ ] **Step 1: Add the `useAuthStore` import and `accesoTodas` derivation**

Add to the imports at the top of `frontend/src/pages/reportes/tabs/TabVentas.jsx`:

```javascript
import { useAuthStore } from '../../../store/authStore';
```

Inside `export default function TabVentas({ empresa })`, right after the `useAuth()` line, add:

```javascript
  const accesoTodas = useAuthStore((s) => s.usuario?.sucursal_activa?.id == null);
  const [filtroSucursal, setFiltroSucursal] = useState('todas');
```

- [ ] **Step 2: Derive the sucursal filter options and extend the `filtrado` memo**

Add this `useMemo` next to the existing `cajeros` one:

```javascript
  const sucursales = useMemo(() => {
    const unicos = new Map();
    data.forEach(v => { if (v.sucursal?.id) unicos.set(v.sucursal.id, v.sucursal.nombre); });
    return Array.from(unicos.entries()).map(([id, nombre]) => ({ id, nombre }));
  }, [data]);
```

Replace the existing `filtrado` memo:

```javascript
  const filtrado = useMemo(() => {
    let base = filtroCajero === 'todos' ? data : data.filter(v => String(v.usuario?.id) === filtroCajero);
    if (accesoTodas && filtroSucursal !== 'todas') {
      base = base.filter(v => String(v.sucursal?.id) === filtroSucursal);
    }
    return base;
  }, [data, filtroCajero, filtroSucursal, accesoTodas]);
```

- [ ] **Step 3: Add the per-sucursal summary memo**

Add after the existing `stats` memo:

```javascript
  const resumenSucursales = useMemo(() => {
    if (!accesoTodas) return [];
    const mapa = new Map();
    filtrado.forEach(v => {
      const id = v.sucursal?.id;
      if (id == null) return;
      if (!mapa.has(id)) mapa.set(id, { id, nombre: v.sucursal.nombre, count: 0, total: 0, efectivo: 0, qr: 0 });
      const s = mapa.get(id);
      s.count += 1;
      s.total += parseFloat(v.total || 0);
      if (v.metodo_pago === 'efectivo') s.efectivo += parseFloat(v.total || 0);
      else s.qr += parseFloat(v.total || 0);
    });
    return Array.from(mapa.values()).sort((a, b) => b.total - a.total);
  }, [filtrado, accesoTodas]);
```

- [ ] **Step 4: Add the Sucursal filter dropdown**

In the JSX, right after the existing "Cajero" `<select>` block (still inside the `<div className="flex flex-wrap items-end gap-3">` that also holds `FiltroFechas`), add:

```jsx
          {accesoTodas && (
            <div className="flex flex-col gap-1">
              <label className="text-xs font-medium text-gray-500 dark:text-gray-400">Sucursal</label>
              <select value={filtroSucursal} onChange={e => setFiltroSucursal(e.target.value)}
                className="px-3 py-2 text-sm rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-violet-500">
                <option value="todas">Todas</option>
                {sucursales.map(s => (
                  <option key={s.id} value={String(s.id)}>{s.nombre}</option>
                ))}
              </select>
            </div>
          )}
```

- [ ] **Step 5: Add the Sucursal column to the detailed table**

Change the header array and its rendering: replace
```javascript
                {['Fecha', 'Mesa', 'Cliente', 'Cajero', 'Método', 'Total'].map(h => (
```
with
```javascript
                {[...(accesoTodas ? ['Sucursal'] : []), 'Fecha', 'Mesa', 'Cliente', 'Cajero', 'Método', 'Total'].map(h => (
```
Update the "sin resultados" `colSpan` from `6` to `{accesoTodas ? 7 : 6}`, and the `tfoot`'s `colSpan={5}` to `colSpan={accesoTodas ? 6 : 5}`.

Add the cell in the row, right before the existing "Fecha" `<td>`:
```jsx
                  {accesoTodas && (
                    <td className="px-4 py-3 text-gray-600 dark:text-gray-300">{v.sucursal?.nombre || '-'}</td>
                  )}
```

- [ ] **Step 6: Render the summary table**

Right after the `<div className="grid grid-cols-2 lg:grid-cols-4 gap-4">...</div>` StatCard block and before the `{isLoading ? <Skeleton /> : (...)}` block, add:

```jsx
      {accesoTodas && resumenSucursales.length > 0 && (
        <div className="overflow-x-auto rounded-2xl border border-gray-200 dark:border-gray-700/50">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-violet-50 dark:bg-violet-900/20 border-b border-gray-200 dark:border-gray-700/50">
                {['Sucursal', 'N° Ventas', 'Total', 'Efectivo', 'QR'].map(h => (
                  <th key={h} className="text-left px-4 py-3 text-xs font-semibold text-violet-700 dark:text-violet-300 uppercase tracking-wide">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100 dark:divide-gray-700/40">
              {resumenSucursales.map(s => (
                <tr key={s.id} className="bg-white dark:bg-gray-900">
                  <td className="px-4 py-3 font-medium text-gray-900 dark:text-white">{s.nombre}</td>
                  <td className="px-4 py-3 text-gray-700 dark:text-gray-200">{s.count}</td>
                  <td className="px-4 py-3 font-semibold text-emerald-600 dark:text-emerald-400">{bs(s.total)}</td>
                  <td className="px-4 py-3 text-gray-600 dark:text-gray-300">{bs(s.efectivo)}</td>
                  <td className="px-4 py-3 text-gray-600 dark:text-gray-300">{bs(s.qr)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
```

- [ ] **Step 7: Verify with a compile check**

Run: `npx vite build` (from `frontend/`)
Expected: build succeeds, no errors.

- [ ] **Step 8: Manual trace**

Read the final file top to bottom and confirm: (a) `accesoTodas` is declared once, inside `TabVentas`, before any JSX that reads it — this file has no nested child component (unlike `ProductosPage.jsx`'s `TabProductos` pattern), so there's no cross-component scope risk here; (b) `colSpan` values on both the empty-state row and the `tfoot` row correctly account for the extra column; (c) the summary table only renders in `acceso_todas` mode.

- [ ] **Step 9: Commit**

```bash
git add frontend/src/pages/reportes/tabs/TabVentas.jsx
git commit -m "feat(reportes): sucursal column, filter and summary in Ventas report"
```

---

### Task 3: Frontend — Inventario: columna, filtro y resumen por sucursal

**Files:**
- Modify: `frontend/src/pages/reportes/tabs/TabInventario.jsx`

**Interfaces:**
- Consumes: `sucursal: { id, nombre }` on each row from Task 1's `GET /reportes/inventario`.
- Produces: same three additions as Task 2, adapted to this report's columns (Entradas/Salidas/Ajustes instead of money).

- [ ] **Step 1: Add the `useAuthStore` import, `accesoTodas`, and `filtroSucursal` state**

```javascript
import { useAuthStore } from '../../../store/authStore';
```

Inside `export default function TabInventario({ empresa })`, after `useAuth()`:

```javascript
  const accesoTodas = useAuthStore((s) => s.usuario?.sucursal_activa?.id == null);
  const [filtroSucursal, setFiltroSucursal] = useState('todas');
```

- [ ] **Step 2: Derive sucursal filter options and extend `filtrado`**

```javascript
  const sucursales = useMemo(() => {
    const unicos = new Map();
    data.forEach(r => { if (r.sucursal?.id) unicos.set(r.sucursal.id, r.sucursal.nombre); });
    return Array.from(unicos.entries()).map(([id, nombre]) => ({ id, nombre }));
  }, [data]);
```

Replace the existing `filtrado` memo:

```javascript
  const filtrado = useMemo(() => {
    let base = filtroTipo === 'todos' ? data : data.filter(r => r.tipo === filtroTipo);
    if (accesoTodas && filtroSucursal !== 'todas') {
      base = base.filter(r => String(r.sucursal?.id) === filtroSucursal);
    }
    return base;
  }, [data, filtroTipo, filtroSucursal, accesoTodas]);
```

- [ ] **Step 3: Add the per-sucursal summary memo**

```javascript
  const resumenSucursales = useMemo(() => {
    if (!accesoTodas) return [];
    const mapa = new Map();
    filtrado.forEach(r => {
      const id = r.sucursal?.id;
      if (id == null) return;
      if (!mapa.has(id)) mapa.set(id, { id, nombre: r.sucursal.nombre, total: 0, entradas: 0, salidas: 0, ajustes: 0 });
      const s = mapa.get(id);
      s.total += 1;
      if (['entrada', 'compra'].includes(r.tipo)) s.entradas += r.cantidad;
      else if (['salida', 'venta'].includes(r.tipo)) s.salidas += r.cantidad;
      else if (r.tipo === 'ajuste') s.ajustes += 1;
    });
    return Array.from(mapa.values()).sort((a, b) => b.total - a.total);
  }, [filtrado, accesoTodas]);
```

- [ ] **Step 4: Add the Sucursal filter dropdown**

Right after the existing "Tipo" `<select>` block:

```jsx
          {accesoTodas && (
            <div className="flex flex-col gap-1">
              <label className="text-xs font-medium text-gray-500 dark:text-gray-400">Sucursal</label>
              <select value={filtroSucursal} onChange={e => setFiltroSucursal(e.target.value)}
                className="px-3 py-2 text-sm rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-violet-500">
                <option value="todas">Todas</option>
                {sucursales.map(s => (
                  <option key={s.id} value={String(s.id)}>{s.nombre}</option>
                ))}
              </select>
            </div>
          )}
```

- [ ] **Step 5: Add the Sucursal column**

Replace:
```javascript
                {['Fecha', 'Producto', 'Tipo', 'Cantidad', 'Stock Ant.', 'Stock Nuevo', 'Usuario', 'Nota'].map(h => (
```
with:
```javascript
                {[...(accesoTodas ? ['Sucursal'] : []), 'Fecha', 'Producto', 'Tipo', 'Cantidad', 'Stock Ant.', 'Stock Nuevo', 'Usuario', 'Nota'].map(h => (
```
Update the empty-state `colSpan` from `8` to `{accesoTodas ? 9 : 8}`.

Add the cell right before the "Fecha" `<td>` in the row:
```jsx
                  {accesoTodas && (
                    <td className="px-4 py-3 text-gray-600 dark:text-gray-300">{r.sucursal?.nombre || '-'}</td>
                  )}
```

- [ ] **Step 6: Render the summary table**

Right after the StatCard grid, before `{isLoading ? <Skeleton /> : (...)}`:

```jsx
      {accesoTodas && resumenSucursales.length > 0 && (
        <div className="overflow-x-auto rounded-2xl border border-gray-200 dark:border-gray-700/50">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-violet-50 dark:bg-violet-900/20 border-b border-gray-200 dark:border-gray-700/50">
                {['Sucursal', 'N° Movimientos', 'Entradas', 'Salidas', 'Ajustes'].map(h => (
                  <th key={h} className="text-left px-4 py-3 text-xs font-semibold text-violet-700 dark:text-violet-300 uppercase tracking-wide">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100 dark:divide-gray-700/40">
              {resumenSucursales.map(s => (
                <tr key={s.id} className="bg-white dark:bg-gray-900">
                  <td className="px-4 py-3 font-medium text-gray-900 dark:text-white">{s.nombre}</td>
                  <td className="px-4 py-3 text-gray-700 dark:text-gray-200">{s.total}</td>
                  <td className="px-4 py-3 font-semibold text-emerald-600 dark:text-emerald-400">{s.entradas}</td>
                  <td className="px-4 py-3 font-semibold text-rose-600 dark:text-rose-400">{s.salidas}</td>
                  <td className="px-4 py-3 text-amber-600 dark:text-amber-400">{s.ajustes}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
```

- [ ] **Step 7: Verify with a compile check**

Run: `npx vite build` (from `frontend/`)
Expected: build succeeds, no errors.

- [ ] **Step 8: Manual trace**

Read the final file and confirm `accesoTodas` is declared and used within the same single component (no nested child component in this file), `colSpan` accounts for the extra column, and the summary/column/filter are all gated by `accesoTodas`.

- [ ] **Step 9: Commit**

```bash
git add frontend/src/pages/reportes/tabs/TabInventario.jsx
git commit -m "feat(reportes): sucursal column, filter and summary in Inventario report"
```

---

### Task 4: Frontend — Compras: columna, filtro y resumen por sucursal

**Files:**
- Modify: `frontend/src/pages/reportes/tabs/TabCompras.jsx`

**Interfaces:**
- Consumes: `sucursal: { id, nombre }` on each row from Task 1's `GET /reportes/compras`.
- Produces: same three additions as Task 2/3, adapted to this report's columns (N° Compras / Total).

- [ ] **Step 1: Add the `useAuthStore` import, `accesoTodas`, and `filtroSucursal` state**

```javascript
import { useAuthStore } from '../../../store/authStore';
```

Inside `export default function TabCompras({ empresa })`, after `useAuth()`:

```javascript
  const accesoTodas = useAuthStore((s) => s.usuario?.sucursal_activa?.id == null);
  const [filtroSucursal, setFiltroSucursal] = useState('todas');
```

- [ ] **Step 2: Derive sucursal filter options and extend `filtrado`**

```javascript
  const sucursales = useMemo(() => {
    const unicos = new Map();
    data.forEach(c => { if (c.sucursal?.id) unicos.set(c.sucursal.id, c.sucursal.nombre); });
    return Array.from(unicos.entries()).map(([id, nombre]) => ({ id, nombre }));
  }, [data]);
```

Replace the existing `filtrado` memo:

```javascript
  const filtrado = useMemo(() => {
    let base = filtroEstado === 'todos' ? data : data.filter(c => c.estado === filtroEstado);
    if (accesoTodas && filtroSucursal !== 'todas') {
      base = base.filter(c => String(c.sucursal?.id) === filtroSucursal);
    }
    return base;
  }, [data, filtroEstado, filtroSucursal, accesoTodas]);
```

- [ ] **Step 3: Add the per-sucursal summary memo**

```javascript
  const resumenSucursales = useMemo(() => {
    if (!accesoTodas) return [];
    const mapa = new Map();
    filtrado.forEach(c => {
      const id = c.sucursal?.id;
      if (id == null) return;
      if (!mapa.has(id)) mapa.set(id, { id, nombre: c.sucursal.nombre, count: 0, total: 0 });
      const s = mapa.get(id);
      s.count += 1;
      s.total += parseFloat(c.total || 0);
    });
    return Array.from(mapa.values()).sort((a, b) => b.total - a.total);
  }, [filtrado, accesoTodas]);
```

- [ ] **Step 4: Add the Sucursal filter dropdown**

Right after the existing "Estado" `<select>` block:

```jsx
          {accesoTodas && (
            <div className="flex flex-col gap-1">
              <label className="text-xs font-medium text-gray-500 dark:text-gray-400">Sucursal</label>
              <select value={filtroSucursal} onChange={e => setFiltroSucursal(e.target.value)}
                className="px-3 py-2 text-sm rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-violet-500">
                <option value="todas">Todas</option>
                {sucursales.map(s => (
                  <option key={s.id} value={String(s.id)}>{s.nombre}</option>
                ))}
              </select>
            </div>
          )}
```

- [ ] **Step 5: Add the Sucursal column**

Replace:
```javascript
                {['Fecha', 'Proveedor', 'Estado', 'Registrado por', 'Total', 'Notas'].map(h => (
```
with:
```javascript
                {[...(accesoTodas ? ['Sucursal'] : []), 'Fecha', 'Proveedor', 'Estado', 'Registrado por', 'Total', 'Notas'].map(h => (
```
Update the empty-state `colSpan` from `6` to `{accesoTodas ? 7 : 6}`, and the `tfoot`'s `colSpan={4}` to `colSpan={accesoTodas ? 5 : 4}`.

Add the cell right before the "Fecha" `<td>` in the row:
```jsx
                  {accesoTodas && (
                    <td className="px-4 py-3 text-gray-600 dark:text-gray-300">{c.sucursal?.nombre || '-'}</td>
                  )}
```

- [ ] **Step 6: Render the summary table**

Right after the StatCard grid, before `{isLoading ? <Skeleton /> : (...)}`:

```jsx
      {accesoTodas && resumenSucursales.length > 0 && (
        <div className="overflow-x-auto rounded-2xl border border-gray-200 dark:border-gray-700/50">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-violet-50 dark:bg-violet-900/20 border-b border-gray-200 dark:border-gray-700/50">
                {['Sucursal', 'N° Compras', 'Total'].map(h => (
                  <th key={h} className="text-left px-4 py-3 text-xs font-semibold text-violet-700 dark:text-violet-300 uppercase tracking-wide">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100 dark:divide-gray-700/40">
              {resumenSucursales.map(s => (
                <tr key={s.id} className="bg-white dark:bg-gray-900">
                  <td className="px-4 py-3 font-medium text-gray-900 dark:text-white">{s.nombre}</td>
                  <td className="px-4 py-3 text-gray-700 dark:text-gray-200">{s.count}</td>
                  <td className="px-4 py-3 font-semibold text-blue-600 dark:text-blue-400">{bs(s.total)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
```

- [ ] **Step 7: Verify with a compile check**

Run: `npx vite build` (from `frontend/`)
Expected: build succeeds, no errors.

- [ ] **Step 8: Manual trace**

Read the final file and confirm `accesoTodas` is declared/used within the same single component, `colSpan` values (both empty-state and `tfoot`) account for the extra column, and the summary/column/filter are gated correctly.

- [ ] **Step 9: Commit**

```bash
git add frontend/src/pages/reportes/tabs/TabCompras.jsx
git commit -m "feat(reportes): sucursal column, filter and summary in Compras report"
```

---

### Task 5: Frontend — Caja: columna, filtro y resumen por sucursal

**Files:**
- Modify: `frontend/src/pages/reportes/tabs/TabCaja.jsx`

**Interfaces:**
- Consumes: `sucursal: { id, nombre }` on each row from Task 1's `GET /reportes/caja` (flattened from the `sesion_caja` join).
- Produces: same three additions, adapted to this report's columns (Ingresos/Egresos/Neto).

- [ ] **Step 1: Add the `useAuthStore` import, `accesoTodas`, and `filtroSucursal` state**

```javascript
import { useAuthStore } from '../../../store/authStore';
```

Inside `export default function TabCaja({ empresa })`, after `useAuth()`:

```javascript
  const accesoTodas = useAuthStore((s) => s.usuario?.sucursal_activa?.id == null);
  const [filtroSucursal, setFiltroSucursal] = useState('todas');
```

- [ ] **Step 2: Derive sucursal filter options and extend `filtrado`**

```javascript
  const sucursales = useMemo(() => {
    const unicos = new Map();
    data.forEach(r => { if (r.sucursal?.id) unicos.set(r.sucursal.id, r.sucursal.nombre); });
    return Array.from(unicos.entries()).map(([id, nombre]) => ({ id, nombre }));
  }, [data]);
```

Replace the existing `filtrado` memo:

```javascript
  const filtrado = useMemo(() => {
    let base = filtroTipo === 'todos' ? data : data.filter(r => r.tipo === filtroTipo);
    if (accesoTodas && filtroSucursal !== 'todas') {
      base = base.filter(r => String(r.sucursal?.id) === filtroSucursal);
    }
    return base;
  }, [data, filtroTipo, filtroSucursal, accesoTodas]);
```

- [ ] **Step 3: Add the per-sucursal summary memo**

```javascript
  const resumenSucursales = useMemo(() => {
    if (!accesoTodas) return [];
    const mapa = new Map();
    filtrado.forEach(r => {
      const id = r.sucursal?.id;
      if (id == null) return;
      if (!mapa.has(id)) mapa.set(id, { id, nombre: r.sucursal.nombre, ingresos: 0, egresos: 0 });
      const s = mapa.get(id);
      if (r.tipo === 'ingreso') s.ingresos += parseFloat(r.monto || 0);
      else s.egresos += parseFloat(r.monto || 0);
    });
    return Array.from(mapa.values())
      .map(s => ({ ...s, neto: s.ingresos - s.egresos }))
      .sort((a, b) => b.neto - a.neto);
  }, [filtrado, accesoTodas]);
```

- [ ] **Step 4: Add the Sucursal filter dropdown**

Right after the existing "Tipo" `<select>` block:

```jsx
          {accesoTodas && (
            <div className="flex flex-col gap-1">
              <label className="text-xs font-medium text-gray-500 dark:text-gray-400">Sucursal</label>
              <select value={filtroSucursal} onChange={e => setFiltroSucursal(e.target.value)}
                className="px-3 py-2 text-sm rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-violet-500">
                <option value="todas">Todas</option>
                {sucursales.map(s => (
                  <option key={s.id} value={String(s.id)}>{s.nombre}</option>
                ))}
              </select>
            </div>
          )}
```

- [ ] **Step 5: Add the Sucursal column**

Replace:
```javascript
                {['Fecha', 'Tipo', 'Concepto', 'Método', 'Usuario', 'Monto'].map(h => (
```
with:
```javascript
                {[...(accesoTodas ? ['Sucursal'] : []), 'Fecha', 'Tipo', 'Concepto', 'Método', 'Usuario', 'Monto'].map(h => (
```
Update the empty-state `colSpan` from `6` to `{accesoTodas ? 7 : 6}`, and the `tfoot`'s `colSpan={5}` to `colSpan={accesoTodas ? 6 : 5}`.

Add the cell right before the "Fecha" `<td>` in the row:
```jsx
                  {accesoTodas && (
                    <td className="px-4 py-3 text-gray-600 dark:text-gray-300">{r.sucursal?.nombre || '-'}</td>
                  )}
```

- [ ] **Step 6: Render the summary table**

Right after the StatCard grid, before `{isLoading ? <Skeleton /> : (...)}`:

```jsx
      {accesoTodas && resumenSucursales.length > 0 && (
        <div className="overflow-x-auto rounded-2xl border border-gray-200 dark:border-gray-700/50">
          <table className="w-full text-sm">
            <thead>
              <tr className="bg-violet-50 dark:bg-violet-900/20 border-b border-gray-200 dark:border-gray-700/50">
                {['Sucursal', 'Ingresos', 'Egresos', 'Neto'].map(h => (
                  <th key={h} className="text-left px-4 py-3 text-xs font-semibold text-violet-700 dark:text-violet-300 uppercase tracking-wide">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100 dark:divide-gray-700/40">
              {resumenSucursales.map(s => (
                <tr key={s.id} className="bg-white dark:bg-gray-900">
                  <td className="px-4 py-3 font-medium text-gray-900 dark:text-white">{s.nombre}</td>
                  <td className="px-4 py-3 font-semibold text-emerald-600 dark:text-emerald-400">{bs(s.ingresos)}</td>
                  <td className="px-4 py-3 font-semibold text-rose-600 dark:text-rose-400">{bs(s.egresos)}</td>
                  <td className={`px-4 py-3 font-bold ${s.neto >= 0 ? 'text-emerald-600 dark:text-emerald-400' : 'text-rose-600 dark:text-rose-400'}`}>{bs(s.neto)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
```

- [ ] **Step 7: Verify with a compile check**

Run: `npx vite build` (from `frontend/`)
Expected: build succeeds, no errors.

- [ ] **Step 8: Manual trace**

Read the final file and confirm `accesoTodas` is declared/used within the same single component, `colSpan` values account for the extra column, and the summary/column/filter are gated correctly.

- [ ] **Step 9: Commit**

```bash
git add frontend/src/pages/reportes/tabs/TabCaja.jsx
git commit -m "feat(reportes): sucursal column, filter and summary in Caja report"
```
