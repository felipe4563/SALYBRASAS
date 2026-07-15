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

