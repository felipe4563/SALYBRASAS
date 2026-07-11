# Venta en pantalla única — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar el flujo de venta en 3 pantallas (productos → mesa → cobro) por una sola pantalla en `/ventas`: carrito local + selección de mesa/llevar + cobro, todo en una acción atómica contra el backend. Se revierte el trabajo de la sesión anterior (estado `'armando'`, endpoints `/borrador`, `/asignar`, `DELETE /ventas/:id`) que queda sin uso.

**Architecture:** El carrito vive 100% en el estado local de React hasta el momento de cobrar. Un solo endpoint nuevo `POST /ventas/completa` crea el pedido ya `completado` (pagado) en una transacción atómica: valida stock, descuenta inventario, registra caja, y la mesa nunca llega a marcarse "ocupada" (se asocia para historial pero queda `disponible` todo el tiempo). Sin pantalla de cocina en uso por ahora, no hace falta el estado intermedio `pendiente`/`listo` para este flujo nuevo.

**Tech Stack:** Node.js/Express + Sequelize/MySQL (backend), React 18 + Vite + React Query + React Router (frontend).

## Global Constraints

- No modificar `listarCocina()`, `marcarListo()`, `cancelar()`, `crear()`, `agregarItem()`, `actualizarItem()`, `eliminarItem()` tal como quedaron después de la sesión anterior (con la validación de stock y el gating de `flujo_cocina` ya en `cobrar()`) — siguen existiendo para `PedidoPage.jsx` y casos puntuales, fuera de alcance de este plan.
- No modificar el orden `mas_vendido` en `productos.service.js`.
- `PedidoPage.jsx` (ruta `/ventas/pedido/:id`) no se toca.
- **La base de datos de desarrollo es la que usa el restaurante en operación real ahora mismo.** Cualquier verificación manual que mute datos (crear pedidos, cambiar stock) debe hacerse con muchísimo cuidado, revirtiendo de inmediato cualquier dato de prueba, o evitando la mutación en absoluto y verificando solo lectura/build/tests.
- El proyecto no tiene infraestructura de tests con base de datos separada — seguir el patrón existente (tests 401 para rutas nuevas en `backend/tests/ventas.test.js`), sin inventar tests que muten datos reales.

---

### Task 1: Revertir el trabajo de la sesión anterior (estado `armando`, `/borrador`, `/asignar`, `DELETE /ventas/:id`)

**Files:**
- Create: `bd/reversion_flujo_armando.sql`
- Modify: `backend/src/models/Pedido.js`
- Modify: `backend/src/modules/ventas/ventas.service.js`
- Modify: `backend/src/modules/ventas/ventas.controller.js`
- Modify: `backend/src/modules/ventas/ventas.routes.js`
- Modify: `backend/tests/ventas.test.js`

**Interfaces:**
- Produces: `pedidos.estado` vuelve a `('pendiente','listo','completado','cancelado')`, `pedidos.tipo` vuelve a `NOT NULL DEFAULT 'mesa'`. El service ya no exporta `iniciarBorrador`, `asignar`, `cancelarBorrador`. `agregarItem`/`eliminarItem` vuelven a exigir únicamente `pedido.estado === 'pendiente'`.

- [ ] **Step 1: Verificar que no queden pedidos en `armando` antes de revertir el esquema**

Run: `mysql -u root -h localhost bd_restaurante -e "SELECT id, estado, tipo FROM pedidos WHERE estado='armando' OR tipo IS NULL;"`

Expected: sin filas. Si aparece alguna, hay que decidir con el usuario si se borra o se le asigna mesa/tipo antes de continuar — no seguir con el Step 2 sin resolver esto.

- [ ] **Step 2: Escribir y aplicar la migración de reversión**

Crear `bd/reversion_flujo_armando.sql`:

```sql
-- Reversión: se descarta el flujo "armar sin mesa" (estado 'armando')
-- en favor de la pantalla única de venta (productos + mesa + cobro
-- en un solo paso). Ver docs/superpowers/specs/2026-07-11-venta-pantalla-unica-design.md

ALTER TABLE `pedidos`
  MODIFY COLUMN `estado` ENUM('pendiente','listo','completado','cancelado') NOT NULL DEFAULT 'pendiente',
  MODIFY COLUMN `tipo` ENUM('mesa','llevar') NOT NULL DEFAULT 'mesa';
```

Run: `mysql -u root -h localhost bd_restaurante < bd/reversion_flujo_armando.sql`

Verificar:

Run: `mysql -u root -h localhost bd_restaurante -e "SHOW COLUMNS FROM pedidos WHERE Field IN ('estado','tipo');"`

Expected: `estado` → `enum('pendiente','listo','completado','cancelado')`, `Null: NO`; `tipo` → `enum('mesa','llevar')`, `Null: NO`, `Default: mesa`.

- [ ] **Step 3: Revertir el modelo Sequelize**

En `backend/src/models/Pedido.js`, reemplazar:

```js
  tipo: { type: DataTypes.ENUM('mesa', 'llevar'), allowNull: true, defaultValue: 'mesa' },
  numero_llevar: { type: DataTypes.INTEGER.UNSIGNED, allowNull: true },
  estado: { type: DataTypes.ENUM('armando','pendiente','listo','completado','cancelado'), defaultValue: 'pendiente' },
```

por:

```js
  tipo: { type: DataTypes.ENUM('mesa', 'llevar'), defaultValue: 'mesa' },
  numero_llevar: { type: DataTypes.INTEGER.UNSIGNED, allowNull: true },
  estado: { type: DataTypes.ENUM('pendiente','listo','completado','cancelado'), defaultValue: 'pendiente' },
```

