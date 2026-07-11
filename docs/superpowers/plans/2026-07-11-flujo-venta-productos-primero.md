# Flujo de venta productos-primero — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cambiar el flujo de venta del POS de "elegir mesa → agregar productos → cobrar" a "elegir productos → elegir mesa (o para llevar) → cobrar", liberando la mesa y validando stock al cobrar, y respetando la configuración `flujo_cocina` (físico/digital) para decidir si se imprime ticket de cocina.

**Architecture:** El pedido pasa a tener un nuevo estado inicial `'armando'` (carrito en construcción, sin mesa/tipo). Se crea con el primer producto tocado (`POST /ventas/borrador`), se le siguen agregando ítems con los endpoints existentes, se le asigna mesa/tipo con un endpoint nuevo (`PATCH /ventas/:id/asignar`, que lo pasa a `'pendiente'` y lo hace visible en cocina, igual que hoy), y se cobra con el endpoint existente (`POST /ventas/:id/cobrar`, ahora con validación de stock y con el ticket de cocina condicionado a `flujo_cocina`). En el frontend esto se traduce en dos pantallas nuevas (Paso 1: productos, Paso 2: mesa) antes de llegar a la pantalla de cobro ya existente (`PedidoPage`, sin cambios).

**Tech Stack:** Node.js/Express + Sequelize/MySQL (backend), React 18 + Vite + React Query + React Router (frontend).

## Global Constraints

- No modificar `listarCocina()`, `marcarListo()`, `cancelar()` (para pedidos ya `pendiente`/`listo`), ni el orden `mas_vendido` en `productos.service.js` — están fuera de alcance.
- No modificar `PedidoPage.jsx` (Paso 3) — sigue siendo la pantalla de carrito+cobro tal cual funciona hoy.
- El proyecto no tiene infraestructura de tests con base de datos (los tests actuales en `backend/tests/*.test.js` son únicamente checks de "sin token → 401"; no hay DB de pruebas separada, `backend/.env` apunta a la única base configurada). No se debe escribir un test que cree/cobre pedidos reales contra esa base — seguir el patrón existente de tests (`401` para rutas nuevas) y verificar el resto manualmente corriendo la app (última tarea del plan).
- No hay corredor de migraciones (no hay carpeta `migrations/`, ni Sequelize CLI configurado). Los cambios de esquema van en un archivo `.sql` suelto en `bd/`, igual que `bd_restaurante_produccion.sql`, y se aplican a mano con el cliente `mysql`.
- Bs (bolivianos) es la moneda; no cambia nada de formato monetario en este trabajo.

---

### Task 1: Migración de esquema + modelo `Pedido`

**Files:**
- Create: `bd/migracion_flujo_venta_productos_primero.sql`
- Modify: `backend/src/models/Pedido.js:10-12`

**Interfaces:**
- Produces: `pedidos.estado` ENUM ahora incluye `'armando'`. `pedidos.tipo` acepta `NULL`. El modelo Sequelize `Pedido` refleja ambos cambios para que `Pedido.create({ estado: 'armando', tipo: null, mesa_id: null, ... })` no falle por validación de tipo ENUM ni por `tipo` nulo.

- [ ] **Step 1: Escribir el script de migración SQL**

Crear `bd/migracion_flujo_venta_productos_primero.sql`:

```sql
-- Migración: flujo de venta "productos primero"
-- Agrega el estado 'armando' (carrito en construcción, sin mesa/tipo aún)
-- y permite que `tipo` sea NULL mientras el pedido está en armado.

ALTER TABLE `pedidos`
  MODIFY COLUMN `estado` ENUM('armando','pendiente','listo','completado','cancelado') NOT NULL DEFAULT 'pendiente',
  MODIFY COLUMN `tipo` ENUM('mesa','llevar') NULL DEFAULT NULL;
```

- [ ] **Step 2: Aplicar la migración a la base de datos de desarrollo**

Usando las credenciales de `backend/.env` (`DB_USER`, `DB_PASS`, `DB_NAME`, `DB_HOST`):

Run: `mysql -u <DB_USER> -p -h <DB_HOST> <DB_NAME> < bd/migracion_flujo_venta_productos_primero.sql`

Expected: sin salida (el `ALTER TABLE` no imprime nada si tiene éxito). Verificar con:

Run: `mysql -u <DB_USER> -p -h <DB_HOST> <DB_NAME> -e "SHOW COLUMNS FROM pedidos WHERE Field IN ('estado','tipo');"`

Expected: la fila `estado` muestra `enum('armando','pendiente','listo','completado','cancelado')` y la fila `tipo` muestra `Null: YES`.

- [ ] **Step 3: Actualizar el modelo Sequelize**

En `backend/src/models/Pedido.js`, reemplazar las líneas 10-12:

```js
  tipo: { type: DataTypes.ENUM('mesa', 'llevar'), allowNull: true, defaultValue: 'mesa' },
  numero_llevar: { type: DataTypes.INTEGER.UNSIGNED, allowNull: true },
  estado: { type: DataTypes.ENUM('armando','pendiente','listo','completado','cancelado'), defaultValue: 'pendiente' },
```

- [ ] **Step 4: Verificar que el backend sigue arrancando**

Run: `cd backend && npm run dev`

Expected: el servidor arranca sin errores de Sequelize (`Unable to connect` o de sync de modelo). Detener con Ctrl+C.

- [ ] **Step 5: Commit**

```bash
git add bd/migracion_flujo_venta_productos_primero.sql backend/src/models/Pedido.js
git commit -m "feat(db): agregar estado 'armando' y permitir tipo nulo en pedidos"
```

---

### Task 2: Backend — crear pedido en armado (`POST /ventas/borrador`) y permitir agregar/quitar ítems mientras está `armando`

**Files:**
- Modify: `backend/src/modules/ventas/ventas.service.js`
- Modify: `backend/src/modules/ventas/ventas.controller.js`
- Modify: `backend/src/modules/ventas/ventas.routes.js`
- Test: `backend/tests/ventas.test.js`

