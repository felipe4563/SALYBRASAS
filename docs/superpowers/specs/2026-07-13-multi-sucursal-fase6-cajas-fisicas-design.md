# Multi-sucursal — Fase 6: Cajas físicas por sucursal

## Contexto

La Fase 5 le dio a un usuario "acceso a todas las sucursales" la
posibilidad de elegir libremente en qué sucursal abrir una sesión de
caja. En la práctica esto generó confusión: si esa persona abre en la
Sucursal A y después en la Sucursal B, y solo cierra una, la otra queda
abierta sin que nadie lo note — no hay ningún concepto de "punto de
cobro" que muestre con claridad qué está abierto y dónde.

Esta fase introduce una entidad **Caja** (un punto de cobro físico,
p.ej. "Caja 1", "Caja Mostrador") que pertenece a una sola sucursal y es
gestionada por el administrador. La regla clave: **una caja solo puede
tener una sesión abierta a la vez** — si "Caja 1" de la Sucursal A ya
está abierta, nadie más puede abrirla hasta que se cierre. Esto
reemplaza, para las acciones de abrir/ver caja activa, el mecanismo de
"elegir sucursal_id libremente" que agregó la Fase 5 (Task 1 backend /
Task 4 frontend) — ahora se elige una **caja** concreta, cuya sucursal
ya está fija de antemano. El resto de la Fase 5 (inventario, productos)
no cambia.

## Decisiones de alcance

- **Una caja = un punto de cobro por sucursal**, puede haber varias
  cajas por sucursal (ej. 2 cajeros cobrando en simultáneo).
- **Regla de exclusividad**: una caja no puede tener dos sesiones
  `abierta` al mismo tiempo — intentar abrir una caja ya abierta es 409.
- **Acceso-todas**: sigue eligiendo primero la sucursal (selector ya
  existente de la Fase 5), y ahí ve la lista de cajas de esa sucursal.
- **Gestión de cajas**: página nueva "Cajas" en el menú (como
  Sucursales), con permisos propios (`cajas.ver/crear/editar/eliminar`),
  separados de los permisos de sesión existentes (`caja.ver/abrir/cerrar`).
- **Migración de datos**: se crea automáticamente una "Caja Principal"
  por cada sucursal ya existente, y las sesiones (abiertas o históricas)
  se vinculan a esa caja de su propia sucursal — el sistema sigue
  funcionando igual que hoy sin que el admin tenga que configurar nada
  de entrada.
- **La pantalla operativa de Caja debe ser responsiva** — grilla de
  tarjetas que se apila en mobile y se acomoda en más columnas en
  tablet/desktop (mismo espíritu que el resto del sistema).
- **Eliminar una caja** sigue el mismo patrón que Sucursales: se
  bloquea (409) si tiene alguna sesión asociada (abierta o histórica),
  para no romper reportes existentes. Desactivarla (`activo=false`) es
  la forma de "retirarla" sin perder el historial.

## Modelo de datos

### Migración `014_cajas.sql`

```sql
CREATE TABLE IF NOT EXISTS cajas (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sucursal_id INT UNSIGNED NOT NULL,
  nombre VARCHAR(100) NOT NULL,
  activo TINYINT(1) NOT NULL DEFAULT 1,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (sucursal_id) REFERENCES sucursales(id)
);

ALTER TABLE sesiones_caja
  ADD COLUMN caja_id INT UNSIGNED NULL AFTER sucursal_id,
  ADD FOREIGN KEY (caja_id) REFERENCES cajas(id);

-- Backfill: una "Caja Principal" por cada sucursal existente,
-- y las sesiones existentes (abiertas o cerradas) apuntan a la
-- caja principal de su propia sucursal.
INSERT INTO cajas (sucursal_id, nombre)
SELECT id, 'Caja Principal' FROM sucursales;

UPDATE sesiones_caja sc
JOIN cajas c ON c.sucursal_id = sc.sucursal_id AND c.nombre = 'Caja Principal'
SET sc.caja_id = c.id
WHERE sc.caja_id IS NULL;

ALTER TABLE sesiones_caja
  MODIFY COLUMN caja_id INT UNSIGNED NOT NULL;
```

`sesiones_caja.sucursal_id` **no se toca** — sigue existiendo,
denormalizado, poblado con la sucursal de la caja elegida al abrir. Todo
el código que ya filtra/joinea por `sesion_caja.sucursal_id` (reportes,
mesas, etc., de las Fases 2-5) sigue funcionando sin cambios.

### `backend/src/models/Caja.js` (nuevo)

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

`models/index.js` agrega las asociaciones:

```javascript
Caja.belongsTo(Sucursal, { foreignKey: 'sucursal_id', as: 'sucursal' });
Sucursal.hasMany(Caja, { foreignKey: 'sucursal_id', as: 'cajas' });
Caja.hasMany(SesionCaja, { foreignKey: 'caja_id', as: 'sesiones' });
SesionCaja.belongsTo(Caja, { foreignKey: 'caja_id', as: 'caja' });
```

