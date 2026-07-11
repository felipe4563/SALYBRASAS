# Task 2: Conexión a base de datos

**Objetivo:** Crear la configuración de Sequelize con las opciones correctas para MySQL, timezone Bolivia y timestamps en español.

**Directorio de trabajo:** `c:/Users/ASUS/OneDrive/Escritorio/TODO/SISTEMAS/RESTAURANTE/backend/`

**Contexto:** El scaffolding base ya existe (Task 1 completada). El proyecto tiene Express 4, dotenv, y Sequelize instalados. Git ya está inicializado.

## Global Constraints

- Base de datos completamente en español (tablas y columnas)
- Moneda: Bs (Bolivia), zona horaria: `America/La_Paz`
- Puerto backend: 3001
- Node.js 20+, Express 4, Sequelize 6, MySQL 8

## Archivos a crear

- `backend/src/config/database.js`

## Pasos

### Step 1: Crear `src/config/database.js`

```js
const { Sequelize } = require('sequelize');

const sequelize = new Sequelize(
  process.env.DB_NAME,
  process.env.DB_USER,
  process.env.DB_PASS,
  {
    host: process.env.DB_HOST,
    port: process.env.DB_PORT || 3306,
    dialect: 'mysql',
    timezone: 'America/La_Paz',
    logging: process.env.NODE_ENV === 'development' ? console.log : false,
    define: {
      timestamps: true,
      createdAt: 'creado_en',
      updatedAt: 'actualizado_en',
      underscored: true,
    },
  }
);

module.exports = sequelize;
```

### Step 2: Verificar que `.env` tenga las credenciales correctas

El `.env` ya existe desde Task 1. Solo confirma que tiene valores para:
- `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASS`

Si `DB_NAME` no tiene un valor concreto, usa `restaurante_db`.

### Step 3: Probar la conexión

Agrega temporalmente en `src/server.js` (después del require de app):

```js
const sequelize = require('./config/database');
sequelize.authenticate()
  .then(() => console.log('DB conectada'))
  .catch(err => console.error('Error DB:', err.message));
```

Corre `node src/server.js` para verificar (si la DB no existe aún está bien, solo confirma que no hay error de sintaxis/import; si hay error de conexión es esperado sin DB activa — el test real se hará en Task 4).

### Step 4: Quitar el bloque temporal de `server.js`

Deja `server.js` exactamente como estaba antes de agregar el bloque temporal.

### Step 5: Commit

```bash
git add src/config/database.js
git commit -m "feat: configurar conexión Sequelize con MySQL y timezone Bolivia"
```

## Report contract

Escribe el resultado en `.superpowers/sdd/task-2-report.md`:
```
STATUS: DONE

Commits:
- <hash> feat: configurar conexión Sequelize con MySQL y timezone Bolivia

Tests: N/A

Archivos creados:
- src/config/database.js
```
