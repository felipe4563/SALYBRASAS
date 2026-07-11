# Task 3: Migraciones SQL — base de datos completa en español

**Objetivo:** Crear los 11 archivos SQL de migración que definen las 20 tablas del sistema, todas en español.

**Directorio de trabajo:** `c:/Users/ASUS/OneDrive/Escritorio/TODO/SISTEMAS/RESTAURANTE/backend/`

**Contexto:** Tasks 1 y 2 completadas. El proyecto tiene Express 4 + Sequelize configurado. Git inicializado con 2 commits.

## Global Constraints

- **Todas las tablas y columnas en español** (crítico)
- MySQL 8, ENGINE=InnoDB, utf8mb4_unicode_ci
- Zona horaria: America/La_Paz
- `sesiones_caja` (006) DEBE crearse ANTES que `pedidos` (007) — FK dependency

## Archivos a crear

```
backend/database/migrations/001_roles_permisos.sql
backend/database/migrations/002_usuarios.sql
backend/database/migrations/003_areas_mesas.sql
backend/database/migrations/004_categorias_productos.sql
backend/database/migrations/005_clientes.sql
backend/database/migrations/006_sesiones_caja.sql
backend/database/migrations/007_pedidos.sql
backend/database/migrations/008_inventario.sql
backend/database/migrations/009_compras.sql
backend/database/migrations/010_caja_libro.sql
backend/database/migrations/011_reservaciones_config.sql
```

## Contenido exacto de cada archivo

### 001_roles_permisos.sql

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

### 002_usuarios.sql

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

### 003_areas_mesas.sql

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

### 004_categorias_productos.sql

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

### 005_clientes.sql

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

### 006_sesiones_caja.sql

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

### 007_pedidos.sql

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

### 008_inventario.sql

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

### 009_compras.sql

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

### 010_caja_libro.sql

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

### 011_reservaciones_config.sql

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

## Pasos de ejecución

1. Crear el directorio `database/migrations/` si no existe
2. Crear cada uno de los 11 archivos con el contenido exacto arriba
3. **NO ejecutar las migraciones** — solo crear los archivos (la ejecución en MySQL la hace el usuario manualmente)
4. Commit:

```bash
git add database/
git commit -m "feat: migraciones SQL completas — 20 tablas en español"
```

## Report contract

Escribe el resultado en `.superpowers/sdd/task-3-report.md`:
```
STATUS: DONE

Commits:
- <hash> feat: migraciones SQL completas — 20 tablas en español

Archivos creados: 11 archivos SQL en database/migrations/
Tablas definidas: 20
```