- [ ] **Step 4: Quitar `iniciarBorrador`, `asignar`, `cancelarBorrador` de `ventas.service.js`**

En `backend/src/modules/ventas/ventas.service.js`:

1. Borrar la función completa `iniciarBorrador` (entre `async function crear(...)` y `async function asignar(...)`).
2. Borrar la función completa `asignar` (entre `iniciarBorrador` y `agregarItem`).
3. Borrar la función completa `cancelarBorrador` (entre `cancelar` y `_recalcularTotal`).
4. En `agregarItem`, revertir la línea de validación de estado:

```js
  if (pedido.estado !== 'pendiente') throw Object.assign(new Error('El pedido no está pendiente'), { status: 409 });
```

5. En `eliminarItem`, revertir la línea de validación de estado:

```js
  if (!pedido || pedido.estado !== 'pendiente') throw Object.assign(new Error('Pedido no modificable'), { status: 409 });
```

6. Actualizar el `module.exports` final:

```js
module.exports = { listar, listarCocina, obtener, crear, agregarItem, actualizarItem, eliminarItem, cobrar, cancelar, marcarListo };
```

- [ ] **Step 5: Quitar los controllers correspondientes**

En `backend/src/modules/ventas/ventas.controller.js`, borrar las funciones `iniciarBorrador`, `asignar`, `eliminarBorrador` completas, y actualizar el `module.exports`:

```js
module.exports = { listar, obtener, crear, agregarItem, actualizarItem, eliminarItem, cobrar, cancelar, listarCocina, marcarListo };
```

- [ ] **Step 6: Quitar las rutas correspondientes**

En `backend/src/modules/ventas/ventas.routes.js`, borrar estas tres líneas:

```js
router.post('/borrador', verificarPermiso('ventas', 'crear'), ctrl.iniciarBorrador);
router.patch('/:id/asignar', verificarPermiso('ventas', 'crear'), ctrl.asignar);
router.delete('/:id', verificarPermiso('ventas', 'crear'), ctrl.eliminarBorrador);
```

- [ ] **Step 7: Quitar los tests 401 correspondientes**

En `backend/tests/ventas.test.js`, borrar los tres `it(...)` que prueban `POST /api/v1/ventas/borrador`, `PATCH /api/v1/ventas/1/asignar` y `DELETE /api/v1/ventas/1`. Debe quedar únicamente:

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

- [ ] **Step 8: Correr los tests del backend**

Run: `cd backend && DB_HOST=localhost DB_PORT=3306 DB_NAME=bd_restaurante DB_USER=root DB_PASS= JWT_SECRET=secretas JWT_REFRESH_SECRET=secretas_refresh JWT_EXPIRES_IN=8h JWT_REFRESH_EXPIRES_IN=7d npx jest --runInBand`

Expected: todos los test suites pasan (el conteo de tests baja en 3 respecto a antes, por los que se quitaron).

- [ ] **Step 9: Commit**

```bash
git add bd/reversion_flujo_armando.sql backend/src/models/Pedido.js backend/src/modules/ventas backend/tests/ventas.test.js
git commit -m "revert(ventas): descartar flujo armando/borrador/asignar en favor de pantalla unica"
```

---

### Task 2: Backend — endpoint atómico `POST /ventas/completa`

**Files:**
- Modify: `backend/src/modules/ventas/ventas.service.js`
- Modify: `backend/src/modules/ventas/ventas.controller.js`
- Modify: `backend/src/modules/ventas/ventas.routes.js`
- Test: `backend/tests/ventas.test.js`

**Interfaces:**
- Consumes: `Pedido`, `DetallePedido`, `Mesa`, `Producto`, `SesionCaja`, `LibroCaja`, `RegistroInventario`, `Configuracion`, `sequelize`, `emitir`, `_siguienteNumeroLlevar()`, `obtener(id)` (todos ya importados/definidos en `ventas.service.js`).
- Produces: `crearCompleta({ tipo, mesa_id, nombre_cliente, items, metodo_pago, monto_recibido, sesion_caja_id, usuario_id })` → pedido completo (mismo shape que `obtener()`). Ruta `POST /ventas/completa`.

- [ ] **Step 1: Escribir el test de "sin token → 401"**

En `backend/tests/ventas.test.js`, agregar dentro del `describe`:

```js
  it('POST /api/v1/ventas/completa sin token → 401', async () => {
    const res = await request(app).post('/api/v1/ventas/completa').send({});
    expect(res.status).toBe(401);
  });
```

- [ ] **Step 2: Correr el test (ya debería pasar por el middleware de auth a nivel de router, igual que las otras rutas de este módulo)**

Run: `cd backend && DB_HOST=localhost DB_PORT=3306 DB_NAME=bd_restaurante DB_USER=root DB_PASS= JWT_SECRET=secretas JWT_REFRESH_SECRET=secretas_refresh JWT_EXPIRES_IN=8h JWT_REFRESH_EXPIRES_IN=7d npx jest --runInBand -- ventas.test.js`

Expected: PASS (el `router.use(auth)` a nivel de módulo ya bloquea cualquier sub-ruta sin token, como se confirmó en la sesión anterior).

- [ ] **Step 3: Agregar `crearCompleta` al service**

En `backend/src/modules/ventas/ventas.service.js`, agregar la función después de `crear` (antes de `agregarItem`):