**Interfaces:**
- Consumes: `Pedido`, `SesionCaja`, `Producto`, `DetallePedido`, `sequelize`, `emitir` (ya importados en `ventas.service.js`); `obtener(id)` (ya existe en el mismo archivo).
- Produces: `iniciarBorrador({ usuario_id, sesion_caja_id, producto_id, cantidad, nota })` → devuelve el pedido completo (mismo shape que `obtener()`). Ruta `POST /ventas/borrador`. `agregarItem`/`eliminarItem` ahora también aceptan pedidos en estado `'armando'` (antes solo `'pendiente'`).

- [ ] **Step 1: Escribir el test de "sin token → 401" para la ruta nueva**

En `backend/tests/ventas.test.js`, agregar dentro del `describe`:

```js
  it('POST /api/v1/ventas/borrador sin token → 401', async () => {
    const res = await request(app).post('/api/v1/ventas/borrador').send({});
    expect(res.status).toBe(401);
  });
```

- [ ] **Step 2: Correr el test y verificar que falla**

Run: `cd backend && npm test -- ventas.test.js`

Expected: FAIL — `expected 401, got 404` (la ruta no existe todavía).

- [ ] **Step 3: Agregar `iniciarBorrador` al service**

En `backend/src/modules/ventas/ventas.service.js`, agregar esta función después de `crear` (después de la línea 98, antes de `agregarItem`):

```js
async function iniciarBorrador({ usuario_id, sesion_caja_id, producto_id, cantidad = 1, nota }) {
  if (!sesion_caja_id) {
    throw Object.assign(new Error('No hay caja abierta. Abre la caja antes de crear una orden.'), { status: 409 });
  }
  const sesionActiva = await SesionCaja.findByPk(sesion_caja_id);
  if (!sesionActiva || sesionActiva.estado !== 'abierta') {
    throw Object.assign(new Error('La sesión de caja no está abierta.'), { status: 409 });
  }

  const producto = await Producto.findByPk(producto_id);
  if (!producto) throw Object.assign(new Error('Producto no encontrado'), { status: 404 });
  if (!producto.activo || !producto.es_vendible) throw Object.assign(new Error('Producto no disponible'), { status: 409 });

  const pedido = await Pedido.create({
    mesa_id: null,
    tipo: null,
    usuario_id,
    sesion_caja_id,
    estado: 'armando',
  });

  await DetallePedido.create({
    pedido_id: pedido.id,
    producto_id,
    cantidad,
    precio: producto.precio,
    nota,
  });

  await _recalcularTotal(pedido.id);
  return obtener(pedido.id);
}
```

Cambiar la validación de estado en `agregarItem` (línea 103) y `eliminarItem` (línea 133) para aceptar también `'armando'`:

```js
  if (!['armando', 'pendiente'].includes(pedido.estado)) throw Object.assign(new Error('El pedido no está pendiente'), { status: 409 });
```

(en `agregarItem`, reemplaza la línea `if (pedido.estado !== 'pendiente') throw ...`)

```js
  if (!pedido || !['armando', 'pendiente'].includes(pedido.estado)) throw Object.assign(new Error('Pedido no modificable'), { status: 409 });
```

(en `eliminarItem`, reemplaza la línea `if (!pedido || pedido.estado !== 'pendiente') throw ...`)

Actualizar el `module.exports` al final del archivo para incluir `iniciarBorrador`:

```js
module.exports = { listar, listarCocina, obtener, crear, iniciarBorrador, agregarItem, actualizarItem, eliminarItem, cobrar, cancelar, marcarListo };
```

- [ ] **Step 4: Agregar el controller**

En `backend/src/modules/ventas/ventas.controller.js`, agregar después de `crear`:

```js
async function iniciarBorrador(req, res, next) {
  try {
    const { producto_id, cantidad, nota, sesion_caja_id } = req.body;
    if (!producto_id) return res.status(400).json({ ok: false, mensaje: 'producto_id es requerido' });
    const datos = { producto_id, cantidad, nota, sesion_caja_id, usuario_id: req.usuario.id };
    res.status(201).json({ ok: true, datos: await svc.iniciarBorrador(datos) });
  } catch (err) { next(err); }
}
```

Actualizar el `module.exports`:

```js
module.exports = { listar, obtener, crear, iniciarBorrador, agregarItem, actualizarItem, eliminarItem, cobrar, cancelar, listarCocina, marcarListo };
```

- [ ] **Step 5: Agregar la ruta**

En `backend/src/modules/ventas/ventas.routes.js`, agregar antes de `router.post('/', ...)` (línea 11):

```js
router.post('/borrador', verificarPermiso('ventas', 'crear'), ctrl.iniciarBorrador);
```

- [ ] **Step 6: Correr el test y verificar que pasa**

Run: `cd backend && npm test -- ventas.test.js`

Expected: PASS (2 tests).

- [ ] **Step 7: Commit**

```bash
git add backend/src/modules/ventas backend/tests/ventas.test.js
git commit -m "feat(ventas): crear pedido en armado antes de asignar mesa"
```

---

### Task 3: Backend — asignar mesa/llevar a un pedido en armado (`PATCH /ventas/:id/asignar`)

**Files:**
- Modify: `backend/src/modules/ventas/ventas.service.js`
- Modify: `backend/src/modules/ventas/ventas.controller.js`
- Modify: `backend/src/modules/ventas/ventas.routes.js`
- Test: `backend/tests/ventas.test.js`

**Interfaces:**
- Consumes: `_siguienteNumeroLlevar()` (función privada ya existente en `ventas.service.js`, línea 37).
- Produces: `asignar(pedido_id, { tipo, mesa_id, nombre_cliente, documento_cliente, tipo_documento })` → pedido completo. Ruta `PATCH /ventas/:id/asignar`.

- [ ] **Step 1: Escribir el test de "sin token → 401"**

En `backend/tests/ventas.test.js`, agregar:

```js
  it('PATCH /api/v1/ventas/1/asignar sin token → 401', async () => {
    const res = await request(app).patch('/api/v1/ventas/1/asignar').send({});
    expect(res.status).toBe(401);
  });
```

