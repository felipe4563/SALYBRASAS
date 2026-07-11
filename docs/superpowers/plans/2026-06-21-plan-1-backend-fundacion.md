# Backend Fundación — Plan de Implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Crear el backend Node.js con Express, base de datos MySQL completa en español, autenticación JWT y sistema de roles/permisos configurables.

**Architecture:** API REST con Express organizada por módulos. Sequelize como ORM con migraciones y seeders. JWT con access token (8h) + refresh token (7 días). Middleware de permisos que verifica `modulo.accion` contra los permisos asignados al rol del usuario.

**Tech Stack:** Node.js 20+, Express 4, Sequelize 6, MySQL 8, jsonwebtoken, bcryptjs, dotenv, express-validator

## Global Constraints

- Base de datos completamente en español (tablas y columnas)
- Moneda: Bs (Bolivia), zona horaria: America/La_Paz
- Prefijo API: `/api/v1`
- Puerto backend: 3001
- Todos los errores responden con `{ ok: false, mensaje: "..." }`
- Todos los éxitos responden con `{ ok: true, datos: ... }`

---

## Mapa de Archivos

```
backend/
├── .env.example
├── package.json
├── src/
│   ├── app.js                          # Express app (sin listen)
│   ├── server.js                       # listen + arranque
│   ├── config/
│   │   └── database.js                 # instancia Sequelize
│   ├── middlewares/
│   │   ├── auth.js                     # verificar JWT → req.usuario
│   │   ├── permisos.js                 # verificar permiso requerido
│   │   └── errores.js                  # handler global de errores
│   ├── modules/
│   │   ├── auth/
│   │   │   ├── auth.routes.js
│   │   │   ├── auth.controller.js
│   │   │   └── auth.service.js
│   │   └── roles/
│   │       ├── roles.routes.js
│   │       ├── roles.controller.js
│   │       ├── roles.service.js
│   │       └── models/
│   │           ├── Rol.js
│   │           └── Permiso.js
│   └── models/                         # modelos Sequelize de todas las tablas
│       ├── index.js                    # carga modelos y asociaciones
│       ├── Usuario.js
│       ├── Rol.js
│       ├── Permiso.js
│       ├── Area.js
│       ├── Mesa.js
│       ├── Categoria.js
│       ├── Producto.js
│       ├── IngredienteProducto.js
│       ├── Cliente.js
│       ├── SesionCaja.js
│       ├── Pedido.js
│       ├── DetallePedido.js
│       ├── RegistroInventario.js
│       ├── Proveedor.js
│       ├── Compra.js
│       ├── DetalleCompra.js
│       ├── DetalleArqueo.js
│       ├── Gasto.js
│       ├── LibroCaja.js
│       ├── Reservacion.js
│       └── Configuracion.js
├── database/
│   ├── migrations/                     # un archivo SQL por grupo de tablas
│   │   ├── 001_roles_permisos.sql
│   │   ├── 002_usuarios.sql
│   │   ├── 003_areas_mesas.sql
│   │   ├── 004_categorias_productos.sql
│   │   ├── 005_clientes.sql
│   │   ├── 006_sesiones_caja.sql
│   │   ├── 007_pedidos.sql
│   │   ├── 008_inventario.sql
│   │   ├── 009_compras.sql
│   │   ├── 010_caja_libro.sql
│   │   └── 011_reservaciones_config.sql
│   └── seeds/
│       └── seed.js                     # roles, permisos, usuario admin
└── tests/
    ├── auth.test.js
    └── roles.test.js
```

---

### Task 1: Scaffolding del proyecto

**Files:**
- Create: `backend/package.json`
- Create: `backend/.env.example`
- Create: `backend/src/app.js`
- Create: `backend/src/server.js`

**Interfaces:**
- Produces: `app` Express exportado desde `src/app.js` (usado por todos los módulos y tests)

- [ ] **Step 1: Crear carpeta e inicializar npm**

```bash
cd c:/Users/ASUS/OneDrive/Escritorio/TODO/SISTEMAS/RESTAURANTE
mkdir backend && cd backend
npm init -y
```

- [ ] **Step 2: Instalar dependencias**

```bash
npm install express sequelize mysql2 jsonwebtoken bcryptjs dotenv cors express-validator
npm install --save-dev nodemon jest supertest
```

- [ ] **Step 3: Crear `.env.example`**

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

Copiar a `.env` y llenar los valores reales. Agregar `.env` al `.gitignore`.

- [ ] **Step 4: Crear `src/app.js`**

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

- [ ] **Step 5: Crear `src/server.js`**

```js
require('dotenv').config();
const app = require('./app');

const PORT = process.env.PORT || 3001;

app.listen(PORT, () => {
  console.log(`Servidor corriendo en puerto ${PORT}`);
});
```

- [ ] **Step 6: Agregar scripts a `package.json`**

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

- [ ] **Step 7: Verificar que el servidor arranca**

```bash
npm run dev
```
Esperado: `Servidor corriendo en puerto 3001`

Probar: `curl http://localhost:3001/api/v1/salud`
Esperado: `{"ok":true,"datos":"API restaurante funcionando"}`

- [ ] **Step 8: Commit**

```bash
git init
echo "node_modules/" > .gitignore
echo ".env" >> .gitignore
git add .
git commit -m "feat: scaffolding backend Node.js + Express"
```

---

### Task 2: Conexión a base de datos

**Files:**
- Create: `backend/src/config/database.js`

**Interfaces:**
- Produces: `sequelize` instancia exportada (usada por todos los modelos)

- [ ] **Step 1: Crear `src/config/database.js`**

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

- [ ] **Step 2: Probar conexión agregando temporalmente en `server.js`**

```js
// Agregar después del require de app:
const sequelize = require('./config/database');
sequelize.authenticate()
  .then(() => console.log('DB conectada'))
  .catch(err => console.error('Error DB:', err));
```

- [ ] **Step 3: Verificar**

```bash
npm run dev
```
Esperado: `DB conectada` en consola. Si falla, revisar variables en `.env`.

- [ ] **Step 4: Quitar el bloque temporal de `server.js`** (se conectará via `models/index.js` en Task 3)

- [ ] **Step 5: Commit**

```bash
git add src/config/database.js
git commit -m "feat: configurar conexión Sequelize + MySQL"
```

---

### Task 3: Migraciones — crear base de datos completa