```js
async function crearCompleta({ tipo, mesa_id, nombre_cliente, documento_cliente, tipo_documento, items, metodo_pago, monto_recibido, descuento = 0, propina = 0, sesion_caja_id, usuario_id }) {
  if (!sesion_caja_id) {
    throw Object.assign(new Error('No hay caja abierta. Abre la caja antes de crear una orden.'), { status: 409 });
  }
  const sesionActiva = await SesionCaja.findByPk(sesion_caja_id);
  if (!sesionActiva || sesionActiva.estado !== 'abierta') {
    throw Object.assign(new Error('La sesión de caja no está abierta.'), { status: 409 });
  }

  if (!items || items.length === 0) {
    throw Object.assign(new Error('El pedido no tiene productos'), { status: 409 });
  }

  const productos = [];
  for (const item of items) {
    const producto = await Producto.findByPk(item.producto_id);
    if (!producto) throw Object.assign(new Error('Producto no encontrado'), { status: 404 });
    if (!producto.activo || !producto.es_vendible) throw Object.assign(new Error('Producto no disponible'), { status: 409 });
    const stockActual = producto.stock ?? 0;
    if (stockActual < item.cantidad) {
      throw Object.assign(new Error(`Stock insuficiente: ${producto.nombre}`), { status: 409 });
    }
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
      tipo,
      numero_llevar,
      usuario_id,
      sesion_caja_id,
      estado: 'completado',
      total,
      descuento,
      propina,
      metodo_pago,
      monto_recibido: monto_recibido || monto_neto,
      cambio,
      nombre_cliente: nombre_cliente || (tipo === 'llevar' ? 'Cliente' : 'Público General'),
      documento_cliente,
      tipo_documento: tipo_documento || 'Ticket',
    }, { transaction: t });

    for (const { item, producto } of productos) {
      await DetallePedido.create({
        pedido_id: pedido.id,
        producto_id: item.producto_id,
        cantidad: item.cantidad,
        precio: producto.precio,
        nota: item.nota,
      }, { transaction: t });

      const stock_anterior = producto.stock ?? 0;
      const stock_nuevo = stock_anterior - item.cantidad;
      await producto.update({ stock: stock_nuevo }, { transaction: t });
      await RegistroInventario.create({
        producto_id: item.producto_id,
        usuario_id,
        tipo: 'venta',
        cantidad: item.cantidad,
        stock_anterior,
        stock_nuevo,
        nota: `Venta #${pedido.id}`,
      }, { transaction: t });
    }

    await LibroCaja.create({
      sesion_caja_id,
      usuario_id,
      tipo: 'ingreso',
      concepto: `Venta #${pedido.id}`,
      monto: monto_neto,
      metodo_pago,
      referencia_id: pedido.id,
    }, { transaction: t });

    await SesionCaja.increment('total_ventas', { by: monto_neto, where: { id: sesion_caja_id }, transaction: t });

    return pedido.id;
  });

  const creado = await obtener(pedidoId);
  emitir('restaurante:actualizar', { tipo: 'pedido_cobrado' });

  const cfgRows = await Configuracion.findAll({ where: { clave: ['nombre_negocio', 'simbolo_moneda', 'direccion', 'telefono', 'flujo_cocina'] } });
  const cfg = cfgRows.reduce((o, r) => { o[r.clave] = r.valor; return o; }, {});

  const inicioDia = new Date(); inicioDia.setHours(0, 0, 0, 0);
  const finDia    = new Date(); finDia.setHours(23, 59, 59, 999);
  const numero_orden_diario = await Pedido.count({
    where: { creado_en: { [Op.between]: [inicioDia, finDia] }, estado: { [Op.ne]: 'cancelado' } },
  });

  emitir('print:caja', { pedido: creado.toJSON(), metodo_pago, cambio, config: cfg, numero_orden_diario });
  if (cfg.flujo_cocina === 'fisico') {
    emitir('print:cocina', { pedido: creado.toJSON(), config: cfg, numero_orden_diario });
  }
  return creado;
}
```

Actualizar el `module.exports` al final del archivo:

```js
module.exports = { listar, listarCocina, obtener, crear, crearCompleta, agregarItem, actualizarItem, eliminarItem, cobrar, cancelar, marcarListo };
```

- [ ] **Step 4: Agregar el controller**

En `backend/src/modules/ventas/ventas.controller.js`, agregar después de `crear`:

```js
async function crearCompleta(req, res, next) {
  try {
    const { tipo, items, metodo_pago } = req.body;
    if (!tipo) return res.status(400).json({ ok: false, mensaje: "tipo es requerido ('mesa' o 'llevar')" });
    if (!items || !items.length) return res.status(400).json({ ok: false, mensaje: 'items es requerido y no puede estar vacío' });
    if (!metodo_pago) return res.status(400).json({ ok: false, mensaje: 'metodo_pago es requerido (efectivo|qr)' });
    const datos = { ...req.body, usuario_id: req.usuario.id };
    res.status(201).json({ ok: true, datos: await svc.crearCompleta(datos) });
  } catch (err) { next(err); }
}
```

Actualizar el `module.exports`:

```js
module.exports = { listar, obtener, crear, crearCompleta, agregarItem, actualizarItem, eliminarItem, cobrar, cancelar, listarCocina, marcarListo };
```

- [ ] **Step 5: Agregar la ruta**

En `backend/src/modules/ventas/ventas.routes.js`, agregar después de `router.post('/', verificarPermiso('ventas', 'crear'), ctrl.crear);`:

```js
router.post('/completa', verificarPermiso('ventas', 'crear'), ctrl.crearCompleta);
```

- [ ] **Step 6: Correr toda la suite de backend**

Run: `cd backend && DB_HOST=localhost DB_PORT=3306 DB_NAME=bd_restaurante DB_USER=root DB_PASS= JWT_SECRET=secretas JWT_REFRESH_SECRET=secretas_refresh JWT_EXPIRES_IN=8h JWT_REFRESH_EXPIRES_IN=7d npx jest --runInBand`

Expected: todos los test suites pasan.

- [ ] **Step 7: Commit**

```bash
git add backend/src/modules/ventas backend/tests/ventas.test.js
git commit -m "feat(ventas): endpoint atomico para crear y cobrar un pedido en un solo paso"
```

---

### Task 3: Frontend — cliente API: quitar lo viejo, agregar `crearVentaCompleta`

**Files:**
- Modify: `frontend/src/api/ventas.js`

**Interfaces:**
- Produces: `crearVentaCompleta(datos)`. Se eliminan `iniciarBorrador`, `asignarPedido`, `eliminarPedido`.

- [ ] **Step 1: Editar el archivo**

En `frontend/src/api/ventas.js`, borrar estas tres funciones (las últimas del archivo):

```js
export const iniciarBorrador = (datos) =>
  api.post('/ventas/borrador', datos).then((r) => r.data.datos);

