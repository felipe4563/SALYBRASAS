# Task 1 Report: Migración y modelos (GrupoOpciones, Opcion, Producto.grupo_opciones_id)

## Status
DONE

## Qué se hizo
Implementé completamente la Task 1 según el brief, creando la infraestructura de base de datos y modelos Sequelize para soportar grupos de opciones/variantes por producto. Esta es la base para futuras tareas que permitirán asignar opciones (como "Término de cocción": Jugoso/Término medio/Bien cocido) a productos del sistema.

## Pasos ejecutados

### Step 1: Migración SQL
Archivo creado: `backend/database/migrations/017_opciones_producto.sql`

Contiene:
- Tabla `grupos_opciones` (id, nombre, timestamps)
- Tabla `opciones` (id, grupo_opciones_id, nombre, orden, timestamps con FK en cascada)
- Alter table en `productos` agregando columna `grupo_opciones_id` (nullable con FK en SET NULL)

### Step 2: Aplicar la migración
Comando ejecutado:
```bash
cd backend
Get-Content database/migrations/017_opciones_producto.sql | mysql -u root bd_restaurante
```
**Resultado:** Éxito, sin errores. Las tres instrucciones SQL se ejecutaron correctamente.

### Step 3-4: Modelos Sequelize
- `backend/src/models/GrupoOpciones.js` - Modelo con campos id, nombre
- `backend/src/models/Opcion.js` - Modelo con campos id, grupo_opciones_id, nombre, orden

### Step 5: Modificar Producto.js
Agregué campo `grupo_opciones_id` (tipo INTEGER.UNSIGNED, nullable) después de `categoria_id` en el modelo Producto.

### Step 6: Registrar en index.js
- Agregué requires para GrupoOpciones y Opcion
- Definí todas las asociaciones:
  - `GrupoOpciones.hasMany(Opcion)` con alias 'opciones'
  - `Opcion.belongsTo(GrupoOpciones)` con alias 'grupo'
  - `Producto.belongsTo(GrupoOpciones)` con alias 'grupo_opciones'
  - `GrupoOpciones.hasMany(Producto)` con alias 'productos'
- Exporté ambos modelos en module.exports

### Step 7: Test
Archivo creado: `backend/tests/opciones.model.test.js`

Contiene 2 tests:
1. "crea un grupo de opciones con sus opciones asociadas" - Verifica que se puede crear un grupo y cargar sus opciones con include
2. "un producto puede asignarse a un grupo de opciones, y al borrar el grupo queda sin asignar" - Verifica FK ON DELETE SET NULL

También creé `backend/tests/setup.js` para cargar dotenv en los tests, e actualicé `backend/package.json` para usar este setup file.

### Step 8: Ejecución del test
Comando:
```bash
npx jest tests/opciones.model.test.js
```

**Resultado:**
```
Test Suites: 1 passed, 1 total
Tests:       2 passed, 2 total
Snapshots:   0 total
Time:        1.127 s
```

Ambos tests pasaron exitosamente.

### Step 9: Commit
Comando ejecutado:
```bash
git add backend/database/migrations/017_opciones_producto.sql backend/src/models/GrupoOpciones.js backend/src/models/Opcion.js backend/src/models/Producto.js backend/src/models/index.js backend/tests/opciones.model.test.js backend/tests/setup.js backend/package.json
git commit -m "feat(productos): modelo de grupos de opciones y opciones por producto"
```

**Resultado:**
```
[main a2059d1] feat(productos): modelo de grupos de opciones y opciones por producto
 8 files changed, 102 insertions(+)
 create mode 100644 backend/database/migrations/017_opciones_producto.sql
 create mode 100644 backend/src/models/GrupoOpciones.js
 create mode 100644 backend/src/models/Opcion.js
 create mode 100644 backend/tests/opciones.model.test.js
 create mode 100644 backend/tests/setup.js
```

## Archivos finales creados/modificados

**Creados:**
- `backend/database/migrations/017_opciones_producto.sql` - Migración SQL
- `backend/src/models/GrupoOpciones.js` - Modelo GrupoOpciones
- `backend/src/models/Opcion.js` - Modelo Opcion
- `backend/tests/opciones.model.test.js` - Tests de los modelos
- `backend/tests/setup.js` - Setup file para jest con dotenv

**Modificados:**
- `backend/src/models/Producto.js` - Agregado campo grupo_opciones_id
- `backend/src/models/index.js` - Agregados requires, asociaciones y exports
- `backend/package.json` - Agregado setupFilesAfterEnv en jest config

## Detalles técnicos

### Asociaciones Sequelize implementadas
Las asociaciones garantizan:
1. Un GrupoOpciones puede tener muchas Opciones (hasMany)
2. Una Opcion pertenece a un GrupoOpciones (belongsTo)
3. Un Producto puede tener un GrupoOpciones (belongsTo) - nullable
4. Un GrupoOpciones puede tener muchos Productos (hasMany)

### Comportamiento de FKs
- `opciones.grupo_opciones_id` → ON DELETE CASCADE (al borrar grupo, se borran sus opciones)
- `productos.grupo_opciones_id` → ON DELETE SET NULL (al borrar grupo, el producto queda sin asignar)

### Notas de implementación
- Usado `setupFilesAfterEnv` en jest config para cargar dotenv automáticamente en tests
- Todos los timestamps utilizan la convención ya existente (creado_en, actualizado_en)
- Campo `orden` en opciones permite futuros ordenamientos personalizados
- Campo `grupo_opciones_id` en Producto es nullable, permitiendo productos sin opciones asignadas

## Resultado
✓ Task 1 completada exitosamente
✓ 2 tests pasando
✓ Commit realizado: a2059d1
✓ Base de datos actualizada
✓ Todos los modelos y asociaciones funcionando correctamente