**Files:**
- Create: `backend/database/migrations/001_roles_permisos.sql`
- Create: `backend/database/migrations/002_usuarios.sql`
- Create: `backend/database/migrations/003_areas_mesas.sql`
- Create: `backend/database/migrations/004_categorias_productos.sql`
- Create: `backend/database/migrations/005_clientes.sql`
- Create: `backend/database/migrations/006_sesiones_caja.sql`
- Create: `backend/database/migrations/007_pedidos.sql`
- Create: `backend/database/migrations/008_inventario.sql`
- Create: `backend/database/migrations/009_compras.sql`
- Create: `backend/database/migrations/010_caja_libro.sql`
- Create: `backend/database/migrations/011_reservaciones_config.sql`

**Interfaces:**
- Produces: base de datos `restaurante_db` con todas las tablas en español

- [ ] **Step 1: Crear base de datos en MySQL**

```sql
CREATE DATABASE IF NOT EXISTS restaurante_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE restaurante_db;
```

- [ ] **Step 2: `001_roles_permisos.sql`**

```sql
CREATE TABLE IF NOT EXISTS roles (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  descripcion VARCHAR(255),
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS permisos (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  modulo VARCHAR(50) NOT NULL,
  accion VARCHAR(50) NOT NULL,
  descripcion VARCHAR(255),
  UNIQUE KEY permiso_unico (modulo, accion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS roles_permisos (
  rol_id INT UNSIGNED NOT NULL,
  permiso_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (rol_id, permiso_id),
  FOREIGN KEY (rol_id) REFERENCES roles(id) ON DELETE CASCADE,
  FOREIGN KEY (permiso_id) REFERENCES permisos(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- [ ] **Step 3: `002_usuarios.sql`**

```sql
CREATE TABLE IF NOT EXISTS usuarios (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  rol_id INT UNSIGNED NOT NULL,
  nombre VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL,
  contrasena VARCHAR(255) NOT NULL,
  activo TINYINT(1) NOT NULL DEFAULT 1,
  token_recordar VARCHAR(255),
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY usuarios_email_unique (email),
  FOREIGN KEY (rol_id) REFERENCES roles(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- [ ] **Step 4: `003_areas_mesas.sql`**

```sql
CREATE TABLE IF NOT EXISTS areas (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(255) NOT NULL,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS mesas (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  area_id INT UNSIGNED NOT NULL,
  nombre VARCHAR(100) NOT NULL,
  asientos INT NOT NULL DEFAULT 4,
  estado ENUM('disponible','ocupada','reservada') NOT NULL DEFAULT 'disponible',
  pos_x INT NOT NULL DEFAULT 0,
  pos_y INT NOT NULL DEFAULT 0,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (area_id) REFERENCES areas(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- [ ] **Step 5: `004_categorias_productos.sql`**

```sql
CREATE TABLE IF NOT EXISTS categorias (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(255) NOT NULL,
  imagen VARCHAR(255),
  activo TINYINT(1) NOT NULL DEFAULT 1,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS productos (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  categoria_id INT UNSIGNED NOT NULL,
  nombre VARCHAR(255) NOT NULL,
  codigo_barras VARCHAR(255),
  codigo VARCHAR(100),
  precio DECIMAL(10,2) NOT NULL,
  costo DECIMAL(10,2),
  stock INT DEFAULT NULL,
  es_vendible TINYINT(1) NOT NULL DEFAULT 1,
  imagen VARCHAR(255),
  activo TINYINT(1) NOT NULL DEFAULT 1,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY productos_barcode_unique (codigo_barras),
  FOREIGN KEY (categoria_id) REFERENCES categorias(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ingredientes_producto (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  producto_id INT UNSIGNED NOT NULL,
  ingrediente_id INT UNSIGNED NOT NULL,
  cantidad DECIMAL(10,2) NOT NULL,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE CASCADE,
  FOREIGN KEY (ingrediente_id) REFERENCES productos(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- [ ] **Step 6: `005_clientes.sql`**

```sql
CREATE TABLE IF NOT EXISTS clientes (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(255) NOT NULL,
  tipo_documento VARCHAR(50) NOT NULL DEFAULT 'CI',
  numero_documento VARCHAR(50),
  email VARCHAR(255),
  telefono VARCHAR(50),
  direccion VARCHAR(255),
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY clientes_doc_unique (numero_documento)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- [ ] **Step 7: `006_sesiones_caja.sql`** (debe ir antes que pedidos)

```sql
CREATE TABLE IF NOT EXISTS sesiones_caja (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT UNSIGNED NOT NULL,
  monto_apertura DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  monto_cierre DECIMAL(10,2),
  total_ventas DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  total_gastos DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  diferencia DECIMAL(10,2),
  abierto_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  cerrado_en TIMESTAMP,
  estado ENUM('abierta','cerrada') NOT NULL DEFAULT 'abierta',
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- [ ] **Step 8: `007_pedidos.sql`**

```sql
CREATE TABLE IF NOT EXISTS pedidos (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  mesa_id INT UNSIGNED NOT NULL,
  usuario_id INT UNSIGNED NOT NULL,
  cliente_id INT UNSIGNED,
  sesion_caja_id INT UNSIGNED,
  estado ENUM('pendiente','completado','cancelado') NOT NULL DEFAULT 'pendiente',
  tipo_documento VARCHAR(50) NOT NULL DEFAULT 'Ticket',
  nombre_cliente VARCHAR(255) NOT NULL DEFAULT 'Público General',
  documento_cliente VARCHAR(50),
  total DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  descuento DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  propina DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  metodo_pago ENUM('efectivo','qr') NOT NULL DEFAULT 'efectivo',
  monto_recibido DECIMAL(10,2),
  cambio DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  notas TEXT,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (mesa_id) REFERENCES mesas(id),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
  FOREIGN KEY (cliente_id) REFERENCES clientes(id) ON DELETE SET NULL,
  FOREIGN KEY (sesion_caja_id) REFERENCES sesiones_caja(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS detalle_pedidos (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  pedido_id INT UNSIGNED NOT NULL,
  producto_id INT UNSIGNED NOT NULL,
  cantidad INT NOT NULL DEFAULT 1,
  precio DECIMAL(10,2) NOT NULL,
  nota VARCHAR(255),
  estado ENUM('pendiente','preparando','servido') NOT NULL DEFAULT 'pendiente',
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (pedido_id) REFERENCES pedidos(id) ON DELETE CASCADE,
  FOREIGN KEY (producto_id) REFERENCES productos(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- [ ] **Step 9: `008_inventario.sql`**

```sql
CREATE TABLE IF NOT EXISTS registros_inventario (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  producto_id INT UNSIGNED NOT NULL,
  usuario_id INT UNSIGNED NOT NULL,
  tipo ENUM('entrada','salida','venta','compra','ajuste') NOT NULL,
  cantidad INT NOT NULL,
  stock_anterior INT,
  stock_nuevo INT,
  nota VARCHAR(255),
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE CASCADE,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- [ ] **Step 10: `009_compras.sql`**

```sql
CREATE TABLE IF NOT EXISTS proveedores (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(255) NOT NULL,
  contacto VARCHAR(255),
  telefono VARCHAR(50),
  email VARCHAR(255),
  direccion VARCHAR(255),
  activo TINYINT(1) NOT NULL DEFAULT 1,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS compras (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  proveedor_id INT UNSIGNED NOT NULL,
  usuario_id INT UNSIGNED NOT NULL,
  total DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  notas TEXT,
  estado ENUM('pendiente','recibido') NOT NULL DEFAULT 'pendiente',
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (proveedor_id) REFERENCES proveedores(id),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS detalle_compras (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  compra_id INT UNSIGNED NOT NULL,
  producto_id INT UNSIGNED NOT NULL,
  cantidad INT NOT NULL,
  costo_unitario DECIMAL(10,2) NOT NULL,
  subtotal DECIMAL(10,2) NOT NULL,
  FOREIGN KEY (compra_id) REFERENCES compras(id) ON DELETE CASCADE,
  FOREIGN KEY (producto_id) REFERENCES productos(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- [ ] **Step 11: `010_caja_libro.sql`**

```sql
CREATE TABLE IF NOT EXISTS detalle_arqueo (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sesion_caja_id INT UNSIGNED NOT NULL,
  denominacion DECIMAL(10,2) NOT NULL,
  cantidad INT NOT NULL DEFAULT 0,
  subtotal DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  FOREIGN KEY (sesion_caja_id) REFERENCES sesiones_caja(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS gastos (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sesion_caja_id INT UNSIGNED,
  usuario_id INT UNSIGNED NOT NULL,
  descripcion VARCHAR(255) NOT NULL,
  monto DECIMAL(10,2) NOT NULL,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (sesion_caja_id) REFERENCES sesiones_caja(id) ON DELETE SET NULL,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS libro_caja (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sesion_caja_id INT UNSIGNED,
  usuario_id INT UNSIGNED NOT NULL,
  tipo ENUM('ingreso','egreso') NOT NULL,
  concepto VARCHAR(255) NOT NULL,
  monto DECIMAL(10,2) NOT NULL,
  metodo_pago ENUM('efectivo','qr') NOT NULL DEFAULT 'efectivo',
  referencia_id INT UNSIGNED,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (sesion_caja_id) REFERENCES sesiones_caja(id) ON DELETE SET NULL,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- [ ] **Step 12: `011_reservaciones_config.sql`**

```sql
CREATE TABLE IF NOT EXISTS reservaciones (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre_cliente VARCHAR(255) NOT NULL,
  telefono VARCHAR(50),
  hora_reserva DATETIME NOT NULL,
  personas INT NOT NULL,
  mesa_id INT UNSIGNED,
  nota TEXT,
  estado ENUM('pendiente','confirmada','cancelada') NOT NULL DEFAULT 'pendiente',
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (mesa_id) REFERENCES mesas(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS configuraciones (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  clave VARCHAR(100) NOT NULL,
  valor TEXT,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY configuraciones_clave_unique (clave)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- [ ] **Step 13: Ejecutar migraciones en orden**

```bash
# En MySQL client o HeidiSQL, ejecutar en orden del 001 al 011
mysql -u root -p restaurante_db < database/migrations/001_roles_permisos.sql
mysql -u root -p restaurante_db < database/migrations/002_usuarios.sql
mysql -u root -p restaurante_db < database/migrations/003_areas_mesas.sql
mysql -u root -p restaurante_db < database/migrations/004_categorias_productos.sql
mysql -u root -p restaurante_db < database/migrations/005_clientes.sql
mysql -u root -p restaurante_db < database/migrations/006_sesiones_caja.sql
mysql -u root -p restaurante_db < database/migrations/007_pedidos.sql
mysql -u root -p restaurante_db < database/migrations/008_inventario.sql
mysql -u root -p restaurante_db < database/migrations/009_compras.sql
mysql -u root -p restaurante_db < database/migrations/010_caja_libro.sql
mysql -u root -p restaurante_db < database/migrations/011_reservaciones_config.sql
```

Verificar: `SHOW TABLES;` debe mostrar 20 tablas.

- [ ] **Step 14: Commit**

```bash
git add database/
git commit -m "feat: migraciones SQL completas en español"
```

---

### Task 4: Modelos Sequelize

**Files:**
- Create: `backend/src/models/index.js`
- Create: `backend/src/models/Rol.js`
- Create: `backend/src/models/Permiso.js`
- Create: `backend/src/models/Usuario.js`
- Create: `backend/src/models/Area.js`
- Create: `backend/src/models/Mesa.js`
- Create: `backend/src/models/Categoria.js`
- Create: `backend/src/models/Producto.js`
- Create: `backend/src/models/Cliente.js`
- Create: `backend/src/models/SesionCaja.js`
- Create: `backend/src/models/Pedido.js`
- Create: `backend/src/models/DetallePedido.js`
- Modify: `backend/src/server.js`

**Interfaces:**
- Produces: modelos Sequelize exportados desde `src/models/index.js` como `{ Rol, Permiso, Usuario, Mesa, Pedido, ... }`

- [ ] **Step 1: Crear `src/models/Rol.js`**

```js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Rol = sequelize.define('Rol', {
  id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
  nombre: { type: DataTypes.STRING(100), allowNull: false },
  descripcion: { type: DataTypes.STRING(255) },
}, {
  tableName: 'roles',
  createdAt: 'creado_en',
  updatedAt: 'actualizado_en',
});

module.exports = Rol;
```

- [ ] **Step 2: Crear `src/models/Permiso.js`**

```js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Permiso = sequelize.define('Permiso', {
  id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
  modulo: { type: DataTypes.STRING(50), allowNull: false },
  accion: { type: DataTypes.STRING(50), allowNull: false },
  descripcion: { type: DataTypes.STRING(255) },
}, {
  tableName: 'permisos',
  createdAt: 'creado_en',
  updatedAt: 'actualizado_en',
  timestamps: false,
});

module.exports = Permiso;
```

- [ ] **Step 3: Crear `src/models/Usuario.js`**

```js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Usuario = sequelize.define('Usuario', {
  id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
  rol_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
  nombre: { type: DataTypes.STRING(255), allowNull: false },
  email: { type: DataTypes.STRING(255), allowNull: false, unique: true },
  contrasena: { type: DataTypes.STRING(255), allowNull: false },
  activo: { type: DataTypes.TINYINT(1), defaultValue: 1 },
  token_recordar: { type: DataTypes.STRING(255) },
}, {
  tableName: 'usuarios',
  createdAt: 'creado_en',
  updatedAt: 'actualizado_en',
});

module.exports = Usuario;
```

- [ ] **Step 4: Crear `src/models/Area.js`**

```js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Area = sequelize.define('Area', {
  id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
  nombre: { type: DataTypes.STRING(255), allowNull: false },
}, {
  tableName: 'areas',
  createdAt: 'creado_en',
  updatedAt: 'actualizado_en',
});

module.exports = Area;
```

- [ ] **Step 5: Crear `src/models/Mesa.js`**

```js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Mesa = sequelize.define('Mesa', {
  id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
  area_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
  nombre: { type: DataTypes.STRING(100), allowNull: false },
  asientos: { type: DataTypes.INTEGER, defaultValue: 4 },
  estado: { type: DataTypes.ENUM('disponible','ocupada','reservada'), defaultValue: 'disponible' },
  pos_x: { type: DataTypes.INTEGER, defaultValue: 0 },
  pos_y: { type: DataTypes.INTEGER, defaultValue: 0 },
}, {
  tableName: 'mesas',
  createdAt: 'creado_en',
  updatedAt: 'actualizado_en',
});

module.exports = Mesa;
```

- [ ] **Step 6: Crear `src/models/Categoria.js`**

```js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Categoria = sequelize.define('Categoria', {
  id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
  nombre: { type: DataTypes.STRING(255), allowNull: false },
  imagen: { type: DataTypes.STRING(255) },
  activo: { type: DataTypes.TINYINT(1), defaultValue: 1 },
}, {
  tableName: 'categorias',
  createdAt: 'creado_en',
  updatedAt: 'actualizado_en',
});

module.exports = Categoria;
```

- [ ] **Step 7: Crear `src/models/Producto.js`**

```js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Producto = sequelize.define('Producto', {
  id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
  categoria_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
  nombre: { type: DataTypes.STRING(255), allowNull: false },
  codigo_barras: { type: DataTypes.STRING(255), unique: true },
  codigo: { type: DataTypes.STRING(100) },
  precio: { type: DataTypes.DECIMAL(10,2), allowNull: false },
  costo: { type: DataTypes.DECIMAL(10,2) },
  stock: { type: DataTypes.INTEGER },
  es_vendible: { type: DataTypes.TINYINT(1), defaultValue: 1 },
  imagen: { type: DataTypes.STRING(255) },
  activo: { type: DataTypes.TINYINT(1), defaultValue: 1 },
}, {
  tableName: 'productos',
  createdAt: 'creado_en',
  updatedAt: 'actualizado_en',
});

module.exports = Producto;
```

- [ ] **Step 8: Crear `src/models/Cliente.js`**

```js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Cliente = sequelize.define('Cliente', {
  id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
  nombre: { type: DataTypes.STRING(255), allowNull: false },
  tipo_documento: { type: DataTypes.STRING(50), defaultValue: 'CI' },
  numero_documento: { type: DataTypes.STRING(50), unique: true },
  email: { type: DataTypes.STRING(255) },
  telefono: { type: DataTypes.STRING(50) },
  direccion: { type: DataTypes.STRING(255) },
}, {
  tableName: 'clientes',
  createdAt: 'creado_en',
  updatedAt: 'actualizado_en',
});

module.exports = Cliente;
```

- [ ] **Step 9: Crear `src/models/SesionCaja.js`**

```js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const SesionCaja = sequelize.define('SesionCaja', {
  id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
  usuario_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
  monto_apertura: { type: DataTypes.DECIMAL(10,2), defaultValue: 0 },
  monto_cierre: { type: DataTypes.DECIMAL(10,2) },
  total_ventas: { type: DataTypes.DECIMAL(10,2), defaultValue: 0 },
  total_gastos: { type: DataTypes.DECIMAL(10,2), defaultValue: 0 },
  diferencia: { type: DataTypes.DECIMAL(10,2) },
  abierto_en: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
  cerrado_en: { type: DataTypes.DATE },
  estado: { type: DataTypes.ENUM('abierta','cerrada'), defaultValue: 'abierta' },
}, {
  tableName: 'sesiones_caja',
  timestamps: false,
});

module.exports = SesionCaja;
```

- [ ] **Step 10: Crear `src/models/Pedido.js`**

```js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Pedido = sequelize.define('Pedido', {
  id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
  mesa_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
  usuario_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
  cliente_id: { type: DataTypes.INTEGER.UNSIGNED },
  sesion_caja_id: { type: DataTypes.INTEGER.UNSIGNED },
  estado: { type: DataTypes.ENUM('pendiente','completado','cancelado'), defaultValue: 'pendiente' },
  tipo_documento: { type: DataTypes.STRING(50), defaultValue: 'Ticket' },
  nombre_cliente: { type: DataTypes.STRING(255), defaultValue: 'Público General' },
  documento_cliente: { type: DataTypes.STRING(50) },
  total: { type: DataTypes.DECIMAL(10,2), defaultValue: 0 },
  descuento: { type: DataTypes.DECIMAL(10,2), defaultValue: 0 },
  propina: { type: DataTypes.DECIMAL(10,2), defaultValue: 0 },
  metodo_pago: { type: DataTypes.ENUM('efectivo','qr'), defaultValue: 'efectivo' },
  monto_recibido: { type: DataTypes.DECIMAL(10,2) },
  cambio: { type: DataTypes.DECIMAL(10,2), defaultValue: 0 },
  notas: { type: DataTypes.TEXT },
}, {
  tableName: 'pedidos',
  createdAt: 'creado_en',
  updatedAt: 'actualizado_en',
});

module.exports = Pedido;
```

- [ ] **Step 11: Crear `src/models/DetallePedido.js`**

```js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const DetallePedido = sequelize.define('DetallePedido', {
  id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
  pedido_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
  producto_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
  cantidad: { type: DataTypes.INTEGER, defaultValue: 1 },
  precio: { type: DataTypes.DECIMAL(10,2), allowNull: false },
  nota: { type: DataTypes.STRING(255) },
  estado: { type: DataTypes.ENUM('pendiente','preparando','servido'), defaultValue: 'pendiente' },
}, {
  tableName: 'detalle_pedidos',
  createdAt: 'creado_en',
  updatedAt: 'actualizado_en',
});

module.exports = DetallePedido;
```

- [ ] **Step 12: Crear `src/models/index.js` con asociaciones**

```js
const sequelize = require('../config/database');

const Rol = require('./Rol');
const Permiso = require('./Permiso');
const Usuario = require('./Usuario');
const Area = require('./Area');
const Mesa = require('./Mesa');
const Categoria = require('./Categoria');
const Producto = require('./Producto');
const Cliente = require('./Cliente');
const SesionCaja = require('./SesionCaja');
const Pedido = require('./Pedido');
const DetallePedido = require('./DetallePedido');

// Roles y Permisos
Rol.belongsToMany(Permiso, { through: 'roles_permisos', foreignKey: 'rol_id', otherKey: 'permiso_id', as: 'permisos' });
Permiso.belongsToMany(Rol, { through: 'roles_permisos', foreignKey: 'permiso_id', otherKey: 'rol_id', as: 'roles' });

// Usuario
Usuario.belongsTo(Rol, { foreignKey: 'rol_id', as: 'rol' });
Rol.hasMany(Usuario, { foreignKey: 'rol_id', as: 'usuarios' });

// Mesas
Mesa.belongsTo(Area, { foreignKey: 'area_id', as: 'area' });
Area.hasMany(Mesa, { foreignKey: 'area_id', as: 'mesas' });

// Productos
Producto.belongsTo(Categoria, { foreignKey: 'categoria_id', as: 'categoria' });
Categoria.hasMany(Producto, { foreignKey: 'categoria_id', as: 'productos' });

// Pedidos
Pedido.belongsTo(Mesa, { foreignKey: 'mesa_id', as: 'mesa' });
Pedido.belongsTo(Usuario, { foreignKey: 'usuario_id', as: 'usuario' });
Pedido.belongsTo(Cliente, { foreignKey: 'cliente_id', as: 'cliente' });
Pedido.belongsTo(SesionCaja, { foreignKey: 'sesion_caja_id', as: 'sesion_caja' });
Pedido.hasMany(DetallePedido, { foreignKey: 'pedido_id', as: 'detalles' });
DetallePedido.belongsTo(Pedido, { foreignKey: 'pedido_id' });
DetallePedido.belongsTo(Producto, { foreignKey: 'producto_id', as: 'producto' });

// SesionCaja
SesionCaja.belongsTo(Usuario, { foreignKey: 'usuario_id', as: 'usuario' });
SesionCaja.hasMany(Pedido, { foreignKey: 'sesion_caja_id', as: 'pedidos' });

module.exports = {
  sequelize,
  Rol, Permiso, Usuario,
  Area, Mesa,
  Categoria, Producto,
  Cliente,
  SesionCaja, Pedido, DetallePedido,
};
```

- [ ] **Step 13: Conectar modelos en `server.js`**

```js
require('dotenv').config();
const app = require('./app');
const { sequelize } = require('./models');

const PORT = process.env.PORT || 3001;

sequelize.authenticate()
  .then(() => {
    console.log('DB conectada');
    app.listen(PORT, () => console.log(`Servidor en puerto ${PORT}`));
  })
  .catch(err => {
    console.error('Error DB:', err);
    process.exit(1);
  });
```

- [ ] **Step 14: Verificar arranque**

```bash
npm run dev
```
Esperado: `DB conectada` y `Servidor en puerto 3001`

- [ ] **Step 15: Commit**

```bash
git add src/models/ src/server.js
git commit -m "feat: modelos Sequelize con asociaciones"
```

---

### Task 5: Seed — datos iniciales

**Files:**
- Create: `backend/database/seeds/seed.js`

**Interfaces:**
- Produces: roles (Administrador, Cajero, Mozo), todos los permisos definidos, usuario admin, configuraciones base

- [ ] **Step 1: Crear `database/seeds/seed.js`**

```js
require('dotenv').config();
const bcrypt = require('bcryptjs');
const { sequelize, Rol, Permiso, Usuario } = require('../../src/models');

const PERMISOS = [
  { modulo: 'ventas', accion: 'ver', descripcion: 'Ver pedidos' },
  { modulo: 'ventas', accion: 'crear', descripcion: 'Crear pedidos' },
  { modulo: 'ventas', accion: 'cancelar', descripcion: 'Cancelar pedidos' },
  { modulo: 'ventas', accion: 'cobrar', descripcion: 'Cobrar pedidos' },
  { modulo: 'usuarios', accion: 'ver', descripcion: 'Ver usuarios' },
  { modulo: 'usuarios', accion: 'crear', descripcion: 'Crear usuarios' },
  { modulo: 'usuarios', accion: 'editar', descripcion: 'Editar usuarios' },
  { modulo: 'usuarios', accion: 'eliminar', descripcion: 'Eliminar usuarios' },
  { modulo: 'inventario', accion: 'ver', descripcion: 'Ver inventario' },
  { modulo: 'inventario', accion: 'ajustar', descripcion: 'Ajustar stock' },
  { modulo: 'inventario', accion: 'entrada', descripcion: 'Registrar entrada' },
  { modulo: 'inventario', accion: 'salida', descripcion: 'Registrar salida' },
  { modulo: 'caja', accion: 'abrir', descripcion: 'Abrir caja' },
  { modulo: 'caja', accion: 'cerrar', descripcion: 'Cerrar caja' },
  { modulo: 'caja', accion: 'ver', descripcion: 'Ver sesiones de caja' },
  { modulo: 'libro_caja', accion: 'ver', descripcion: 'Ver libro caja' },
  { modulo: 'libro_caja', accion: 'crear', descripcion: 'Registrar en libro caja' },
  { modulo: 'compras', accion: 'ver', descripcion: 'Ver compras' },
  { modulo: 'compras', accion: 'crear', descripcion: 'Crear compras' },
  { modulo: 'compras', accion: 'recibir', descripcion: 'Marcar compra como recibida' },
  { modulo: 'compras', accion: 'editar', descripcion: 'Editar compras' },
  { modulo: 'proveedores', accion: 'ver', descripcion: 'Ver proveedores' },
  { modulo: 'proveedores', accion: 'crear', descripcion: 'Crear proveedores' },
  { modulo: 'proveedores', accion: 'editar', descripcion: 'Editar proveedores' },
  { modulo: 'productos', accion: 'ver', descripcion: 'Ver productos' },
  { modulo: 'productos', accion: 'crear', descripcion: 'Crear productos' },
  { modulo: 'productos', accion: 'editar', descripcion: 'Editar productos' },
  { modulo: 'productos', accion: 'eliminar', descripcion: 'Eliminar productos' },
  { modulo: 'clientes', accion: 'ver', descripcion: 'Ver clientes' },
  { modulo: 'clientes', accion: 'crear', descripcion: 'Crear clientes' },
  { modulo: 'clientes', accion: 'editar', descripcion: 'Editar clientes' },
  { modulo: 'configuracion', accion: 'ver', descripcion: 'Ver configuración' },
  { modulo: 'configuracion', accion: 'editar', descripcion: 'Editar configuración' },
  { modulo: 'roles', accion: 'ver', descripcion: 'Ver roles' },
  { modulo: 'roles', accion: 'crear', descripcion: 'Crear roles' },
  { modulo: 'roles', accion: 'editar', descripcion: 'Editar roles' },
  { modulo: 'roles', accion: 'eliminar', descripcion: 'Eliminar roles' },
  { modulo: 'reportes', accion: 'ver', descripcion: 'Ver reportes' },
];

async function seed() {
  await sequelize.authenticate();

  // Insertar permisos
  const permisos = await Promise.all(
    PERMISOS.map(p => Permiso.findOrCreate({ where: { modulo: p.modulo, accion: p.accion }, defaults: p }))
  );
  const permisosCreados = permisos.map(([p]) => p);

  // Rol Administrador — todos los permisos
  const [admin] = await Rol.findOrCreate({ where: { nombre: 'Administrador' }, defaults: { descripcion: 'Acceso total' } });
  await admin.setPermisos(permisosCreados);

  // Rol Cajero
  const [cajero] = await Rol.findOrCreate({ where: { nombre: 'Cajero' }, defaults: { descripcion: 'Ventas, caja y clientes' } });
  const permisosCajero = permisosCreados.filter(p =>
    ['ventas', 'caja', 'libro_caja', 'clientes'].includes(p.modulo)
  );
  await cajero.setPermisos(permisosCajero);

  // Rol Mozo
  const [mozo] = await Rol.findOrCreate({ where: { nombre: 'Mozo' }, defaults: { descripcion: 'Toma de pedidos' } });
  const permisosMozo = permisosCreados.filter(p =>
    p.modulo === 'ventas' && ['ver', 'crear'].includes(p.accion)
  );
  await mozo.setPermisos(permisosMozo);

  // Usuario admin
  const hash = await bcrypt.hash('admin123', 12);
  await Usuario.findOrCreate({
    where: { email: 'admin@restaurante.com' },
    defaults: { rol_id: admin.id, nombre: 'Administrador', contrasena: hash },
  });

  // Configuraciones base
  const { sequelize: db } = require('../../src/models');
  await db.query(`
    INSERT IGNORE INTO configuraciones (clave, valor) VALUES
      ('nombre_negocio', 'Mi Restaurante'),
      ('direccion', ''),
      ('telefono', ''),
      ('moneda', 'Bs'),
      ('simbolo_moneda', 'Bs.'),
      ('zona_horaria', 'America/La_Paz'),
      ('pie_ticket', '¡Gracias por su preferencia!'),
      ('logo', NULL)
  `);

  console.log('Seed completado');
  process.exit(0);
}

seed().catch(err => { console.error(err); process.exit(1); });
```

- [ ] **Step 2: Agregar script en `package.json`**

```json
"seed": "node database/seeds/seed.js"
```

- [ ] **Step 3: Ejecutar seed**

```bash
npm run seed
```
Esperado: `Seed completado`

- [ ] **Step 4: Verificar en MySQL**

```sql
SELECT nombre FROM roles;         -- Administrador, Cajero, Mozo
SELECT COUNT(*) FROM permisos;    -- 37
SELECT email FROM usuarios;       -- admin@restaurante.com
SELECT clave FROM configuraciones; -- 8 filas
```

- [ ] **Step 5: Commit**

```bash
git add database/seeds/
git commit -m "feat: seed roles, permisos y usuario admin"
```

---

### Task 6: Middlewares de auth y permisos

**Files:**
- Create: `backend/src/middlewares/auth.js`
- Create: `backend/src/middlewares/permisos.js`
- Create: `backend/src/middlewares/errores.js`

**Interfaces:**
- Produces:
  - `auth` middleware: agrega `req.usuario = { id, nombre, email, rol_id, permisos: ['ventas.ver', ...] }`
  - `verificarPermiso(modulo, accion)` → middleware factory
  - `manejarErrores` → Express error handler (4 args)

- [ ] **Step 1: Crear `src/middlewares/auth.js`**

```js
const jwt = require('jsonwebtoken');
const { Usuario, Rol, Permiso } = require('../models');

async function auth(req, res, next) {
  const header = req.headers['authorization'];
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ ok: false, mensaje: 'Token requerido' });
  }

  const token = header.split(' ')[1];

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    const usuario = await Usuario.findOne({
      where: { id: payload.id, activo: 1 },
      include: [{
        model: Rol,
        as: 'rol',
        include: [{ model: Permiso, as: 'permisos' }],
      }],
    });

    if (!usuario) {
      return res.status(401).json({ ok: false, mensaje: 'Usuario no encontrado' });
    }

    req.usuario = {
      id: usuario.id,
      nombre: usuario.nombre,
      email: usuario.email,
      rol_id: usuario.rol_id,
      permisos: usuario.rol.permisos.map(p => `${p.modulo}.${p.accion}`),
    };

    next();
  } catch {
    return res.status(401).json({ ok: false, mensaje: 'Token inválido o expirado' });
  }
}

module.exports = auth;
```

- [ ] **Step 2: Crear `src/middlewares/permisos.js`**

```js
function verificarPermiso(modulo, accion) {
  return (req, res, next) => {
    const permiso = `${modulo}.${accion}`;
    if (!req.usuario || !req.usuario.permisos.includes(permiso)) {
      return res.status(403).json({ ok: false, mensaje: `Sin permiso: ${permiso}` });
    }
    next();
  };
}

module.exports = { verificarPermiso };
```

- [ ] **Step 3: Crear `src/middlewares/errores.js`**

```js
function manejarErrores(err, _req, res, _next) {
  console.error(err);
  const estado = err.status || 500;
  const mensaje = err.message || 'Error interno del servidor';
  res.status(estado).json({ ok: false, mensaje });
}

module.exports = manejarErrores;
```

- [ ] **Step 4: Registrar el handler en `src/app.js`**

```js
const express = require('express');
const cors = require('cors');
const manejarErrores = require('./middlewares/errores');

const app = express();

app.use(cors());
app.use(express.json());

app.get('/api/v1/salud', (_req, res) => {
  res.json({ ok: true, datos: 'API restaurante funcionando' });
});

// Rutas (se agregarán aquí en tasks siguientes)

app.use(manejarErrores);

module.exports = app;
```

- [ ] **Step 5: Commit**

```bash
git add src/middlewares/
git commit -m "feat: middlewares auth JWT y verificarPermiso"
```

---

### Task 7: Módulo Auth (login + refresh token)

**Files:**
- Create: `backend/src/modules/auth/auth.routes.js`
- Create: `backend/src/modules/auth/auth.controller.js`
- Create: `backend/src/modules/auth/auth.service.js`
- Modify: `backend/src/app.js`
- Test: `backend/tests/auth.test.js`

**Interfaces:**
- Produces:
  - `POST /api/v1/auth/login` → `{ ok, datos: { token, refresh_token, usuario: { id, nombre, email, rol } } }`
  - `POST /api/v1/auth/refresh` → `{ ok, datos: { token } }`
  - `GET /api/v1/auth/yo` (requiere auth) → `{ ok, datos: { id, nombre, email, permisos } }`

- [ ] **Step 1: Crear `src/modules/auth/auth.service.js`**

```js
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { Usuario, Rol, Permiso } = require('../../models');

async function login(email, contrasena) {
  const usuario = await Usuario.findOne({
    where: { email, activo: 1 },
    include: [{ model: Rol, as: 'rol', include: [{ model: Permiso, as: 'permisos' }] }],
  });

  if (!usuario) throw Object.assign(new Error('Credenciales inválidas'), { status: 401 });

  const valida = await bcrypt.compare(contrasena, usuario.contrasena);
  if (!valida) throw Object.assign(new Error('Credenciales inválidas'), { status: 401 });

  const payload = { id: usuario.id };
  const token = jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN });
  const refresh_token = jwt.sign(payload, process.env.JWT_REFRESH_SECRET, { expiresIn: process.env.JWT_REFRESH_EXPIRES_IN });

  return {
    token,
    refresh_token,
    usuario: {
      id: usuario.id,
      nombre: usuario.nombre,
      email: usuario.email,
      rol: usuario.rol.nombre,
      permisos: usuario.rol.permisos.map(p => `${p.modulo}.${p.accion}`),
    },
  };
}

async function refresh(refresh_token) {
  let payload;
  try {
    payload = jwt.verify(refresh_token, process.env.JWT_REFRESH_SECRET);
  } catch {
    throw Object.assign(new Error('Refresh token inválido'), { status: 401 });
  }
  const token = jwt.sign({ id: payload.id }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN });
  return { token };
}

module.exports = { login, refresh };
```

- [ ] **Step 2: Crear `src/modules/auth/auth.controller.js`**

```js
const authService = require('./auth.service');

async function login(req, res, next) {
  try {
    const { email, contrasena } = req.body;
    if (!email || !contrasena) {
      return res.status(400).json({ ok: false, mensaje: 'Email y contraseña requeridos' });
    }
    const datos = await authService.login(email, contrasena);
    res.json({ ok: true, datos });
  } catch (err) {
    next(err);
  }
}

async function refresh(req, res, next) {
  try {
    const { refresh_token } = req.body;
    if (!refresh_token) return res.status(400).json({ ok: false, mensaje: 'refresh_token requerido' });
    const datos = await authService.refresh(refresh_token);
    res.json({ ok: true, datos });
  } catch (err) {
    next(err);
  }
}

function yo(req, res) {
  res.json({ ok: true, datos: req.usuario });
}

module.exports = { login, refresh, yo };
```

- [ ] **Step 3: Crear `src/modules/auth/auth.routes.js`**

```js
const { Router } = require('express');
const { login, refresh, yo } = require('./auth.controller');
const auth = require('../../middlewares/auth');

const router = Router();

router.post('/login', login);
router.post('/refresh', refresh);
router.get('/yo', auth, yo);

module.exports = router;
```

- [ ] **Step 4: Registrar rutas en `src/app.js`**

```js
// Agregar después de app.use(express.json()):
const authRoutes = require('./modules/auth/auth.routes');
app.use('/api/v1/auth', authRoutes);
```

- [ ] **Step 5: Escribir tests `tests/auth.test.js`**

```js
const request = require('supertest');
const app = require('../src/app');

describe('POST /api/v1/auth/login', () => {
  it('retorna token con credenciales válidas', async () => {
    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'admin@restaurante.com', contrasena: 'admin123' });

    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.datos.token).toBeDefined();
    expect(res.body.datos.usuario.rol).toBe('Administrador');
  });

  it('rechaza credenciales inválidas', async () => {
    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'admin@restaurante.com', contrasena: 'incorrecta' });

    expect(res.status).toBe(401);
    expect(res.body.ok).toBe(false);
  });

  it('rechaza sin body', async () => {
    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({});

    expect(res.status).toBe(400);
  });
});

describe('GET /api/v1/auth/yo', () => {
  it('rechaza sin token', async () => {
    const res = await request(app).get('/api/v1/auth/yo');
    expect(res.status).toBe(401);
  });

  it('retorna usuario con token válido', async () => {
    const loginRes = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'admin@restaurante.com', contrasena: 'admin123' });

    const token = loginRes.body.datos.token;
    const res = await request(app)
      .get('/api/v1/auth/yo')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.datos.email).toBe('admin@restaurante.com');
    expect(Array.isArray(res.body.datos.permisos)).toBe(true);
  });
});
```

- [ ] **Step 6: Correr tests**

```bash
npm test -- tests/auth.test.js
```
Esperado: 4 tests pasando

- [ ] **Step 7: Commit**

```bash
git add src/modules/auth/ tests/auth.test.js src/app.js
git commit -m "feat: módulo auth con JWT login, refresh y /yo"
```

---

### Task 8: Módulo Roles y Permisos (API)

**Files:**
- Create: `backend/src/modules/roles/roles.routes.js`
- Create: `backend/src/modules/roles/roles.controller.js`
- Create: `backend/src/modules/roles/roles.service.js`
- Modify: `backend/src/app.js`
- Test: `backend/tests/roles.test.js`

**Interfaces:**
- Produces:
  - `GET /api/v1/roles` → `{ ok, datos: [{ id, nombre, descripcion, permisos: [] }] }`
  - `POST /api/v1/roles` → crear rol
  - `PUT /api/v1/roles/:id` → editar nombre/descripcion/permisos
  - `DELETE /api/v1/roles/:id` → eliminar (solo si no tiene usuarios)
  - `GET /api/v1/permisos` → listar todos los permisos agrupados por módulo

- [ ] **Step 1: Crear `src/modules/roles/roles.service.js`**

```js
const { Rol, Permiso, Usuario } = require('../../models');

