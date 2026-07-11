# Task 1: Scaffolding del proyecto

**Objetivo:** Crear la estructura base del backend Node.js + Express con package.json, scripts, middlewares básicos y health check endpoint.

**Directorio de trabajo:** `c:/Users/ASUS/OneDrive/Escritorio/TODO/SISTEMAS/RESTAURANTE/backend/`

> Crear la carpeta `backend/` si no existe todavía.

## Global Constraints

- Base de datos completamente en español (tablas y columnas) — no aplica a esta task aún
- Prefijo API: `/api/v1`
- Puerto backend: 3001
- Todos los errores responden con `{ ok: false, mensaje: "..." }`
- Todos los éxitos responden con `{ ok: true, datos: ... }`
- Node.js 20+, Express 4

## Files a crear

- `backend/package.json`
- `backend/.env.example`
- `backend/.gitignore`
- `backend/src/app.js`
- `backend/src/server.js`

## Pasos

### Step 1: Crear carpeta e inicializar npm

```bash
cd c:/Users/ASUS/OneDrive/Escritorio/TODO/SISTEMAS/RESTAURANTE
mkdir backend
cd backend
npm init -y
```

### Step 2: Instalar dependencias

```bash
npm install express sequelize mysql2 jsonwebtoken bcryptjs dotenv cors express-validator
npm install --save-dev nodemon jest supertest
```

### Step 3: Crear `.env.example`

```env
PORT=3001
DB_HOST=localhost
DB_PORT=3306
DB_NAME=restaurante_db
DB_USER=root
DB_PASS=
JWT_SECRET=cambia_este_secreto_en_produccion
JWT_REFRESH_SECRET=cambia_este_refresh_secreto
JWT_EXPIRES_IN=8h
JWT_REFRESH_EXPIRES_IN=7d
NODE_ENV=development
```

Copiar a `.env` y agregar `.env` al `.gitignore`.

### Step 4: Crear `src/app.js`

```js
const express = require('express');
const cors = require('cors');

const app = express();

app.use(cors());
app.use(express.json());

app.get('/api/v1/salud', (_req, res) => {
  res.json({ ok: true, datos: 'API restaurante funcionando' });
});

module.exports = app;
```

### Step 5: Crear `src/server.js`

```js
require('dotenv').config();
const app = require('./app');

const PORT = process.env.PORT || 3001;

app.listen(PORT, () => {
  console.log(`Servidor corriendo en puerto ${PORT}`);
});
```

### Step 6: Actualizar `package.json` con scripts

```json
"scripts": {
  "start": "node src/server.js",
  "dev": "nodemon src/server.js",
  "test": "jest --runInBand"
},
"jest": {
  "testEnvironment": "node"
}
```

### Step 7: Crear `.gitignore`

```
node_modules/
.env
dist/
```

### Step 8: Init git y commit

```bash
git init
git add .
git commit -m "feat: scaffolding backend Node.js + Express"
```

### Step 9: Verificar

```bash
node src/server.js
# En otra terminal:
curl http://localhost:3001/api/v1/salud
# Esperado: {"ok":true,"datos":"API restaurante funcionando"}
```

Matar el servidor después de verificar (Ctrl+C).

## Report contract

Cuando termines, escribe el resultado en `.superpowers/sdd/task-1-report.md` con:
- STATUS: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
- Commits creados (hash corto)
- Resumen de tests (si aplica)
- Concerns (si STATUS=DONE_WITH_CONCERNS)
