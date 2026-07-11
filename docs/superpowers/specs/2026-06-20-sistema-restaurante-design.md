# Sistema de Gestión de Restaurante — Diseño

**Fecha:** 2026-06-20  
**Stack:** Node.js (Express) + MySQL + React + Vite (PWA)  
**Moneda:** Bs (Bolivia)  
**Zona horaria:** America/La_Paz

---

## 1. Módulos del Sistema

| Módulo | Descripción |
|---|---|
| Ventas / POS | Toma de pedidos por mesa, cobro, impresión de ticket |
| Usuarios | CRUD de usuarios, asignación de roles |
| Inventario | Stock de productos, entradas, salidas, ajustes |
| Caja | Apertura/cierre de turno, arqueo de billetes |
| Libro Caja | Registro de ingresos y egresos del turno |
| Compras | Proveedores, órdenes de compra, actualización de stock |
| Configuración | Datos del negocio, logo, pie de ticket, moneda |
| Roles y Permisos | Roles personalizables con permisos por módulo/acción |

---

## 2. Roles Base

| Rol | Acceso por defecto |
|---|---|
| Administrador | Acceso total a todos los módulos |
| Cajero | Ventas, Caja, Libro Caja, Clientes |
| Mozo | Solo toma de pedidos (plano de mesas) |

Los permisos son **personalizables** — el administrador puede ajustar qué acciones puede realizar cada rol desde el módulo de Roles y Permisos.

---

## 3. Permisos por Módulo

Cada permiso tiene formato `modulo.accion`:

```
ventas.ver          ventas.crear        ventas.cancelar     ventas.cobrar
usuarios.ver        usuarios.crear      usuarios.editar     usuarios.eliminar
inventario.ver      inventario.ajustar  inventario.entrada  inventario.salida
caja.abrir          caja.cerrar         caja.ver
libro_caja.ver      libro_caja.crear
compras.ver         compras.crear       compras.recibir     compras.editar
proveedores.ver     proveedores.crear   proveedores.editar
configuracion.ver   configuracion.editar
roles.ver           roles.crear         roles.editar        roles.eliminar
reportes.ver
```

---

## 4. Base de Datos (MySQL — todo en español)

### Roles y Permisos
```sql
CREATE TABLE roles (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  descripcion VARCHAR(255),
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE permisos (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  modulo VARCHAR(50) NOT NULL,
  accion VARCHAR(50) NOT NULL,
  descripcion VARCHAR(255),
  UNIQUE KEY permiso_unico (modulo, accion)
);

CREATE TABLE roles_permisos (
  rol_id INT UNSIGNED NOT NULL,
  permiso_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (rol_id, permiso_id),
  FOREIGN KEY (rol_id) REFERENCES roles(id) ON DELETE CASCADE,
  FOREIGN KEY (permiso_id) REFERENCES permisos(id) ON DELETE CASCADE
);
```

### Usuarios
```sql
CREATE TABLE usuarios (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  rol_id INT UNSIGNED NOT NULL,
  nombre VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  contrasena VARCHAR(255) NOT NULL,
  activo TINYINT(1) NOT NULL DEFAULT 1,
  token_recordar VARCHAR(100),
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (rol_id) REFERENCES roles(id)
);
```

### Salón y Mesas
```sql
CREATE TABLE areas (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(255) NOT NULL,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE mesas (
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
);
```

### Productos
```sql
CREATE TABLE categorias (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(255) NOT NULL,
  imagen VARCHAR(255),
  activo TINYINT(1) NOT NULL DEFAULT 1,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE productos (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  categoria_id INT UNSIGNED NOT NULL,
  nombre VARCHAR(255) NOT NULL,
  codigo_barras VARCHAR(255) UNIQUE,
  codigo VARCHAR(100),
  precio DECIMAL(10,2) NOT NULL,
  costo DECIMAL(10,2),
  stock INT DEFAULT NULL,
  es_vendible TINYINT(1) NOT NULL DEFAULT 1,
  imagen VARCHAR(255),
  activo TINYINT(1) NOT NULL DEFAULT 1,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (categoria_id) REFERENCES categorias(id) ON DELETE CASCADE
);

CREATE TABLE ingredientes_producto (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  producto_id INT UNSIGNED NOT NULL,
  ingrediente_id INT UNSIGNED NOT NULL,
  cantidad DECIMAL(10,2) NOT NULL,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE CASCADE,
  FOREIGN KEY (ingrediente_id) REFERENCES productos(id) ON DELETE CASCADE
);
```

