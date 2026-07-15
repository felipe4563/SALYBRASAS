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