- [ ] **Step 2: Correr el test y verificar que falla**

Run: `cd backend && npm test -- ventas.test.js`

Expected: FAIL — `expected 401, got 404`.

- [ ] **Step 3: Agregar `asignar` al service**

En `backend/src/modules/ventas/ventas.service.js`, agregar después de `iniciarBorrador`:

```js
async function asignar(pedido_id, { tipo, mesa_id, nombre_cliente, documento_cliente, tipo_documento }) {
  const pedido = await Pedido.findByPk(pedido_id, { include: [{ model: DetallePedido, as: 'detalles' }] });
  if (!pedido) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  if (pedido.estado !== 'armando') throw Object.assign(new Error('El pedido ya tiene mesa/tipo asignado'), { status: 409 });
  if (!pedido.detalles || pedido.detalles.length === 0) {
    throw Object.assign(new Error('El pedido no tiene productos'), { status: 409 });
  }

  if (tipo === 'mesa') {
    if (!mesa_id) throw Object.assign(new Error('mesa_id es requerido'), { status: 400 });
    const mesa = await Mesa.findByPk(mesa_id);
    if (!mesa) throw Object.assign(new Error('Mesa no encontrada'), { status: 404 });
    if (mesa.estado !== 'disponible') throw Object.assign(new Error('Mesa ya ocupada'), { status: 409 });

    await pedido.update({
      tipo: 'mesa',
      mesa_id,
      estado: 'pendiente',
      nombre_cliente: nombre_cliente || 'Público General',
      documento_cliente,
      tipo_documento: tipo_documento || 'Ticket',
    });
    await mesa.update({ estado: 'ocupada' });
  } else if (tipo === 'llevar') {
    const numero_llevar = await _siguienteNumeroLlevar();
    await pedido.update({
      tipo: 'llevar',
      mesa_id: null,
      numero_llevar,
      estado: 'pendiente',
      nombre_cliente: nombre_cliente || 'Cliente',
      documento_cliente,
      tipo_documento: tipo_documento || 'Ticket',
    });
  } else {
    throw Object.assign(new Error("tipo debe ser 'mesa' o 'llevar'"), { status: 400 });
  }

  const resultado = await obtener(pedido_id);
  emitir('restaurante:actualizar', { tipo: 'pedido_nuevo' });
  return resultado;
}
```

Actualizar el `module.exports`:

```js
module.exports = { listar, listarCocina, obtener, crear, iniciarBorrador, asignar, agregarItem, actualizarItem, eliminarItem, cobrar, cancelar, marcarListo };
```

- [ ] **Step 4: Agregar el controller**

En `backend/src/modules/ventas/ventas.controller.js`, agregar después de `iniciarBorrador`:

```js
async function asignar(req, res, next) {
  try {
    const { tipo } = req.body;
    if (!tipo) return res.status(400).json({ ok: false, mensaje: "tipo es requerido ('mesa' o 'llevar')" });
    res.json({ ok: true, datos: await svc.asignar(req.params.id, req.body) });
  } catch (err) { next(err); }
}
```

Actualizar el `module.exports`:

```js
module.exports = { listar, obtener, crear, iniciarBorrador, asignar, agregarItem, actualizarItem, eliminarItem, cobrar, cancelar, listarCocina, marcarListo };
```

- [ ] **Step 5: Agregar la ruta**

En `backend/src/modules/ventas/ventas.routes.js`, agregar después de `router.post('/:id/items', ...)` (línea 13):

```js
router.patch('/:id/asignar', verificarPermiso('ventas', 'crear'), ctrl.asignar);
```

- [ ] **Step 6: Correr el test y verificar que pasa**

Run: `cd backend && npm test -- ventas.test.js`

Expected: PASS (3 tests).

- [ ] **Step 7: Commit**

```bash
git add backend/src/modules/ventas backend/tests/ventas.test.js
git commit -m "feat(ventas): endpoint para asignar mesa o llevar a un pedido en armado"
```

---

### Task 4: Backend — validar stock y condicionar impresión de cocina al cobrar

**Files:**
- Modify: `backend/src/modules/ventas/ventas.service.js:141-225`

**Interfaces:**
- Consumes: `Configuracion` (ya importado). No cambia la firma de `cobrar(pedido_id, usuario_id, { metodo_pago, monto_recibido, descuento, propina })`.
- Produces: `cobrar()` ahora rechaza con 409 si algún producto no tiene stock suficiente, y solo emite `print:cocina` si `configuraciones.flujo_cocina === 'fisico'`.

- [ ] **Step 1: Agregar la validación de stock antes de la transacción**

En `backend/src/modules/ventas/ventas.service.js`, dentro de `cobrar`, justo después de la línea `const cambio = ...` (línea 158) y antes de `await sequelize.transaction(...)` (línea 160), agregar:

```js
  for (const detalle of pedido.detalles) {
    const producto = await Producto.findByPk(detalle.producto_id);
    const stockActual = producto?.stock ?? 0;
    if (stockActual < detalle.cantidad) {
      throw Object.assign(
        new Error(`Stock insuficiente: ${producto?.nombre ?? 'producto #' + detalle.producto_id}`),
        { status: 409 }
      );
    }
  }
```

- [ ] **Step 2: Condicionar el `print:cocina` a `flujo_cocina`**

Reemplazar las líneas 211-223 (desde `// Incluir config del negocio...` hasta `emitir('print:cocina', ...)`) por:

```js
  // Incluir config del negocio en el evento para que el agente la use directamente
  const cfgRows = await Configuracion.findAll({ where: { clave: ['nombre_negocio', 'simbolo_moneda', 'direccion', 'telefono', 'flujo_cocina'] } });
  const cfg = cfgRows.reduce((o, r) => { o[r.clave] = r.valor; return o; }, {});

  // Número de orden diario (se reinicia cada día, aplica a mesa y llevar)
  const inicioDia = new Date(); inicioDia.setHours(0, 0, 0, 0);
  const finDia    = new Date(); finDia.setHours(23, 59, 59, 999);
  const numero_orden_diario = await Pedido.count({
    where: { creado_en: { [Op.between]: [inicioDia, finDia] }, estado: { [Op.ne]: 'cancelado' } },
  });

  emitir('print:caja', { pedido: cobrado.toJSON(), metodo_pago, cambio, config: cfg, numero_orden_diario });
  if (cfg.flujo_cocina === 'fisico') {
    emitir('print:cocina', { pedido: cobrado.toJSON(), config: cfg, numero_orden_diario });
  }
```