async function listar() {
  return Rol.findAll({ include: [{ model: Permiso, as: 'permisos' }] });
}

async function crear({ nombre, descripcion, permiso_ids = [] }) {
  const rol = await Rol.create({ nombre, descripcion });
  if (permiso_ids.length) {
    const permisos = await Permiso.findAll({ where: { id: permiso_ids } });
    await rol.setPermisos(permisos);
  }
  return Rol.findByPk(rol.id, { include: [{ model: Permiso, as: 'permisos' }] });
}

async function actualizar(id, { nombre, descripcion, permiso_ids }) {
  const rol = await Rol.findByPk(id);
  if (!rol) throw Object.assign(new Error('Rol no encontrado'), { status: 404 });
  await rol.update({ nombre, descripcion });
  if (permiso_ids !== undefined) {
    const permisos = await Permiso.findAll({ where: { id: permiso_ids } });
    await rol.setPermisos(permisos);
  }
  return Rol.findByPk(id, { include: [{ model: Permiso, as: 'permisos' }] });
}

async function eliminar(id) {
  const rol = await Rol.findByPk(id);
  if (!rol) throw Object.assign(new Error('Rol no encontrado'), { status: 404 });
  const usuarios = await Usuario.count({ where: { rol_id: id } });
  if (usuarios > 0) throw Object.assign(new Error('El rol tiene usuarios asignados'), { status: 409 });
  await rol.destroy();
}