export const asignarPedido = (pedido_id, datos) =>
  api.patch(`/ventas/${pedido_id}/asignar`, datos).then((r) => r.data.datos);

export const eliminarPedido = (pedido_id) =>
  api.delete(`/ventas/${pedido_id}`).then((r) => r.data.datos);
```

y agregar en su lugar:

```js
export const crearVentaCompleta = (datos) =>
  api.post('/ventas/completa', datos).then((r) => r.data.datos);
```

- [ ] **Step 2: Verificar que el frontend compila**

Run: `cd frontend && npm run build`

Expected: falla momentáneamente porque `SeleccionProductosPage.jsx` y `SeleccionMesaPage.jsx` todavía importan `iniciarBorrador`/`asignarPedido`/`eliminarPedido` — eso se corrige en la Tarea 4. No hacer commit todavía de este paso solo; continuar a la Tarea 4 y compilar recién al final de esa tarea.

---

### Task 4: Frontend — quitar las páginas y rutas del flujo de 3 pasos

**Files:**
- Delete: `frontend/src/pages/ventas/SeleccionProductosPage.jsx`
- Delete: `frontend/src/pages/ventas/SeleccionMesaPage.jsx`
- Modify: `frontend/src/router/index.jsx`

**Interfaces:** ninguna (solo elimina código muerto).

- [ ] **Step 1: Borrar los dos archivos**

Run: `rm "frontend/src/pages/ventas/SeleccionProductosPage.jsx" "frontend/src/pages/ventas/SeleccionMesaPage.jsx"`

- [ ] **Step 2: Quitar las rutas y los imports**

En `frontend/src/router/index.jsx`, quitar estas líneas:

```js
import SeleccionProductosPage from '../pages/ventas/SeleccionProductosPage';
import SeleccionMesaPage from '../pages/ventas/SeleccionMesaPage';
```

y:

```js
            { path: '/ventas/nuevo',      element: <SeleccionProductosPage /> },
            { path: '/ventas/nuevo/:pedidoId/mesa', element: <SeleccionMesaPage /> },