- [ ] **Step 3: Verificar manualmente que el módulo sigue cargando**

Run: `cd backend && node -e "require('./src/modules/ventas/ventas.service.js'); console.log('OK')"`

Expected: imprime `OK` (no hay errores de sintaxis).

- [ ] **Step 4: Commit**

```bash
git add backend/src/modules/ventas/ventas.service.js
git commit -m "feat(ventas): validar stock al cobrar y condicionar ticket de cocina a flujo_cocina"
```

---

### Task 5: Backend — cancelar un pedido en armado (`DELETE /ventas/:id`)

**Files:**
- Modify: `backend/src/modules/ventas/ventas.service.js`
- Modify: `backend/src/modules/ventas/ventas.controller.js`
- Modify: `backend/src/modules/ventas/ventas.routes.js`
- Test: `backend/tests/ventas.test.js`

**Interfaces:**
- Produces: `cancelarBorrador(pedido_id)` → `void`. Ruta `DELETE /ventas/:id`, solo permitida si `pedido.estado === 'armando'`.

- [ ] **Step 1: Escribir el test de "sin token → 401"**

En `backend/tests/ventas.test.js`, agregar:

```js
  it('DELETE /api/v1/ventas/1 sin token → 401', async () => {
    const res = await request(app).delete('/api/v1/ventas/1');
    expect(res.status).toBe(401);
  });
```

- [ ] **Step 2: Correr el test y verificar que falla**

Run: `cd backend && npm test -- ventas.test.js`

Expected: FAIL — `expected 401, got 404`.

- [ ] **Step 3: Agregar `cancelarBorrador` al service**

En `backend/src/modules/ventas/ventas.service.js`, agregar después de `asignar`:

```js
async function cancelarBorrador(pedido_id) {
  const pedido = await Pedido.findByPk(pedido_id);
  if (!pedido) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  if (pedido.estado !== 'armando') {
    throw Object.assign(new Error('Solo se pueden eliminar pedidos en armado (sin mesa asignada)'), { status: 409 });
  }
  await pedido.destroy();
}
```

Actualizar el `module.exports`:

```js
module.exports = { listar, listarCocina, obtener, crear, iniciarBorrador, asignar, agregarItem, actualizarItem, eliminarItem, cobrar, cancelar, cancelarBorrador, marcarListo };
```

- [ ] **Step 4: Agregar el controller**

En `backend/src/modules/ventas/ventas.controller.js`, agregar después de `cancelar`:

```js
async function eliminarBorrador(req, res, next) {
  try { await svc.cancelarBorrador(req.params.id); res.json({ ok: true, datos: null }); }
  catch (err) { next(err); }
}
```

Actualizar el `module.exports`:

```js
module.exports = { listar, obtener, crear, iniciarBorrador, asignar, agregarItem, actualizarItem, eliminarItem, cobrar, cancelar, eliminarBorrador, listarCocina, marcarListo };
```

- [ ] **Step 5: Agregar la ruta**

En `backend/src/modules/ventas/ventas.routes.js`, agregar después de `router.post('/:id/cancelar', ...)` (línea 17):

```js
router.delete('/:id', verificarPermiso('ventas', 'crear'), ctrl.eliminarBorrador);
```

- [ ] **Step 6: Correr el test y verificar que pasa**

Run: `cd backend && npm test -- ventas.test.js`

Expected: PASS (4 tests).

- [ ] **Step 7: Correr toda la suite de backend para verificar que nada se rompió**

Run: `cd backend && npm test`

Expected: todos los tests PASS (incluyendo `mesas.test.js`, `caja.test.js`, etc., que no deberían verse afectados).

- [ ] **Step 8: Commit**

```bash
git add backend/src/modules/ventas backend/tests/ventas.test.js
git commit -m "feat(ventas): permitir cancelar un pedido mientras esta en armado"
```

---

### Task 6: Frontend — cliente API para los nuevos endpoints

**Files:**
- Modify: `frontend/src/api/ventas.js`

**Interfaces:**
- Produces: `iniciarBorrador(datos)`, `asignarPedido(pedido_id, datos)`, `eliminarPedido(pedido_id)` — usadas por las tareas 8 y 9.

- [ ] **Step 1: Agregar las tres funciones**

En `frontend/src/api/ventas.js`, agregar al final del archivo:

```js
export const iniciarBorrador = (datos) =>
  api.post('/ventas/borrador', datos).then((r) => r.data.datos);

export const asignarPedido = (pedido_id, datos) =>
  api.patch(`/ventas/${pedido_id}/asignar`, datos).then((r) => r.data.datos);

export const eliminarPedido = (pedido_id) =>
  api.delete(`/ventas/${pedido_id}`).then((r) => r.data.datos);
```

- [ ] **Step 2: Verificar que el frontend sigue compilando**

Run: `cd frontend && npm run build`

Expected: build termina sin errores (`✓ built in ...`).

- [ ] **Step 3: Commit**

```bash
git add frontend/src/api/ventas.js
git commit -m "feat(ventas): cliente API para borrador, asignar y eliminar pedido"
```

---

### Task 7: Frontend — extraer `ModalLlevar` a su propio componente

**Files:**
- Create: `frontend/src/pages/ventas/components/ModalLlevar.jsx`
- Modify: `frontend/src/pages/ventas/VentasPage.jsx`

**Interfaces:**
- Produces: `ModalLlevar` con props `{ onClose, onConfirmar, cargando }` (idéntico al que hoy vive dentro de `VentasPage.jsx:284-321`), reutilizable desde la Tarea 9 (`SeleccionMesaPage.jsx`).

- [ ] **Step 1: Crear el componente**