async function listarPermisos() {
  const permisos = await Permiso.findAll({ order: [['modulo', 'ASC'], ['accion', 'ASC']] });
  // Agrupar por módulo
  return permisos.reduce((acc, p) => {
    if (!acc[p.modulo]) acc[p.modulo] = [];
    acc[p.modulo].push({ id: p.id, accion: p.accion, descripcion: p.descripcion });
    return acc;
  }, {});
}

module.exports = { listar, crear, actualizar, eliminar, listarPermisos };
```

- [ ] **Step 2: Crear `src/modules/roles/roles.controller.js`**

```js
const rolesService = require('./roles.service');

async function listar(req, res, next) {
  try { res.json({ ok: true, datos: await rolesService.listar() }); }
  catch (err) { next(err); }
}

async function crear(req, res, next) {
  try { res.status(201).json({ ok: true, datos: await rolesService.crear(req.body) }); }
  catch (err) { next(err); }
}

async function actualizar(req, res, next) {
  try { res.json({ ok: true, datos: await rolesService.actualizar(req.params.id, req.body) }); }
  catch (err) { next(err); }
}

async function eliminar(req, res, next) {
  try { await rolesService.eliminar(req.params.id); res.json({ ok: true, datos: null }); }
  catch (err) { next(err); }
}