`backend/src/models/SesionCaja.js` agrega el campo `caja_id`
(`allowNull: false`), igual patrón que `sucursal_id`.

## Permisos

`backend/database/seeds/seed.js` agrega al arreglo de permisos:

```javascript
{ modulo: 'cajas', accion: 'ver',      descripcion: 'Ver cajas' },
{ modulo: 'cajas', accion: 'crear',    descripcion: 'Crear cajas' },
{ modulo: 'cajas', accion: 'editar',   descripcion: 'Editar cajas' },
{ modulo: 'cajas', accion: 'eliminar', descripcion: 'Eliminar cajas' },
```

El rol Administrador recibe automáticamente todos los permisos (lógica
ya existente en el seed) — no requiere cambios adicionales.

## Backend

### Módulo nuevo `backend/src/modules/cajas/` (catálogo)

Mismo patrón que `sucursales` (`sucursales.controller.js`/`.service.js`/`.routes.js`):

**`cajas.service.js`**

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

`cajas.controller.js` sigue el mismo patrón que
`sucursales.controller.js` (handlers finos que llaman al service).
`cajas.routes.js` monta en `/api/v1/cajas`:

```javascript
router.get('/', verificarPermiso('cajas', 'ver'), ctrl.listar);
router.post('/', verificarPermiso('cajas', 'crear'), ctrl.crear);
router.put('/:id', verificarPermiso('cajas', 'editar'), ctrl.actualizar);
router.delete('/:id', verificarPermiso('cajas', 'eliminar'), ctrl.eliminar);
```

`listar` acepta `?sucursal_id=` para filtrar (usado tanto por la página
de administración como por la pantalla operativa).

### Módulo existente `caja` (sesiones) — cambios

**`backend/src/modules/caja/caja.service.js`**

Nueva función para alimentar la pantalla operativa:

```javascript
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
```

`abrir` cambia de firma — recibe `caja_id` en vez de `sucursal_id`:

```javascript
async function abrir(usuario_id, caja_id, monto_apertura = 0) {
  const caja = await Caja.findByPk(caja_id);
  if (!caja || !caja.activo) throw Object.assign(new Error('Caja no encontrada'), { status: 404 });

  const abierta = await SesionCaja.findOne({ where: { caja_id, estado: 'abierta' } });
  if (abierta) throw Object.assign(new Error('Esta caja ya tiene una sesión abierta'), { status: 409 });

  return SesionCaja.create({ usuario_id, caja_id, sucursal_id: caja.sucursal_id, monto_apertura });
}
```

(La regla de exclusividad ahora es por `caja_id`, no por
`usuario_id + sucursal_id` — esto es lo que impide que una caja quede
abierta sin que se note: nadie más puede reabrirla hasta que se cierre,
sin importar quién la abrió.)

**`backend/src/modules/caja/caja.controller.js`**

`_resolverCaja(req)` reemplaza a `_resolverSucursal(req)` de la Fase 5
para las rutas `/abrir` y `/estado`:

```javascript
const { Caja } = require('../../models');

async function _resolverCaja(req, caja_id) {
  const caja = await Caja.findByPk(caja_id);
  if (!caja) throw Object.assign(new Error('Caja no encontrada'), { status: 404 });
  if (!req.usuario.acceso_todas && caja.sucursal_id !== req.usuario.sucursal_id) {
    throw Object.assign(new Error('Caja no encontrada'), { status: 404 }); // mismo patrón anti-IDOR de Fase 2
  }
  return caja;
}

async function estado(req, res, next) {
  try {
    const sucursal_id = req.usuario.acceso_todas ? req.query.sucursal_id : req.usuario.sucursal_id;
    if (!sucursal_id) return res.status(400).json({ ok: false, mensaje: 'sucursal_id es requerido' });
    res.json({ ok: true, datos: await svc.listarConEstado(sucursal_id) });
  } catch (err) { next(err); }
}

async function abrir(req, res, next) {
  try {
    const { caja_id, monto_apertura } = req.body;
    if (!caja_id) return res.status(400).json({ ok: false, mensaje: 'caja_id es requerido' });
    await _resolverCaja(req, caja_id);
    res.status(201).json({ ok: true, datos: await svc.abrir(req.usuario.id, caja_id, monto_apertura) });
  } catch (err) { next(err); }
}
```

`obtenerActiva` (`GET /caja/activa`, usado por Fase 5) se **elimina** —
reemplazado por `estado` (`GET /caja/estado?sucursal_id=`), que devuelve
la lista completa de cajas de la sucursal con su estado, en vez de "la"
sesión activa de un usuario. `caja.routes.js` pierde la ruta `/activa` y
gana `/estado`; `/abrir` ya no lleva `requiereSucursalActiva` (se
mantiene igual que en Fase 5 — la validación vive en el controller).

`cerrar`, `registrarGasto`, `listarGastos`, `reporte` **no cambian** —
siguen operando sobre `sesion_id` con `_verificarAlcance` comparando
`sesion.sucursal_id` (denormalizado, sigue existiendo).