Crear `frontend/src/pages/ventas/components/ModalLlevar.jsx` con el mismo contenido que hoy está en `VentasPage.jsx:284-321`:

```jsx
import { useState } from 'react';
import Modal from '../../../components/ui/Modal';

export default function ModalLlevar({ onClose, onConfirmar, cargando }) {
  const [nombre, setNombre] = useState('');
  return (
    <Modal titulo="Nuevo pedido para llevar" onClose={onClose} ancho="max-w-sm">
      <div className="space-y-4">
        <div>
          <label className="block text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-1.5">
            Nombre del cliente
          </label>
          <input
            type="text"
            autoFocus
            value={nombre}
            onChange={(e) => setNombre(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && nombre.trim() && onConfirmar(nombre.trim())}
            placeholder="Ej: Juan, Mesa exterior..."
            className="w-full bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-xl px-4 py-2.5 text-sm text-gray-800 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-orange-500 transition"
          />
        </div>
        <div className="flex justify-end gap-3 pt-1">
          <button
            onClick={onClose}
            className="px-4 py-2 rounded-xl text-sm text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
          >
            Cancelar
          </button>
          <button
            onClick={() => onConfirmar(nombre.trim() || 'Cliente')}
            disabled={cargando}
            className="px-5 py-2 rounded-xl text-sm bg-orange-500 hover:bg-orange-600 disabled:opacity-60 text-white font-semibold transition-colors"
          >
            {cargando ? 'Creando...' : 'Crear pedido'}
          </button>
        </div>
      </div>
    </Modal>
  );
}
```

- [ ] **Step 2: Quitar la definición local de `VentasPage.jsx`**

En `frontend/src/pages/ventas/VentasPage.jsx`, eliminar por completo la función `function ModalLlevar({ onClose, onConfirmar, cargando }) { ... }` (líneas 284-321, todo lo que queda después del cierre del componente principal `VentasPage`).

(Los demás usos de `ModalLlevar`, `modalLlevar`, `creandoLlevar`, `crearOrdenLlevar` dentro de `VentasPage` se eliminan en la Tarea 10 junto con el resto de la simplificación; por ahora la Tarea 7 solo mueve el componente de archivo, así que **no** se toca el `import` todavía — se deja momentáneamente sin usar el nombre local, ya que la definición se quitó. Para que compile en este paso intermedio, agregar el import:)

```js
import ModalLlevar from './components/ModalLlevar';
```

al inicio de `VentasPage.jsx` (junto a los demás imports de `./components/`).

- [ ] **Step 3: Verificar que compila**

Run: `cd frontend && npm run build`

Expected: build termina sin errores.

- [ ] **Step 4: Commit**

```bash
git add frontend/src/pages/ventas/components/ModalLlevar.jsx frontend/src/pages/ventas/VentasPage.jsx
git commit -m "refactor(ventas): extraer ModalLlevar a su propio componente"
```

---

### Task 8: Frontend — Paso 1: `SeleccionProductosPage.jsx`

**Files:**
- Create: `frontend/src/pages/ventas/SeleccionProductosPage.jsx`
- Modify: `frontend/src/router/index.jsx`

**Interfaces:**
- Consumes: `iniciarBorrador`, `agregarItem`, `actualizarItem`, `eliminarItem`, `eliminarPedido`, `getVenta` (de `../../api/ventas`), `getProductos` (de `../../api/productos`), `getCategorias` (de `../../api/categorias`), `getCajaActiva` (de `../../api/caja`), `BASE_URL` (de `../../api/configuracion`), `useAuth`, `usePermisos`.
- Produces: ruta `/ventas/nuevo`. Navega a `/ventas/nuevo/:pedidoId/mesa` al presionar "Continuar".

- [ ] **Step 1: Crear la página**

Crear `frontend/src/pages/ventas/SeleccionProductosPage.jsx`:

```jsx
import { useState, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { useQuery, useMutation } from '@tanstack/react-query';
import { ArrowLeft, RefreshCw, Package, ShoppingCart, AlertCircle } from 'lucide-react';
import { iniciarBorrador, agregarItem, actualizarItem, eliminarItem, eliminarPedido, getVenta } from '../../api/ventas';
import { getProductos } from '../../api/productos';
import { getCategorias } from '../../api/categorias';
import { getCajaActiva } from '../../api/caja';
import { BASE_URL } from '../../api/configuracion';
import { usePermisos } from '../../hooks/usePermisos';

export default function SeleccionProductosPage() {
  const navigate = useNavigate();
  const { tienePermiso } = usePermisos();
  const puedeCrear = tienePermiso('ventas', 'crear');

  const [pedidoId, setPedidoId] = useState(null);
  const [pedido, setPedido] = useState(null); // { id, detalles, total }
  const [categoriaActiva, setCategoriaActiva] = useState(null);

  const { data: cajaActiva, isLoading: cargandoCaja } = useQuery({
    queryKey: ['caja-activa'],
    queryFn: getCajaActiva,
  });

  const { data: categorias = [] } = useQuery({
    queryKey: ['categorias'],
    queryFn: getCategorias,
  });

  const { data: productos = [], isLoading: cargandoProductos } = useQuery({
    queryKey: ['productos-pos', categoriaActiva],
    queryFn: () => getProductos({ solo_vendibles: true, order_by: 'mas_vendido', ...(categoriaActiva ? { categoria_id: categoriaActiva } : {}) }),
  });

  const itemsPorProducto = useMemo(() => {
    return (pedido?.detalles ?? []).reduce((acc, d) => { acc[d.producto_id] = d; return acc; }, {});
  }, [pedido]);

  const total = parseFloat(pedido?.total ?? 0);

  const crear = useMutation({
    mutationFn: (producto_id) => iniciarBorrador({ producto_id, cantidad: 1, sesion_caja_id: cajaActiva?.id }),
    onSuccess: (p) => { setPedidoId(p.id); setPedido(p); },
  });

  const agregar = useMutation({
    mutationFn: (producto_id) => agregarItem(pedidoId, { producto_id, cantidad: 1 }),
    onSuccess: () => refrescarPedido(),
  });

  const actualizar = useMutation({
    mutationFn: ({ item_id, cantidad }) => actualizarItem(pedidoId, item_id, { cantidad }),
    onSuccess: () => refrescarPedido(),
  });

  const quitar = useMutation({
    mutationFn: (item_id) => eliminarItem(pedidoId, item_id),
    onSuccess: () => refrescarPedido(),
  });

  const cancelarTodo = useMutation({
    mutationFn: () => eliminarPedido(pedidoId),
    onSuccess: () => navigate('/ventas'),
  });

  async function refrescarPedido() {
    const actualizado = await getVenta(pedidoId);
    setPedido(actualizado);
  }

  function handleProducto(prod) {
    if (!puedeCrear) return;
    if (!pedidoId) {
      crear.mutate(prod.id);
      return;
    }
    const existente = itemsPorProducto[prod.id];
    if (existente) {
      actualizar.mutate({ item_id: existente.id, cantidad: existente.cantidad + 1 });
    } else {
      agregar.mutate(prod.id);
    }
  }

  function handleCancelar() {
    if (pedidoId) {
      cancelarTodo.mutate();
    } else {
      navigate('/ventas');
    }
  }

  const totalItems = (pedido?.detalles ?? []).reduce((sum, d) => sum + d.cantidad, 0);

  if (!cargandoCaja && !cajaActiva) {
    return (
      <div className="flex flex-col items-center justify-center h-64 gap-3 text-amber-600 dark:text-amber-400">
        <AlertCircle className="w-10 h-10" />
        <p className="text-sm font-medium">No hay caja abierta. Abre la caja antes de crear un pedido.</p>
        <button onClick={() => navigate('/caja')} className="text-sm underline">Ir a Caja</button>
      </div>
    );
  }

  return (
    <div className="flex flex-col h-[calc(100vh-4rem)]">
      <header className="flex items-center justify-between gap-3 pb-3 border-b border-gray-200 dark:border-gray-700 shrink-0">
        <div className="flex items-center gap-3 min-w-0">
          <button
            onClick={handleCancelar}
            className="p-2 rounded-lg text-gray-500 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors shrink-0"
          >
            <ArrowLeft className="w-4 h-4" />
          </button>
          <h1 className="font-bold text-gray-800 dark:text-gray-100">Nuevo pedido — Paso 1: Productos</h1>
        </div>
      </header>

      <div className="flex gap-2 overflow-x-auto py-3 shrink-0 scrollbar-hide">
        <button
          onClick={() => setCategoriaActiva(null)}
          className={`shrink-0 px-4 py-1.5 rounded-full text-sm font-medium transition-colors ${
            !categoriaActiva ? 'bg-blue-600 text-white' : 'bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700'
          }`}
        >
          Todos
        </button>
        {categorias.map(cat => (
          <button
            key={cat.id}
            onClick={() => setCategoriaActiva(cat.id)}
            className={`shrink-0 px-4 py-1.5 rounded-full text-sm font-medium transition-colors ${
              categoriaActiva === cat.id ? 'bg-blue-600 text-white' : 'bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700'
            }`}
          >
            {cat.nombre}
          </button>
        ))}
      </div>

      <div className="flex-1 overflow-y-auto pb-28">
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
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-3 pb-4">
            {productos.map(prod => {
              const enOrden = itemsPorProducto[prod.id];
              return (
                <button
                  key={prod.id}
                  onClick={() => handleProducto(prod)}
                  disabled={!puedeCrear}
                  className={`relative flex flex-col rounded-xl border transition-all text-left overflow-hidden ${
                    !puedeCrear
                      ? 'opacity-50 cursor-not-allowed'
                      : enOrden
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
                  {enOrden && (
                    <span className="absolute top-2 right-2 w-6 h-6 bg-blue-600 text-white text-xs font-bold rounded-full flex items-center justify-center shadow">
                      {enOrden.cantidad}
                    </span>
                  )}
                </button>
              );
            })}
          </div>
        )}
      </div>

      <div className="fixed bottom-0 left-0 right-0 z-40 bg-white dark:bg-gray-800 border-t border-gray-200 dark:border-gray-700 px-4 py-3 shadow-lg">
        <div className="flex items-center gap-3 max-w-5xl mx-auto">
          <div className="flex-1 min-w-0 flex items-center gap-2">
            <ShoppingCart className="w-4 h-4 text-gray-400 shrink-0" />
            <div className="min-w-0">
              <p className="text-[11px] text-gray-400 uppercase tracking-wide leading-none mb-0.5">
                {totalItems} ítem{totalItems !== 1 ? 's' : ''}
              </p>
              <p className="text-lg font-bold text-gray-900 dark:text-white leading-none">Bs {total.toFixed(2)}</p>
            </div>
          </div>
          <button
            onClick={() => navigate(`/ventas/nuevo/${pedidoId}/mesa`)}
            disabled={!pedidoId || totalItems === 0}
            className="flex items-center gap-2 px-6 py-3 bg-blue-600 hover:bg-blue-700 disabled:opacity-50 text-white rounded-xl font-bold text-sm transition-colors shrink-0"
          >
            Continuar
          </button>
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Agregar la ruta**

En `frontend/src/router/index.jsx`, agregar el import:

```js
import SeleccionProductosPage from '../pages/ventas/SeleccionProductosPage';
```

y la ruta (justo antes de `{ path: '/ventas/pedido/:id', ... }`):

```js
            { path: '/ventas/nuevo',      element: <SeleccionProductosPage /> },
```

- [ ] **Step 3: Verificar que compila**

Run: `cd frontend && npm run build`

Expected: build termina sin errores.

- [ ] **Step 4: Commit**

```bash
git add frontend/src/pages/ventas/SeleccionProductosPage.jsx frontend/src/router/index.jsx
git commit -m "feat(ventas): pantalla de seleccion de productos (paso 1 del nuevo flujo)"
```

---

### Task 9: Frontend — Paso 2: `SeleccionMesaPage.jsx`