async function listarPermisos(req, res, next) {
  try { res.json({ ok: true, datos: await rolesService.listarPermisos() }); }
  catch (err) { next(err); }
}

module.exports = { listar, crear, actualizar, eliminar, listarPermisos };
```

- [ ] **Step 3: Crear `src/modules/roles/roles.routes.js`**

```js
const { Router } = require('express');
const ctrl = require('./roles.controller');
const auth = require('../../middlewares/auth');
const { verificarPermiso } = require('../../middlewares/permisos');

const router = Router();

router.use(auth);

router.get('/', verificarPermiso('roles', 'ver'), ctrl.listar);
router.post('/', verificarPermiso('roles', 'crear'), ctrl.crear);
router.put('/:id', verificarPermiso('roles', 'editar'), ctrl.actualizar);
router.delete('/:id', verificarPermiso('roles', 'eliminar'), ctrl.eliminar);

module.exports = router;
```

- [ ] **Step 4: Agregar al router en `src/app.js`**

```js
const rolesRoutes = require('./modules/roles/roles.routes');
const authRoutes = require('./modules/auth/auth.routes');

// Agregar ruta de permisos (pública solo para admin logueado)
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/roles', rolesRoutes);
app.get('/api/v1/permisos', auth, verificarPermiso('roles', 'ver'), async (req, res, next) => {
  try {
    const { listarPermisos } = require('./modules/roles/roles.service');
    res.json({ ok: true, datos: await listarPermisos() });
  } catch (err) { next(err); }
});
```

> Nota: importar `auth` y `verificarPermiso` en `app.js`:
```js
const auth = require('./middlewares/auth');
const { verificarPermiso } = require('./middlewares/permisos');
```

- [ ] **Step 5: Escribir tests `tests/roles.test.js`**

```js
const request = require('supertest');
const app = require('../src/app');