`obtener(id, alcance)` **sí se extiende**: hoy solo `obtenerActiva`
calculaba `ventas_efectivo`/`ventas_qr` (sumas de `LibroCaja`) para
mostrar el balance en pantalla. Como `obtenerActiva` se elimina y la
vista de detalle de una sesión abierta ahora se llega vía la grilla
(`estado`) + `GET /caja/:id` (`obtener`), ese mismo cálculo se mueve a
`obtener` para que el balance siga funcionando igual que hoy:

```javascript
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
```

(Este cambio también beneficia a `cerrar`, que ya llama a `obtener` al
final para devolver la sesión actualizada — antes no incluía estas
sumas en su respuesta final, ahora sí, de forma consistente.)

## Frontend

### Página nueva `frontend/src/pages/cajas/CajasPage.jsx` (catálogo)

Calco de `SucursalesPage.jsx`: tabla con nombre, sucursal, estado
(activa/inactiva), crear/editar/eliminar. El formulario (`ModalCaja`)
agrega un `<select>` de sucursal (obligatorio, viene de
`getSucursales()`) además del campo nombre. Gateada por
`tienePermiso('cajas', 'ver'/'crear'/'editar'/'eliminar')`.

**`frontend/src/api/cajas.js`** (nuevo):

```javascript
import api from './cliente';

export const getCajas       = (params = {}) => api.get('/cajas', { params }).then(r => r.data.datos);
export const crearCaja      = (datos)       => api.post('/cajas', datos).then(r => r.data.datos);
export const actualizarCaja = (id, datos)   => api.put(`/cajas/${id}`, datos).then(r => r.data.datos);
export const eliminarCaja   = (id)          => api.delete(`/cajas/${id}`).then(r => r.data.datos);
```

**Ruteo y menú**: `frontend/src/router/index.jsx` agrega
`{ path: '/cajas', element: <CajasPage /> }`;
`frontend/src/components/layout/Sidebar.jsx` agrega
`{ to: '/cajas', label: 'Cajas', Icono: Wallet, modulo: 'cajas', accion: 'ver' }`
(mismo ícono que ya usa la pantalla operativa, junto a la entrada
existente `/caja`).

### Pantalla operativa `frontend/src/pages/caja/CajaPage.jsx` — rediseño

Reemplaza el modelo "una sesión activa" por "grilla de cajas con
estado":

- `accesoTodas` + selector de sucursal: igual que en la Fase 5 (Task 4)
  — si `accesoTodas`, se elige sucursal primero (`sucursales` query +
  `<select>`); si no, se usa `usuario.sucursal_activa.id` directo.
- `getEstadoCajas(sucursal_id)` (nuevo, en `frontend/src/api/caja.js`,
  reemplaza a `getCajaActiva`) devuelve el arreglo de
  `{ id, nombre, sesion_abierta }` de esa sucursal.
- **Grilla responsiva** (esto es lo que pediste): cada caja es una
  tarjeta —

```jsx
<div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
  {cajas.map(c => <TarjetaCaja key={c.id} caja={c} onAbrir={...} onVerDetalle={...} />)}
</div>
```

  1 columna en mobile, 2 en tablet (`sm`), 3 en desktop (`lg`) — mismo
  breakpoint que ya usa el resto de la app (`ProductosPage`,
  `InventarioPage`).
- **`TarjetaCaja`**: si `sesion_abierta` es `null`, muestra el nombre y
  un botón "Abrir" (deshabilitado si el usuario no tiene el permiso
  `caja.abrir`) que dispara `ModalAbrirCaja` con ese `caja_id`. Si tiene
  `sesion_abierta`, muestra "🟢 Abierta por {usuario.nombre} · {duración}"
  y un botón "Ver detalle" que navega a la vista de sesión existente
  (el bloque "Caja activa" que ya existe hoy — gastos, cerrar, balance —
  sin cambios de diseño, solo que ahora se llega ahí eligiendo la
  tarjeta en vez de tenerla como única vista).
- El **historial de cierres** (tabla/cards ya existentes, líneas
  270-388 del archivo actual) no cambia de diseño, pero ahora puede
  filtrarse implícitamente por la sucursal elegida (ya que
  `getSesiones()` se sigue llamando igual, sin cambios de esa función).
- `ModalAbrirCaja` cambia de "monto + sucursal opcional" (Fase 5) a
  "monto" solamente — el `caja_id` ya viene fijo de la tarjeta que
  disparó el modal, no hace falta elegirlo de nuevo ahí.

## Fuera de alcance

- No se toca Inventario ni Productos de la Fase 5 (siguen usando
  `sucursal_id` libre para acceso-todas, sin relación con `cajas`).
- No hay asignación de una caja a un cajero específico (cualquier
  usuario con permiso `caja.abrir` de esa sucursal puede abrir
  cualquiera de sus cajas) — no pedido.
- No se agregan reportes nuevos por caja individual — el reporte de
  Caja (Fase 4) sigue agregando por sucursal, no por caja. Se puede
  agregar después si hace falta desglosar por punto de cobro.