**Files:**
- Create: `frontend/src/pages/ventas/SeleccionMesaPage.jsx`
- Modify: `frontend/src/router/index.jsx`

**Interfaces:**
- Consumes: `getMesas` (de `../../api/mesas`), `getVenta`, `asignarPedido`, `eliminarPedido` (de `../../api/ventas`), `TarjetaMesa` (de `./components/TarjetaMesa`), `ModalLlevar` (de `./components/ModalLlevar`, creado en la Tarea 7).
- Produces: ruta `/ventas/nuevo/:pedidoId/mesa`. Navega a `/ventas/pedido/:pedidoId` (Paso 3, `PedidoPage.jsx`, sin cambios) tras asignar mesa o confirmar "para llevar".

- [ ] **Step 1: Crear la página**

Crear `frontend/src/pages/ventas/SeleccionMesaPage.jsx`:

```jsx
import { useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useQuery, useMutation } from '@tanstack/react-query';
import { ArrowLeft, RefreshCw, ShoppingBag, AlertCircle } from 'lucide-react';
import { getMesas } from '../../api/mesas';
import { getVenta, asignarPedido, eliminarPedido } from '../../api/ventas';
import TarjetaMesa from './components/TarjetaMesa';
import ModalLlevar from './components/ModalLlevar';

export default function SeleccionMesaPage() {
  const { pedidoId } = useParams();
  const navigate = useNavigate();
  const [modalLlevar, setModalLlevar] = useState(false);
  const [error, setError] = useState(null);

  const { data: pedido, isLoading: cargandoPedido } = useQuery({
    queryKey: ['venta', pedidoId],
    queryFn: () => getVenta(pedidoId),
  });

  const { data: mesas = [], isLoading: cargandoMesas } = useQuery({
    queryKey: ['mesas'],
    queryFn: getMesas,
  });

  const asignar = useMutation({
    mutationFn: (datos) => asignarPedido(pedidoId, datos),
    onSuccess: () => navigate(`/ventas/pedido/${pedidoId}`),
    onError: (err) => setError(err?.response?.data?.mensaje ?? 'Error al asignar mesa'),
  });

  const cancelarTodo = useMutation({
    mutationFn: () => eliminarPedido(pedidoId),
    onSuccess: () => navigate('/ventas'),
  });

  const porArea = mesas.reduce((acc, mesa) => {
    const key = mesa.area?.nombre ?? 'Sin área';
    if (!acc[key]) acc[key] = [];
    acc[key].push(mesa);
    return acc;
  }, {});

  if (cargandoPedido || cargandoMesas) {
    return (
      <div className="flex items-center justify-center h-64 gap-3 text-gray-400">
        <RefreshCw className="w-5 h-5 animate-spin" />
        <span>Cargando...</span>
      </div>
    );
  }

  if (!pedido || pedido.estado !== 'armando') {
    return (
      <div className="flex flex-col items-center justify-center h-64 gap-3 text-red-400">
        <AlertCircle className="w-10 h-10" />
        <p className="font-medium">Este pedido ya no está en armado (¿ya se le asignó mesa?)</p>
        <button onClick={() => navigate('/ventas')} className="text-sm underline">Volver</button>
      </div>
    );
  }

  return (
    <div className="space-y-5">
      <header className="flex items-center justify-between gap-3 flex-wrap">
        <div className="flex items-center gap-3 min-w-0">
          <button
            onClick={() => navigate(-1)}
            className="p-2 rounded-lg text-gray-500 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors shrink-0"
          >
            <ArrowLeft className="w-4 h-4" />
          </button>
          <div>
            <h1 className="font-bold text-gray-800 dark:text-gray-100">Paso 2: Elegir mesa</h1>
            <p className="text-xs text-gray-400">Bs {parseFloat(pedido.total).toFixed(2)} · {pedido.detalles?.length ?? 0} ítem(s)</p>
          </div>
        </div>
        <button
          onClick={() => setModalLlevar(true)}
          className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-semibold bg-orange-500 hover:bg-orange-600 active:bg-orange-700 text-white transition-colors"
        >
          <ShoppingBag className="w-4 h-4" />
          Para llevar
        </button>
      </header>

      {error && <p className="text-sm text-red-600">{error}</p>}

      {Object.entries(porArea).map(([area, mesasDeArea]) => (
        <section key={area}>
          <h2 className="text-[11px] font-bold uppercase tracking-widest text-gray-400 dark:text-gray-500 mb-3 pl-2 border-l-2 border-gray-200 dark:border-gray-700">
            {area}
          </h2>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-2.5 sm:gap-3">
            {mesasDeArea.map((mesa) => (
              <TarjetaMesa
                key={mesa.id}
                mesa={mesa}
                clickable={mesa.estado === 'disponible' && !asignar.isPending}
                onClick={() => asignar.mutate({ tipo: 'mesa', mesa_id: mesa.id })}
              />
            ))}
          </div>
        </section>
      ))}

      {modalLlevar && (
        <ModalLlevar
          cargando={asignar.isPending}
          onClose={() => setModalLlevar(false)}
          onConfirmar={(nombre) => {
            setModalLlevar(false);
            asignar.mutate({ tipo: 'llevar', nombre_cliente: nombre });
          }}
        />
      )}

      <button
        onClick={() => cancelarTodo.mutate()}
        disabled={cancelarTodo.isPending}
        className="text-sm text-red-600 dark:text-red-400 underline"
      >
        Cancelar pedido
      </button>
    </div>
  );
}
```

- [ ] **Step 2: Agregar la ruta**

En `frontend/src/router/index.jsx`, agregar el import:

```js
import SeleccionMesaPage from '../pages/ventas/SeleccionMesaPage';
```

y la ruta (junto a la de `/ventas/nuevo`):

```js
            { path: '/ventas/nuevo/:pedidoId/mesa', element: <SeleccionMesaPage /> },
```

- [ ] **Step 3: Verificar que compila**

Run: `cd frontend && npm run build`

Expected: build termina sin errores.

- [ ] **Step 4: Commit**

