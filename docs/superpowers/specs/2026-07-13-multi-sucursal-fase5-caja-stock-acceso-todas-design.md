# Multi-sucursal — Fase 5: Caja e ingreso de stock para usuarios "acceso a todas"

## Contexto

Las Fases 1-2 dejaron cada sucursal operando de forma independiente. Para
un usuario normal, atado a una sola sucursal, todo funciona: abre su caja,
carga stock, todo queda en su sucursal automáticamente. Pero un usuario
con `acceso_todas_sucursales` (sucursal activa = null) tiene dos vacíos
reales, descubiertos al probar el sistema en el navegador:

1. **Caja**: `POST /caja/abrir` (y `GET /caja/activa`) están protegidos
   por el middleware `requiereSucursalActiva`, que bloquea con 403 a
   cualquier usuario en modo "Todas las sucursales" sin excepción. Un
   usuario acceso-todas no puede abrir caja para ninguna sucursal, ni ver
   si tiene una sesión activa en alguna.
2. **Stock**: `POST /inventario/entrada|salida|ajuste` tienen el mismo
   bloqueo. Además, `crearProducto` (`productos.service.js:65`) descarta
   en silencio el stock inicial cuando el creador es acceso-todas
   (`stock !== undefined && stock !== null && !alcance.acceso_todas`) —
   ni error ni carga, el producto queda creado con stock 0 en todas las
   sucursales sin avisar.

Esta fase cierra ambos vacíos: un usuario acceso-todas podrá elegir
explícitamente la sucursal destino para abrir caja, cargar/ajustar stock,
o asignar stock inicial al crear un producto. Para un usuario de una sola
sucursal, nada cambia — sigue operando exactamente igual que hoy, sin
selectores nuevos.

## Decisiones de alcance

- **Solo usuarios con `acceso_todas_sucursales` eligen sucursal destino.**
  Un usuario normal (una sola sucursal asignada) nunca ve un selector de
  sucursal en estas pantallas ni puede operar sobre otra sucursal que la
  suya — sigue exactamente el comportamiento actual.
- **Caja**: la pantalla de Caja para un usuario acceso-todas funciona
  igual que Productos/Reportes hoy — un selector de sucursal a nivel de
  página que determina cuál caja se ve/opera a la vez (no un panel con
  el estado de todas las sucursales simultáneamente).
- **Inventario**: el selector de sucursal destino aplica a los 3 tipos de
  movimiento (entrada, salida, ajuste), no solo a entrada.
- **Productos**: al crear un producto con stock inicial siendo
  acceso-todas, el formulario exige elegir la sucursal destino en vez de
  descartar el valor en silencio.

## Backend

### Caja

**`backend/src/middlewares/sucursalActiva.js`** no cambia — sigue
protegiendo cualquier ruta que la use tal cual. Se **quita** el uso de
`requiereSucursalActiva` de las rutas `POST /caja/abrir` en
`caja.routes.js`, porque ese middleware bloquea sin excepción y ahora
necesitamos permitir el caso acceso-todas-con-sucursal-explícita. La
validación pasa a vivir en el controller, que sí puede distinguir los dos
casos.

**`backend/src/modules/caja/caja.controller.js`**

```javascript
const { Sucursal } = require('../../models');

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

async function abrir(req, res, next) {
  try {
    const { monto_apertura } = req.body;
    const sucursal_id = await _resolverSucursal(req);
    res.status(201).json({ ok: true, datos: await svc.abrir(req.usuario.id, sucursal_id, monto_apertura) });
  } catch (err) { next(err); }
}
```

`svc.abrir` y `svc.obtenerActiva` no cambian de firma (ya reciben
`sucursal_id` como parámetro explícito) — solo cambia de dónde sale ese
valor en el controller.

`caja.routes.js`: la línea de `/abrir` pierde `requiereSucursalActiva`:

```javascript
router.get('/activa', verificarPermiso('caja', 'ver'), ctrl.obtenerActiva);
router.post('/abrir', verificarPermiso('caja', 'abrir'), ctrl.abrir);
```

El resto de las rutas de caja (`/:id/cerrar`, `/:id/gastos`, etc.) no
cambian: ya reciben el id de sesión y validan pertenencia con
`_verificarAlcance` en el service, que funciona igual para acceso-todas
(no filtra) que para usuario normal (compara `sucursal_id`).

### Inventario

