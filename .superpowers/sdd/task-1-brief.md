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