let adminToken;

beforeAll(async () => {
  const res = await request(app)
    .post('/api/v1/auth/login')
    .send({ email: 'admin@restaurante.com', contrasena: 'admin123' });
  adminToken = res.body.datos.token;
});

describe('GET /api/v1/roles', () => {
  it('retorna lista de roles para admin', async () => {
    const res = await request(app)
      .get('/api/v1/roles')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.datos.length).toBeGreaterThanOrEqual(3);
  });

  it('rechaza sin token', async () => {
    const res = await request(app).get('/api/v1/roles');
    expect(res.status).toBe(401);
  });
});

describe('GET /api/v1/permisos', () => {
  it('retorna permisos agrupados por módulo', async () => {
    const res = await request(app)
      .get('/api/v1/permisos')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(200);
    expect(res.body.datos).toHaveProperty('ventas');
    expect(res.body.datos).toHaveProperty('caja');
  });
});
```

- [ ] **Step 6: Correr tests**

```bash
npm test -- tests/roles.test.js
```
Esperado: 3 tests pasando

- [ ] **Step 7: Commit final del Plan 1**

```bash
git add src/modules/roles/ tests/roles.test.js src/app.js
git commit -m "feat: módulo roles y permisos con CRUD y middleware"
```

---

## Resultado final del Plan 1

Al completar este plan tendrás:
- Backend Express corriendo en puerto 3001
- Base de datos completa en español (20 tablas)
- Autenticación JWT con login, refresh y ruta `/yo`
- Middleware de permisos `verificarPermiso(modulo, accion)`
- API de roles y permisos funcional
- Seeds con 3 roles, 37 permisos y usuario admin
- Tests pasando para auth y roles

**Siguiente paso:** Plan 2 — Módulos backend (Usuarios, Productos, Ventas, Caja, Compras, Inventario)