Mismo patrón. `backend/src/modules/inventario/inventario.routes.js`
pierde `requiereSucursalActiva` en las 3 rutas de escritura:

```javascript
router.post('/entrada', verificarPermiso('inventario', 'entrada'), ctrl.entrada);
router.post('/salida', verificarPermiso('inventario', 'salida'), ctrl.salida);
router.post('/ajuste', verificarPermiso('inventario', 'ajustar'), ctrl.ajuste);
```

**`backend/src/modules/inventario/inventario.controller.js`**

```javascript
const { Sucursal } = require('../../models');

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

async function entrada(req, res, next) {
  try {
    const { producto_id, cantidad } = req.body;
    if (!producto_id || !cantidad) return res.status(400).json({ ok: false, mensaje: 'producto_id y cantidad son requeridos' });
    const sucursal_id = await _resolverSucursal(req);
    res.status(201).json({ ok: true, datos: await svc.entrada(req.usuario.id, sucursal_id, req.body) });
  } catch (err) { next(err); }
}
// salida y ajuste siguen el mismo patrón: resolver sucursal_id antes de llamar al service.
```

`inventario.service.js` no cambia — `entrada`/`salida`/`ajuste` ya
reciben `sucursal_id` como segundo parámetro explícito.

### Productos

**`backend/src/modules/productos/productos.service.js`**

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

`productos.controller.js` no cambia — ya pasa `req.body` completo a
`crearProducto`, así que `sucursal_id` llega solo con incluirlo en el
payload del frontend.

## Frontend

### Caja (`frontend/src/pages/caja/CajaPage.jsx`)

- `accesoTodas` se deriva con
  `useAuthStore((s) => s.usuario?.sucursal_activa?.id == null)`.
- Cuando `accesoTodas`, se agrega un `useState` de sucursal seleccionada
  (`sucursalId`, inicializado sin selección) y un `<select>` a nivel de
  página (mismo patrón que el filtro de sucursal en `ProductosPage.jsx`),
  con opciones cargadas desde `GET /api/v1/sucursales` (ya existe desde
  Fase 1, `frontend/src/api/sucursales.js`).
- Mientras `accesoTodas` y no hay sucursal elegida, la pantalla muestra
  un mensaje "Elegí una sucursal para ver/operar su caja" en vez de
  intentar cargar `getCajaActiva`.
- Una vez elegida, `getCajaActiva(sucursalId)` y `abrirCaja(monto, sucursalId)`
  se llaman con ese id. El resto de la pantalla (gastos, cerrar, reporte)
  ya usa el id de sesión de caja devuelto y no necesita el selector.
- Para un usuario de una sola sucursal, `sucursalId` nunca se usa y el
  comportamiento es idéntico al actual.

**`frontend/src/api/caja.js`**

```javascript
export const getCajaActiva = (sucursal_id) =>
  api.get('/caja/activa', { params: sucursal_id ? { sucursal_id } : {} }).then(r => r.data.datos).catch(() => null);

export const abrirCaja = (monto_apertura, sucursal_id) =>
  api.post('/caja/abrir', { monto_apertura, ...(sucursal_id ? { sucursal_id } : {}) }).then(r => r.data.datos);
```

### Inventario (`frontend/src/pages/inventario/InventarioPage.jsx`)

- Mismo `accesoTodas` derivado igual que arriba.
- El formulario de entrada/salida/ajuste agrega un `<select>` de
  sucursal cuando `accesoTodas` (mismas opciones de `GET /sucursales`),
  obligatorio para enviar el formulario en ese caso. Se envía como
  `sucursal_id` en el body de la llamada a `entrada`/`salida`/`ajuste`.
- Para usuario de una sola sucursal, no hay cambios visibles.

### Productos (`frontend/src/pages/productos/ProductosPage.jsx`)

- El formulario de "nuevo producto" agrega el mismo `<select>` de
  sucursal, visible solo cuando `accesoTodas` **y** el campo de stock
  inicial tiene un valor distinto de vacío. Se envía como `sucursal_id`
  en el payload de creación.

## Fuera de alcance

- No se toca el historial de sesiones de caja (`GET /caja`), que ya
  muestra todas las sucursales sin filtrar en modo acceso-todas (sin
  selector, es una lista de auditoría, no de operación).
- No se agregan reportes nuevos ni cambios a ventas/compras/mesas.
- No se cambia `actualizarProducto` (edición de producto existente) — el
  stock de un producto ya existente solo se ajusta vía Inventario, como
  hoy.