```

- [ ] **Step 3: Verificar que compila**

Run: `cd frontend && npm run build`

Expected: build termina sin errores (ya no quedan referencias a `iniciarBorrador`/`asignarPedido`/`eliminarPedido` ni a las páginas borradas).

- [ ] **Step 4: Commit**

```bash
git add -u frontend/src/pages/ventas frontend/src/router/index.jsx frontend/src/api/ventas.js
git commit -m "refactor(ventas): quitar paginas del flujo de 3 pasos y cliente API viejo"
```

---

### Task 5: Frontend — soporte visual de "seleccionada" en `TarjetaMesa`

**Files:**
- Modify: `frontend/src/pages/ventas/components/TarjetaMesa.jsx`

**Interfaces:**
- Produces: `TarjetaMesa` acepta un prop opcional `seleccionada` (boolean, default `false`) que agrega un anillo azul cuando es `true`, sin afectar ningún uso existente (todos los usos actuales no pasan ese prop, así que siguen igual).

- [ ] **Step 1: Editar el componente**

En `frontend/src/pages/ventas/components/TarjetaMesa.jsx`, cambiar la firma y el className:

```jsx
export default function TarjetaMesa({ mesa, pedido, onClick, clickable, seleccionada = false }) {
  const cfg = ESTADO_CONFIG[mesa.estado] ?? ESTADO_CONFIG.disponible;

  return (
    <button
      type="button"
      onClick={clickable ? onClick : undefined}
      disabled={!clickable}
      className={`
        w-full text-left rounded-xl border-2 p-4 transition-all duration-150
        ${cfg.border} ${cfg.bg}
        ${seleccionada ? 'ring-2 ring-blue-500 ring-offset-2 dark:ring-offset-gray-900' : ''}
        ${clickable
          ? 'cursor-pointer hover:shadow-md hover:scale-[1.02] active:scale-[0.98]'
          : 'cursor-default opacity-70'
        }
      `}
    >
```

(el resto del componente no cambia)

- [ ] **Step 2: Verificar que compila**

Run: `cd frontend && npm run build`

Expected: build termina sin errores.

- [ ] **Step 3: Commit**

```bash
git add frontend/src/pages/ventas/components/TarjetaMesa.jsx
git commit -m "feat(ventas): soporte visual de mesa seleccionada en TarjetaMesa"
```

---

### Task 6: Frontend — reescribir `VentasPage.jsx` como pantalla única

**Files:**
- Modify: `frontend/src/pages/ventas/VentasPage.jsx`

**Interfaces:**
- Consumes: `getMesas` (`../../api/mesas`), `getVentas`, `crearVentaCompleta` (`../../api/ventas`), `getCajaActiva` (`../../api/caja`), `getProductos` (`../../api/productos`), `getCategorias` (`../../api/categorias`), `BASE_URL` (`../../api/configuracion`), `useAuth`, `usePermisos`, `TarjetaMesa` (con el nuevo prop `seleccionada`), `ModalLlevar` (`./components/ModalLlevar`), `Modal` (`../../components/ui/Modal`), `socket`.
- Produces: `VentasPage` reemplaza completamente su contenido anterior. No se agregan rutas nuevas.

- [ ] **Step 1: Reescribir el archivo completo**

Reemplazar todo el contenido de `frontend/src/pages/ventas/VentasPage.jsx` por:

```jsx
import { useState, useMemo, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  RefreshCw, AlertCircle, Package, ShoppingCart, ShoppingBag,
  Plus, Minus, Trash2, CreditCard, Wallet, ChevronRight,
} from 'lucide-react';
import { getMesas } from '../../api/mesas';
import { getVentas, crearVentaCompleta } from '../../api/ventas';
import { getCajaActiva } from '../../api/caja';
import { getProductos } from '../../api/productos';
import { getCategorias } from '../../api/categorias';
import { BASE_URL } from '../../api/configuracion';
import { useAuth } from '../../hooks/useAuth';
import { usePermisos } from '../../hooks/usePermisos';
import TarjetaMesa from './components/TarjetaMesa';
import ModalLlevar from './components/ModalLlevar';
import Modal from '../../components/ui/Modal';
import socket from '../../socket';

export default function VentasPage() {
  const { usuario } = useAuth();
  const { tienePermiso } = usePermisos();
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const puedeVer    = tienePermiso('ventas', 'ver');
  const puedeCrear  = tienePermiso('ventas', 'crear');
  const puedeCobrar = tienePermiso('ventas', 'cobrar');

  const [categoriaActiva, setCategoriaActiva] = useState(null);
  const [carrito, setCarrito] = useState([]); // [{producto_id, nombre, precio, cantidad, nota}]
  const [mesaSeleccionada, setMesaSeleccionada] = useState(null); // id o null
  const [modoLlevar, setModoLlevar] = useState(null); // nombre_cliente o null
  const [modalLlevar, setModalLlevar] = useState(false);
  const [modalCobrar, setModalCobrar] = useState(false);
  const [tabMobile, setTabMobile] = useState('productos'); // 'productos' | 'orden'

  const { data: mesas = [], isLoading: cargandoMesas } = useQuery({
    queryKey: ['mesas'],
    queryFn: getMesas,
    enabled: puedeVer,
  });

  const { data: cajaActiva, isLoading: cargandoCaja } = useQuery({
    queryKey: ['caja-activa'],
    queryFn: getCajaActiva,
    refetchInterval: 60_000,
    enabled: puedeVer,
  });

  const { data: pedidosActivos = [] } = useQuery({
    queryKey: ['ventas', 'activos'],
    queryFn: () => getVentas({ estado: 'pendiente,listo' }),
    enabled: puedeVer,
  });

  const { data: categorias = [] } = useQuery({
    queryKey: ['categorias'],
    queryFn: getCategorias,
  });

  const { data: productos = [], isLoading: cargandoProductos } = useQuery({
    queryKey: ['productos-pos', categoriaActiva],
    queryFn: () => getProductos({ solo_vendibles: true, order_by: 'mas_vendido', ...(categoriaActiva ? { categoria_id: categoriaActiva } : {}) }),
  });

  useEffect(() => {
    function onActualizar() {
      queryClient.invalidateQueries({ queryKey: ['mesas'] });
      queryClient.invalidateQueries({ queryKey: ['ventas'] });
    }
    socket.on('restaurante:actualizar', onActualizar);
    return () => socket.off('restaurante:actualizar', onActualizar);
  }, [queryClient]);

  const pedidoPorMesa = pedidosActivos.reduce((acc, p) => {
    if (p.mesa_id) acc[p.mesa_id] = p;
    return acc;
  }, {});

  const itemsPorProducto = useMemo(() => {
    return carrito.reduce((acc, it) => { acc[it.producto_id] = it; return acc; }, {});
  }, [carrito]);

  const total = carrito.reduce((sum, it) => sum + it.cantidad * it.precio, 0);
  const totalItems = carrito.reduce((sum, it) => sum + it.cantidad, 0);
  const puedeCobrarAhora = totalItems > 0 && (mesaSeleccionada != null || modoLlevar != null);

  function handleProducto(prod) {
    if (!puedeCrear) return;
    setCarrito((prev) => {
      const existente = prev.find((it) => it.producto_id === prod.id);
      if (existente) {
        return prev.map((it) => it.producto_id === prod.id ? { ...it, cantidad: it.cantidad + 1 } : it);
      }
      return [...prev, { producto_id: prod.id, nombre: prod.nombre, precio: parseFloat(prod.precio), cantidad: 1, nota: null }];
    });
  }

  function incrementar(producto_id) {
    setCarrito((prev) => prev.map((it) => it.producto_id === producto_id ? { ...it, cantidad: it.cantidad + 1 } : it));
  }

  function decrementar(producto_id) {
    setCarrito((prev) => {
      const item = prev.find((it) => it.producto_id === producto_id);
      if (item.cantidad <= 1) return prev.filter((it) => it.producto_id !== producto_id);
      return prev.map((it) => it.producto_id === producto_id ? { ...it, cantidad: it.cantidad - 1 } : it);
    });
  }

  function quitar(producto_id) {
    setCarrito((prev) => prev.filter((it) => it.producto_id !== producto_id));
  }

  function handleClickMesaDisponible(mesa) {
    setModoLlevar(null);
    setMesaSeleccionada((prev) => prev === mesa.id ? null : mesa.id);
  }

  function handleClickMesaOcupada(mesa) {
    const pedido = pedidoPorMesa[mesa.id];
    if (pedido) navigate(`/ventas/pedido/${pedido.id}`);
  }

  function limpiarTodo() {
    setCarrito([]);
    setMesaSeleccionada(null);
    setModoLlevar(null);
  }

  const porArea = mesas.reduce((acc, mesa) => {
    const key = mesa.area?.nombre ?? 'Sin área';
    if (!acc[key]) acc[key] = [];
    acc[key].push(mesa);
    return acc;
  }, {});

  if (!puedeVer) {
    return (
      <div className="flex flex-col items-center justify-center h-64 gap-3 text-gray-400 dark:text-gray-600">
        <AlertCircle className="w-10 h-10" />
        <p className="text-sm font-medium">No tienes permiso para ver ventas</p>
      </div>
    );
  }

  if (!cargandoCaja && !cajaActiva) {
    return (
      <div className="flex flex-col items-center justify-center h-64 gap-3 text-amber-600 dark:text-amber-400">
        <Wallet className="w-10 h-10" />
        <p className="text-sm font-medium">No hay caja abierta</p>
        <button onClick={() => navigate('/caja')} className="text-sm underline flex items-center gap-1">
          Ir a Caja <ChevronRight className="w-3.5 h-3.5" />
        </button>
      </div>
    );
  }

  return (
    <div className="flex flex-col h-[calc(100vh-4rem)]">
      {/* Header */}
      <header className="flex items-center justify-between gap-3 pb-3 border-b border-gray-200 dark:border-gray-700 shrink-0">
        <h1 className="font-bold text-gray-800 dark:text-gray-100">Ventas</h1>
        <div className="flex md:hidden gap-1 bg-gray-100 dark:bg-gray-800 p-1 rounded-xl">
          <button
            onClick={() => setTabMobile('productos')}
            className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${tabMobile === 'productos' ? 'bg-white dark:bg-gray-700 text-gray-900 dark:text-white shadow-sm' : 'text-gray-500'}`}
          >
            Menú
          </button>
          <button
            onClick={() => setTabMobile('orden')}
            className={`relative px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${tabMobile === 'orden' ? 'bg-white dark:bg-gray-700 text-gray-900 dark:text-white shadow-sm' : 'text-gray-500'}`}
          >
            Orden
            {totalItems > 0 && (
              <span className="absolute -top-1 -right-1 w-4 h-4 bg-blue-600 text-white text-[10px] rounded-full flex items-center justify-center">
                {totalItems}
              </span>
            )}
          </button>
        </div>
      </header>

      <div className="flex flex-1 gap-4 overflow-hidden pt-4">
        {/* Panel izquierdo: productos */}
        <div className={`flex flex-col flex-1 min-w-0 overflow-hidden ${tabMobile === 'orden' ? 'hidden md:flex' : 'flex'}`}>
          <div className="flex gap-2 overflow-x-auto pb-2 shrink-0 scrollbar-hide">
            <button
              onClick={() => setCategoriaActiva(null)}
              className={`shrink-0 px-4 py-1.5 rounded-full text-sm font-medium transition-colors ${!categoriaActiva ? 'bg-blue-600 text-white' : 'bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700'}`}
            >
              Todos
            </button>
            {categorias.map((cat) => (
              <button
                key={cat.id}
                onClick={() => setCategoriaActiva(cat.id)}
                className={`shrink-0 px-4 py-1.5 rounded-full text-sm font-medium transition-colors ${categoriaActiva === cat.id ? 'bg-blue-600 text-white' : 'bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700'}`}
              >
                {cat.nombre}
              </button>
            ))}
          </div>

          <div className="flex-1 overflow-y-auto mt-2 pb-4">
            {cargandoProductos ? (
              <div className="flex items-center justify-center h-32 gap-2 text-gray-400">
                <RefreshCw className="w-4 h-4 animate-spin" /><span className="text-sm">Cargando...</span>
              </div>
            ) : productos.length === 0 ? (
              <div className="flex flex-col items-center justify-center h-32 gap-2 text-gray-400 dark:text-gray-600">
                <Package className="w-8 h-8" />
                <p className="text-sm">No hay productos en esta categoría</p>
              </div>
            ) : (
              <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-3">
                {productos.map((prod) => {
                  const enCarrito = itemsPorProducto[prod.id];
                  return (
                    <button
                      key={prod.id}
                      onClick={() => handleProducto(prod)}
                      disabled={!puedeCrear}
                      className={`relative flex flex-col rounded-xl border transition-all text-left overflow-hidden ${
                        !puedeCrear
                          ? 'opacity-50 cursor-not-allowed'
                          : enCarrito
                          ? 'border-blue-400 dark:border-blue-500 bg-blue-50 dark:bg-blue-900/20 hover:bg-blue-100 dark:hover:bg-blue-900/30'
                          : 'border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 hover:border-blue-300 dark:hover:border-blue-600 hover:shadow-sm'
                      }`}
                    >
                      <div className="w-full aspect-square bg-gray-100 dark:bg-gray-700 overflow-hidden">
                        {prod.imagen ? (
                          <img src={`${BASE_URL}${prod.imagen}`} alt={prod.nombre} className="w-full h-full object-cover" />
                        ) : (
                          <div className="w-full h-full flex items-center justify-center">
                            <Package className="w-10 h-10 text-gray-300 dark:text-gray-600" />
                          </div>
                        )}
                      </div>
                      <div className="p-2.5">
                        <p className="text-sm font-medium text-gray-800 dark:text-gray-100 leading-tight line-clamp-2">{prod.nombre}</p>
                        <p className="text-sm font-bold text-blue-600 dark:text-blue-400 mt-1">Bs {parseFloat(prod.precio).toFixed(2)}</p>
                      </div>
                      {enCarrito && (
                        <span className="absolute top-2 right-2 w-6 h-6 bg-blue-600 text-white text-xs font-bold rounded-full flex items-center justify-center shadow">
                          {enCarrito.cantidad}
                        </span>
                      )}
                    </button>
                  );
                })}
              </div>
            )}
          </div>
        </div>

        {/* Panel derecho: orden + mesas + cobro */}
        <aside className={`flex flex-col w-full md:w-[320px] lg:w-[360px] xl:w-[400px] shrink-0 overflow-y-auto gap-4 ${tabMobile === 'productos' ? 'hidden md:flex' : 'flex'}`}>

          {/* Carrito */}
          <div className="flex flex-col bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-2xl overflow-hidden shrink-0">
            <div className="px-4 py-3 border-b border-gray-100 dark:border-gray-700 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <ShoppingCart className="w-4 h-4 text-gray-500 dark:text-gray-400" />
                <span className="font-semibold text-sm text-gray-700 dark:text-gray-200">Orden</span>
              </div>
              {carrito.length > 0 && (
                <button onClick={limpiarTodo} className="text-xs text-red-500 hover:text-red-600">Vaciar</button>
              )}
            </div>
            <div className="max-h-64 overflow-y-auto divide-y divide-gray-100 dark:divide-gray-700">
              {carrito.length === 0 ? (
                <div className="flex flex-col items-center justify-center h-24 gap-2 text-gray-300 dark:text-gray-600">
                  <ShoppingCart className="w-8 h-8" />
                  <p className="text-xs">Toca un producto para agregarlo</p>
                </div>
              ) : (
                carrito.map((it) => (
                  <div key={it.producto_id} className="px-4 py-2.5 flex items-center gap-2">
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-gray-800 dark:text-gray-100 truncate">{it.nombre}</p>
                      <p className="text-xs text-gray-400">Bs {it.precio.toFixed(2)} c/u</p>
                    </div>
                    <div className="flex items-center gap-1 shrink-0">
                      <button onClick={() => decrementar(it.producto_id)} className="w-6 h-6 rounded-lg bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600 flex items-center justify-center">
                        <Minus className="w-3 h-3" />
                      </button>
                      <span className="w-5 text-center text-sm font-semibold text-gray-800 dark:text-gray-100">{it.cantidad}</span>
                      <button onClick={() => incrementar(it.producto_id)} className="w-6 h-6 rounded-lg bg-gray-100 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600 flex items-center justify-center">
                        <Plus className="w-3 h-3" />
                      </button>
                    </div>
                    <button onClick={() => quitar(it.producto_id)} className="shrink-0 p-1 text-gray-300 dark:text-gray-600 hover:text-red-500">
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                ))
              )}
            </div>
            <div className="px-4 py-3 flex items-center justify-between bg-gray-50 dark:bg-gray-700/40 border-t border-gray-100 dark:border-gray-700">
              <span className="text-sm font-medium text-gray-500 dark:text-gray-400">Total</span>
              <span className="text-xl font-bold text-gray-900 dark:text-white">Bs {total.toFixed(2)}</span>
            </div>
          </div>

          {/* Mesa / para llevar */}
          <div className="flex flex-col bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-2xl overflow-hidden shrink-0">
            <div className="px-4 py-3 border-b border-gray-100 dark:border-gray-700 flex items-center justify-between">
              <span className="font-semibold text-sm text-gray-700 dark:text-gray-200">Mesa</span>
              <button
                onClick={() => setModalLlevar(true)}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors ${
                  modoLlevar ? 'bg-orange-500 text-white' : 'bg-orange-50 dark:bg-orange-900/20 text-orange-600 dark:text-orange-400 hover:bg-orange-100 dark:hover:bg-orange-900/30'
                }`}
              >
                <ShoppingBag className="w-3.5 h-3.5" />
                {modoLlevar ? `Llevar: ${modoLlevar}` : 'Para llevar'}
              </button>
            </div>
            <div className="max-h-56 overflow-y-auto p-3">
              {cargandoMesas ? (
                <div className="flex items-center justify-center h-16 text-gray-400 text-sm">Cargando mesas...</div>
              ) : (
                Object.entries(porArea).map(([area, mesasDeArea]) => (
                  <div key={area} className="mb-3 last:mb-0">
                    <p className="text-[10px] font-bold uppercase tracking-widest text-gray-400 dark:text-gray-500 mb-1.5">{area}</p>
                    <div className="grid grid-cols-2 gap-2">
                      {mesasDeArea.map((mesa) => (
                        <TarjetaMesa
                          key={mesa.id}
                          mesa={mesa}
                          pedido={pedidoPorMesa[mesa.id]}
                          seleccionada={mesaSeleccionada === mesa.id}
                          clickable={mesa.estado === 'disponible' || (mesa.estado === 'ocupada' && !!pedidoPorMesa[mesa.id])}
                          onClick={() => mesa.estado === 'disponible' ? handleClickMesaDisponible(mesa) : handleClickMesaOcupada(mesa)}
                        />
                      ))}
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>

          {/* Cobrar */}
          {puedeCobrar && (
            <button
              onClick={() => setModalCobrar(true)}
              disabled={!puedeCobrarAhora}
              className="w-full flex items-center justify-center gap-2 py-3.5 bg-blue-600 hover:bg-blue-700 active:bg-blue-800 disabled:opacity-50 text-white rounded-xl font-bold text-base transition-colors shadow-sm shrink-0"
            >
              <CreditCard className="w-5 h-5" /> Cobrar
            </button>
          )}
        </aside>
      </div>

      {modalLlevar && (
        <ModalLlevar
          cargando={false}
          onClose={() => setModalLlevar(false)}
          onConfirmar={(nombre) => {
            setMesaSeleccionada(null);
            setModoLlevar(nombre || 'Cliente');
            setModalLlevar(false);
          }}
        />
      )}

      {modalCobrar && (
        <ModalCobrar
          total={total}
          carrito={carrito}
          tipo={modoLlevar ? 'llevar' : 'mesa'}
          mesaId={mesaSeleccionada}
          nombreCliente={modoLlevar}
          sesionCajaId={cajaActiva?.id}
          onClose={() => setModalCobrar(false)}
          onExito={() => {
            limpiarTodo();
            setModalCobrar(false);
            queryClient.invalidateQueries({ queryKey: ['mesas'] });
            queryClient.invalidateQueries({ queryKey: ['ventas'] });
          }}
        />
      )}
    </div>
  );
}

/* ─── Modal Cobrar ──────────────────────────────────────────────────────── */

function ModalCobrar({ total, carrito, tipo, mesaId, nombreCliente, sesionCajaId, onClose, onExito }) {
  const [metodo, setMetodo] = useState('efectivo');
  const [error, setError] = useState(null);

  const cobrar = useMutation({
    mutationFn: () => crearVentaCompleta({
      tipo,
      mesa_id: tipo === 'mesa' ? mesaId : undefined,
      nombre_cliente: nombreCliente ?? undefined,
      items: carrito.map((it) => ({ producto_id: it.producto_id, cantidad: it.cantidad, nota: it.nota })),
      metodo_pago: metodo,
      monto_recibido: total,
      sesion_caja_id: sesionCajaId,
    }),
    onSuccess: () => onExito(),
    onError: (err) => setError(err?.response?.data?.mensaje ?? 'Error al cobrar'),
  });

  return (
    <Modal titulo="Cobrar orden" onClose={onClose} ancho="max-w-sm">
      <div className="space-y-5">
        <div className="bg-gray-50 dark:bg-gray-700/50 rounded-xl p-4 text-center">
          <p className="text-xs text-gray-400 uppercase tracking-wide mb-1">Total a cobrar</p>
          <p className="text-3xl font-bold text-gray-900 dark:text-white">Bs {total.toFixed(2)}</p>
        </div>

        <div>
          <p className="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-2">Método de pago</p>
          <div className="grid grid-cols-2 gap-2">
            {[{ id: 'efectivo', label: 'Efectivo' }, { id: 'qr', label: 'QR / Transferencia' }].map((m) => (
              <button
                key={m.id}
                onClick={() => { setMetodo(m.id); setError(null); }}
                className={`py-3 rounded-xl text-sm font-medium border transition-colors ${
                  metodo === m.id ? 'bg-blue-600 border-blue-600 text-white' : 'border-gray-200 dark:border-gray-600 text-gray-600 dark:text-gray-300 hover:border-blue-400 dark:hover:border-blue-500'
                }`}
              >
                {m.label}
              </button>
            ))}
          </div>
        </div>

        {error && <p className="text-sm text-red-600">{error}</p>}

        <div className="flex justify-end gap-3 pt-1">
          <button onClick={onClose} className="px-4 py-2 rounded-xl text-sm text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors">
            Cancelar
          </button>
          <button
            onClick={() => cobrar.mutate()}
            disabled={cobrar.isPending}
            className="px-5 py-2 rounded-xl text-sm bg-blue-600 hover:bg-blue-700 text-white font-semibold transition-colors disabled:opacity-60"
          >
            {cobrar.isPending ? 'Procesando...' : 'Confirmar cobro'}
          </button>
        </div>
      </div>
    </Modal>
  );
}
```

- [ ] **Step 2: Verificar que compila**

Run: `cd frontend && npm run build`

Expected: build termina sin errores.

- [ ] **Step 3: Commit**

```bash
git add frontend/src/pages/ventas/VentasPage.jsx
git commit -m "feat(ventas): pantalla unica de venta (productos + mesa + cobro)"
```

---

### Task 7: Verificación manual (con extremo cuidado — base de datos en operación real)

**Files:** ninguno.

- [ ] **Step 1: Levantar backend y frontend**

Run: `cd backend && npm run dev` (una terminal) y `cd frontend && npm run dev` (otra).

- [ ] **Step 2: Antes de cualquier prueba que mute datos, confirmar con el usuario que es un buen momento**

No crear pedidos de prueba contra la base real sin preguntar primero. Si el usuario da luz verde, usar cantidades mínimas (1 producto barato) y, si el pedido de prueba llega a cobrarse, revertir inmediatamente sus efectos (igual que se hizo en la sesión anterior): restar el monto de `sesiones_caja.total_ventas`, borrar la fila de `libro_caja`, borrar las filas de `registros_inventario`, restaurar el `stock` del producto, borrar el `pedido` y sus `detalle_pedidos`.

- [ ] **Step 3: Verificar el flujo en el navegador**

En `/ventas`: tocar 1-2 productos (aparecen en el panel "Orden" con su cantidad) → elegir una mesa disponible (se resalta) → tocar "Cobrar" → confirmar con "Efectivo". Verificar que:
- El carrito se vacía y la selección de mesa se limpia.
- La mesa nunca se vio "ocupada" en ningún momento (sigue disponible antes y después).
- El pedido aparece en el historial de ventas con `estado: 'completado'`.

Repetir el mismo flujo con "Para llevar" en vez de mesa.

- [ ] **Step 4: Revertir cualquier dato de prueba** (ver Step 2) antes de dar por terminada la verificación.