```bash
git add frontend/src/pages/ventas/SeleccionMesaPage.jsx frontend/src/router/index.jsx
git commit -m "feat(ventas): pantalla de seleccion de mesa/llevar (paso 2 del nuevo flujo)"
```

---

### Task 10: Frontend — simplificar `VentasPage.jsx` (pantalla de inicio)

**Files:**
- Modify: `frontend/src/pages/ventas/VentasPage.jsx`

**Interfaces:**
- Produces: `VentasPage` ya no crea pedidos al tocar mesas disponibles; agrega un botón "Nuevo pedido" que navega a `/ventas/nuevo`.

- [ ] **Step 1: Quitar el flujo viejo de creación**

En `frontend/src/pages/ventas/VentasPage.jsx`, eliminar:
- El estado `const [creando, setCreando] = useState(null);` y `const [modalLlevar, setModalLlevar] = useState(false);` y `const [creandoLlevar, setCreandoLlevar] = useState(false);`.
- Las mutaciones `crearOrden` y `crearOrdenLlevar`.
- El import `crearVenta` de `'../../api/ventas'` (dejar `getVentas`).
- El import `import ModalLlevar from './components/ModalLlevar';` (agregado en la Tarea 7 — ya no se usa en esta página, `ModalLlevar` ahora solo lo usa `SeleccionMesaPage.jsx`).
- El bloque `{/* ── Overlay creando orden ── */}` y `{/* ── Modal para llevar ── */}`.
- El botón "Para llevar" del header.

- [ ] **Step 2: Simplificar `handleClickMesa` y `esClickable`**

Reemplazar (líneas 94-110):

```js
  function handleClickMesa(mesa) {
    if (mesa.estado === 'ocupada') {
      const pedido = pedidoPorMesa[mesa.id];
      if (pedido) navigate(`/ventas/pedido/${pedido.id}`);
    }
  }

  function esClickable(mesa) {
    return mesa.estado === 'ocupada' && puedeVer && !!pedidoPorMesa[mesa.id];
  }
```

- [ ] **Step 3: Agregar el botón "Nuevo pedido"**

En el bloque de acciones del header (donde antes estaba el botón "Para llevar", ahora eliminado), agregar:

```jsx
          {puedeCrear && cajaActiva && (
            <button
              onClick={() => navigate('/ventas/nuevo')}
              className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-semibold bg-blue-600 hover:bg-blue-700 active:bg-blue-800 text-white transition-colors"
            >
              <Plus className="w-4 h-4" />
              Nuevo pedido
            </button>
          )}
```

Agregar `Plus` al import de `lucide-react` (línea 4):

```js
import { RefreshCw, AlertCircle, Coffee, Wallet, ChevronRight, Plus } from 'lucide-react';
```

(se quitan `ShoppingBag` — ya no se usa aquí, ahora vive en `SeleccionMesaPage.jsx` — y se mantiene el resto).

- [ ] **Step 4: Verificar que compila**

Run: `cd frontend && npm run build`

Expected: build termina sin errores, sin warnings de imports no usados (`crearVenta`, `ShoppingBag`, `ModalLlevar` ya fue quitado en el Step 1/`import` correspondiente).

- [ ] **Step 5: Commit**

```bash
git add frontend/src/pages/ventas/VentasPage.jsx
git commit -m "refactor(ventas): simplificar pantalla de mesas, el flujo nuevo empieza en Nuevo pedido"
```

---

### Task 11: Verificación manual end-to-end

**Files:** ninguno (solo verificación).

- [ ] **Step 1: Levantar backend y frontend**

Run: `cd backend && npm run dev` (en una terminal) y `cd frontend && npm run dev` (en otra).

- [ ] **Step 2: Flujo completo — pedido de mesa**

En el navegador: entrar a Ventas, click "Nuevo pedido" → Paso 1: tocar 2 productos distintos (verificar que el total se actualiza y que el botón "Continuar" se habilita) → "Continuar" → Paso 2: tocar una mesa disponible → verificar que redirige a `PedidoPage` con los mismos productos, mesa asignada y estado "pendiente" → abrir la pantalla `/cocina` en otra pestaña y confirmar que el pedido aparece ahí recién ahora (no antes de asignar mesa) → volver a `PedidoPage`, "Cobrar" con efectivo → verificar que la mesa vuelve a "Disponible" en la pantalla de Ventas.

Expected: cada paso funciona sin errores en consola; el pedido cambia de estado `armando → pendiente → completado`; la mesa pasa por `disponible → ocupada → disponible`.

- [ ] **Step 3: Flujo completo — para llevar**

Repetir el mismo flujo pero en el Paso 2 tocar "Para llevar" e ingresar un nombre. Verificar que se genera `numero_llevar` y que el pedido aparece en `/cocina` en la sección "Para llevar".

- [ ] **Step 4: Validación de stock**

En Configuración → Productos, anotar el stock de un producto (o ponerlo en 1 vía el módulo de Inventario). Crear un pedido con cantidad mayor al stock disponible y cobrar. Verificar que el cobro se rechaza con un mensaje "Stock insuficiente: <nombre>" y que el stock no cambió.

- [ ] **Step 5: `flujo_cocina` gating**

En Configuración → Flujo Cocina, dejarlo en "digital" y cobrar un pedido con el `print-agent` corriendo (o revisando los logs del backend/socket) — confirmar que NO se emite `print:cocina` (revisar logs del `print-agent` o agregar un log temporal). Cambiar a "físico", cobrar otro pedido, confirmar que sí se emite/imprime.

- [ ] **Step 6: Cancelar a mitad de camino**

Iniciar un pedido nuevo (Paso 1, tocar un producto), y en el Paso 1 o Paso 2 usar "Cancelar" — verificar que vuelve a la pantalla de Ventas y que el pedido ya no existe (columna `pedidos` en la base, o simplemente que no aparece en ningún lado).

- [ ] **Step 7: Regresión — pedidos existentes**

Verificar que un pedido ya "ocupado" en una mesa (creado antes de este cambio, si hay alguno de prueba) se sigue pudiendo abrir tocándolo desde `VentasPage` y cobrando normalmente.