### Clientes
```sql
CREATE TABLE clientes (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(255) NOT NULL,
  tipo_documento VARCHAR(50) NOT NULL DEFAULT 'CI',
  numero_documento VARCHAR(50) UNIQUE,
  email VARCHAR(255),
  telefono VARCHAR(50),
  direccion VARCHAR(255),
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### Ventas / Pedidos
> **Orden de migración:** `sesiones_caja` debe crearse antes que `pedidos` por la FK `sesion_caja_id`.

```sql
CREATE TABLE pedidos (
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
);

CREATE TABLE detalle_pedidos (
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
);
```

### Inventario
```sql
CREATE TABLE registros_inventario (
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
);
```

### Compras
```sql
CREATE TABLE proveedores (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(255) NOT NULL,
  contacto VARCHAR(255),
  telefono VARCHAR(50),
  email VARCHAR(255),
  direccion VARCHAR(255),
  activo TINYINT(1) NOT NULL DEFAULT 1,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE compras (
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
);

CREATE TABLE detalle_compras (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  compra_id INT UNSIGNED NOT NULL,
  producto_id INT UNSIGNED NOT NULL,
  cantidad INT NOT NULL,
  costo_unitario DECIMAL(10,2) NOT NULL,
  subtotal DECIMAL(10,2) NOT NULL,
  FOREIGN KEY (compra_id) REFERENCES compras(id) ON DELETE CASCADE,
  FOREIGN KEY (producto_id) REFERENCES productos(id)
);
```

### Caja y Arqueo
```sql
CREATE TABLE sesiones_caja (
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
);

-- Denominaciones de Bolivia: 200, 100, 50, 20, 10, 5, 2, 1, 0.50, 0.20, 0.10
CREATE TABLE detalle_arqueo (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sesion_caja_id INT UNSIGNED NOT NULL,
  denominacion DECIMAL(10,2) NOT NULL,
  cantidad INT NOT NULL DEFAULT 0,
  subtotal DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  FOREIGN KEY (sesion_caja_id) REFERENCES sesiones_caja(id) ON DELETE CASCADE
);

CREATE TABLE gastos (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sesion_caja_id INT UNSIGNED,
  usuario_id INT UNSIGNED NOT NULL,
  descripcion VARCHAR(255) NOT NULL,
  monto DECIMAL(10,2) NOT NULL,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (sesion_caja_id) REFERENCES sesiones_caja(id) ON DELETE SET NULL,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
);
```

### Libro Caja
```sql
CREATE TABLE libro_caja (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sesion_caja_id INT UNSIGNED,
  usuario_id INT UNSIGNED NOT NULL,
  tipo ENUM('ingreso','egreso') NOT NULL,
  concepto VARCHAR(255) NOT NULL,
  monto DECIMAL(10,2) NOT NULL,
  metodo_pago ENUM('efectivo','qr') NOT NULL DEFAULT 'efectivo',
  referencia_id INT UNSIGNED,   -- pedido_id si es venta, gasto_id si es egreso (referencia polimórfica, sin FK)
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (sesion_caja_id) REFERENCES sesiones_caja(id) ON DELETE SET NULL,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
);
```

### Reservaciones
```sql
CREATE TABLE reservaciones (
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
);
```

### Configuraciones
```sql
CREATE TABLE configuraciones (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  clave VARCHAR(100) NOT NULL UNIQUE,
  valor TEXT,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Valores iniciales
INSERT INTO configuraciones (clave, valor) VALUES
  ('nombre_negocio', 'Mi Restaurante'),
  ('direccion', ''),
  ('telefono', ''),
  ('moneda', 'Bs'),
  ('simbolo_moneda', 'Bs.'),
  ('zona_horaria', 'America/La_Paz'),
  ('pie_ticket', '¡Gracias por su preferencia!'),
  ('logo', NULL);
```

---

## 5. Arquitectura Backend (Node.js + Express)

```
backend/
├── src/
│   ├── config/
│   │   ├── database.js       # Sequelize config
│   │   └── env.js            # variables de entorno
│   ├── middlewares/
│   │   ├── auth.js           # verificar JWT
│   │   ├── permisos.js       # verificar permiso requerido
│   │   └── errores.js        # manejo global de errores
│   ├── modules/
│   │   ├── auth/             # login, logout, refresh token
│   │   ├── usuarios/
│   │   ├── roles/
│   │   ├── ventas/           # pedidos + detalle_pedidos
│   │   ├── mesas/            # areas + mesas
│   │   ├── productos/        # categorias + productos + ingredientes
│   │   ├── inventario/
│   │   ├── caja/             # sesiones_caja + detalle_arqueo + gastos
│   │   ├── libro_caja/
│   │   ├── compras/          # proveedores + compras + detalle_compras
│   │   ├── clientes/
│   │   ├── reservaciones/
│   │   └── configuracion/
│   └── app.js
```

Cada módulo contiene:
- `routes.js` — definición de rutas Express
- `controller.js` — lógica HTTP (request/response)
- `service.js` — lógica de negocio
- `model.js` — modelo Sequelize

**Autenticación:** JWT (access token 8h + refresh token 7 días)  
**Puerto:** 3001  
**Prefijo API:** `/api/v1`

---

## 6. Arquitectura Frontend (React + Vite PWA)

```
frontend/
├── public/
│   └── manifest.json
├── src/
│   ├── api/                  # axios instances por módulo
│   ├── components/
│   │   ├── ui/               # botones, inputs, modals reutilizables
│   │   ├── layout/           # sidebar, navbar, layout principal
│   │   └── shared/           # tabla, paginación, filtros
│   ├── pages/
│   │   ├── auth/             # login
│   │   ├── ventas/           # POS + plano de mesas
│   │   ├── caja/             # apertura, cierre, arqueo
│   │   ├── libro_caja/
│   │   ├── inventario/
│   │   ├── compras/
│   │   ├── productos/
│   │   ├── clientes/
│   │   ├── usuarios/
│   │   ├── roles/
│   │   ├── reservaciones/
│   │   └── configuracion/
│   ├── store/                # Zustand (auth, caja activa, carrito)
│   ├── hooks/                # useAuth, usePermisos, useCajaActiva
│   ├── router/               # React Router v6 con guardias por permiso
│   └── main.jsx
```

**Librerías clave:**
- `react-konva` — plano visual de mesas drag & drop
- `react-query` (TanStack Query) — caché y sincronización con API
- `zustand` — estado global
- `axios` — cliente HTTP
- `vite-plugin-pwa` — service worker y manifest
- `react-router-dom v6` — navegación con rutas protegidas

---

## 7. Flujo de Roles por Pantalla

### Mozo
- Ve el plano de mesas de su área
- Toca una mesa → abre el POS para tomar pedido
- Agrega productos al pedido
- Envía el pedido a cocina
- No puede cobrar ni ver caja

### Cajero
- Ve el plano de mesas
- Puede cobrar pedidos pendientes
- Abre y cierra su sesión de caja
- Registra gastos del turno
- Ve el libro caja de su turno

### Administrador
- Acceso total
- Configura el sistema, usuarios, roles, productos
- Ve reportes de ventas, inventario, caja
- Diseña el plano del salón (posición de mesas)

---

## 8. Flujo de Caja

1. Cajero abre sesión → ingresa monto inicial en efectivo
2. Durante el turno: las ventas cobradas se registran en `libro_caja` (tipo: ingreso)
3. Los gastos se registran en `gastos` y `libro_caja` (tipo: egreso)
4. Al cerrar: cajero cuenta físicamente los billetes por denominación
5. Sistema calcula: `monto_apertura + total_ventas_efectivo - total_gastos = esperado`
6. Se compara con el conteo físico → diferencia queda registrada en `sesiones_caja`

---

## 9. Métodos de Pago

| Método | Flujo |
|---|---|
| Efectivo | Cajero ingresa monto recibido, sistema calcula cambio |
| QR | Cajero muestra QR estático del negocio, confirma pago manualmente |

Ambos métodos se registran en `pedidos.metodo_pago` y en `libro_caja`.

---

## 10. Datos Iniciales (Seed)

- 3 roles: Administrador, Cajero, Mozo
- Todos los permisos definidos en sección 3
- Rol Administrador con todos los permisos
- Rol Cajero con permisos: ventas.*, caja.*, libro_caja.*, clientes.*
- Rol Mozo con permisos: ventas.ver, ventas.crear
- Usuario admin: admin@restaurante.com / admin123 (cambiar al primer login)
- Configuraciones base con moneda Bs y zona horaria America/La_Paz
