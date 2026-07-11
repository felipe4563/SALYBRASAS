# Task 1: Report

STATUS: DONE

## Commits

- `e03cbb2` feat: scaffolding backend Node.js + Express

## Tests

N/A (no hay tests en Task 1)

## Archivos creados

- `backend/package.json` - Configurado con scripts (start, dev, test) y jest config
- `backend/.env.example` - Variables de entorno de ejemplo
- `backend/.env` - Variables de entorno (copia de .env.example)
- `backend/.gitignore` - Configurado para ignorar node_modules/, .env, dist/
- `backend/src/app.js` - App Express con CORS, JSON parser y endpoint GET /api/v1/salud
- `backend/src/server.js` - Server entry point que carga dotenv y levanta servidor en puerto 3001

## Verificación

- Servidor inicia correctamente en puerto 3001
- Endpoint `/api/v1/salud` responde con formato correcto: `{"ok":true,"datos":"API restaurante funcionando"}`
- Git repository inicializado y primer commit realizado
- Todas las dependencias instaladas (Express, Sequelize, MySQL2, JWT, bcryptjs, dotenv, CORS, express-validator, nodemon, Jest, supertest)
