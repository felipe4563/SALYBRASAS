-- ============================================================================
-- SAL Y BRASAS — Base de datos limpia para producción
-- Generado a partir de bd/bd_restaurante.sql (11-07-2026)
--
-- Qué hace este script:
--   - Recrea la estructura completa de todas las tablas (igual al dump original).
--   - Conserva SOLO los datos maestros: áreas, categorías, mesas, productos,
--     proveedores, roles, permisos, roles_permisos y configuraciones.
--   - Dentro de usuarios, conserva ÚNICAMENTE la cuenta "Administrador".
--   - Deja completamente vacías (borrón y cuenta nueva) las tablas
--     transaccionales: pedidos, detalle_pedidos, sesiones_caja, libro_caja,
--     gastos, compras, detalle_compras, detalle_arqueo, registros_inventario,
--     clientes, reservaciones e ingredientes_producto.
--   - Todos los AUTO_INCREMENT quedan reiniciados a partir del siguiente id
--     disponible en cada tabla conservada (o en 1 para las tablas vacías).
--
-- Uso:
--   1. Haz un respaldo de la base de datos actual antes de ejecutar esto.
--   2. Ejecuta este script completo contra `bd_restaurante` (o una base nueva).
-- ============================================================================

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";
SET FOREIGN_KEY_CHECKS = 0;

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

-- --------------------------------------------------------
-- Limpieza de tablas existentes (si el script se corre sobre la BD actual)
-- --------------------------------------------------------

DROP TABLE IF EXISTS `areas`;
DROP TABLE IF EXISTS `categorias`;
DROP TABLE IF EXISTS `clientes`;
DROP TABLE IF EXISTS `compras`;
DROP TABLE IF EXISTS `configuraciones`;
DROP TABLE IF EXISTS `detalle_arqueo`;
DROP TABLE IF EXISTS `detalle_compras`;
DROP TABLE IF EXISTS `detalle_pedidos`;
DROP TABLE IF EXISTS `gastos`;
DROP TABLE IF EXISTS `ingredientes_producto`;
DROP TABLE IF EXISTS `libro_caja`;
DROP TABLE IF EXISTS `mesas`;
DROP TABLE IF EXISTS `pedidos`;
DROP TABLE IF EXISTS `permisos`;
DROP TABLE IF EXISTS `productos`;
DROP TABLE IF EXISTS `proveedores`;
DROP TABLE IF EXISTS `registros_inventario`;
DROP TABLE IF EXISTS `reservaciones`;
DROP TABLE IF EXISTS `roles`;
DROP TABLE IF EXISTS `roles_permisos`;
DROP TABLE IF EXISTS `sesiones_caja`;
DROP TABLE IF EXISTS `usuarios`;

-- --------------------------------------------------------
-- Estructura: `areas` (maestro — se conserva)
-- --------------------------------------------------------

CREATE TABLE `areas` (
  `id` int(10) UNSIGNED NOT NULL,
  `nombre` varchar(255) NOT NULL,
  `creado_en` timestamp NOT NULL DEFAULT current_timestamp(),
  `actualizado_en` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `areas` (`id`, `nombre`, `creado_en`, `actualizado_en`) VALUES
(1, 'Salon principal', '2026-07-01 00:25:28', '2026-07-01 00:25:28'),
(2, 'Area afuera', '2026-07-01 00:25:38', '2026-07-01 00:25:38'),
(3, 'Area Adentro', '2026-07-01 00:25:53', '2026-07-01 00:25:53');

-- --------------------------------------------------------
-- Estructura: `categorias` (maestro — se conserva)
-- --------------------------------------------------------

CREATE TABLE `categorias` (
  `id` int(10) UNSIGNED NOT NULL,
  `nombre` varchar(255) NOT NULL,
  `imagen` varchar(255) DEFAULT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT 1,
  `creado_en` timestamp NOT NULL DEFAULT current_timestamp(),
  `actualizado_en` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `categorias` (`id`, `nombre`, `imagen`, `activo`, `creado_en`, `actualizado_en`) VALUES
(1, 'Platos principales', NULL, 1, '2026-07-01 01:10:11', '2026-07-01 01:10:11'),
(2, 'Bebidas', NULL, 1, '2026-07-01 01:10:18', '2026-07-01 01:10:18'),
(3, 'Refrescos', NULL, 1, '2026-07-01 01:10:34', '2026-07-01 01:10:34');

-- --------------------------------------------------------
-- Estructura: `clientes` (transaccional — se vacía)
-- --------------------------------------------------------

CREATE TABLE `clientes` (
  `id` int(10) UNSIGNED NOT NULL,
  `nombre` varchar(255) NOT NULL,
  `tipo_documento` varchar(50) NOT NULL DEFAULT 'CI',
  `numero_documento` varchar(50) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `telefono` varchar(50) DEFAULT NULL,
  `direccion` varchar(255) DEFAULT NULL,
  `creado_en` timestamp NOT NULL DEFAULT current_timestamp(),
  `actualizado_en` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- Estructura: `compras` (transaccional — se vacía)
-- --------------------------------------------------------

CREATE TABLE `compras` (
  `id` int(10) UNSIGNED NOT NULL,
  `proveedor_id` int(10) UNSIGNED NOT NULL,
  `usuario_id` int(10) UNSIGNED NOT NULL,
  `total` decimal(10,2) NOT NULL DEFAULT 0.00,
  `notas` text DEFAULT NULL,
  `estado` enum('pendiente','recibido') NOT NULL DEFAULT 'pendiente',
  `creado_en` timestamp NOT NULL DEFAULT current_timestamp(),
  `actualizado_en` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- Estructura: `configuraciones` (maestro — se conserva)
-- --------------------------------------------------------

CREATE TABLE `configuraciones` (
  `id` int(10) UNSIGNED NOT NULL,
  `clave` varchar(100) NOT NULL,
  `valor` text DEFAULT NULL,
  `creado_en` timestamp NOT NULL DEFAULT current_timestamp(),
  `actualizado_en` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `configuraciones` (`id`, `clave`, `valor`, `creado_en`, `actualizado_en`) VALUES
(1, 'nombre_negocio', 'SAL Y BRASAS', '2026-07-01 00:23:31', '2026-07-10 23:02:25'),
(2, 'direccion', 'Av. Peru', '2026-07-01 00:23:31', '2026-07-10 23:02:25'),
(3, 'telefono', '74819122', '2026-07-01 00:23:31', '2026-07-10 23:02:25'),
(4, 'moneda', 'Bs', '2026-07-01 00:23:31', '2026-07-10 23:02:25'),
(5, 'simbolo_moneda', 'Bs.', '2026-07-01 00:23:31', '2026-07-10 23:02:25'),
(6, 'zona_horaria', 'America/La_Paz', '2026-07-01 00:23:31', '2026-07-10 23:02:25'),
(7, 'pie_ticket', '¡Gracias por su preferencia!', '2026-07-01 00:23:31', '2026-07-10 23:02:25'),
(8, 'logo', '/uploads/1782866956251-535876.png', '2026-07-01 00:23:31', '2026-07-10 23:02:25'),
(9, 'flujo_cocina', 'fisico', '2026-07-01 00:23:31', '2026-07-01 00:23:31');

-- --------------------------------------------------------
-- Estructura: `detalle_arqueo` (transaccional — se vacía)
-- --------------------------------------------------------

CREATE TABLE `detalle_arqueo` (
  `id` int(10) UNSIGNED NOT NULL,
  `sesion_caja_id` int(10) UNSIGNED NOT NULL,
  `denominacion` decimal(10,2) NOT NULL,
  `cantidad` int(11) NOT NULL DEFAULT 0,
  `subtotal` decimal(10,2) NOT NULL DEFAULT 0.00
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- Estructura: `detalle_compras` (transaccional — se vacía)
-- --------------------------------------------------------

CREATE TABLE `detalle_compras` (
  `id` int(10) UNSIGNED NOT NULL,
  `compra_id` int(10) UNSIGNED NOT NULL,
  `producto_id` int(10) UNSIGNED NOT NULL,
  `cantidad` int(11) NOT NULL,
  `costo_unitario` decimal(10,2) NOT NULL,
  `subtotal` decimal(10,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- Estructura: `detalle_pedidos` (transaccional — se vacía)
-- --------------------------------------------------------

CREATE TABLE `detalle_pedidos` (
  `id` int(10) UNSIGNED NOT NULL,
  `pedido_id` int(10) UNSIGNED NOT NULL,
  `producto_id` int(10) UNSIGNED NOT NULL,
  `cantidad` int(11) NOT NULL DEFAULT 1,
  `precio` decimal(10,2) NOT NULL,
  `nota` varchar(255) DEFAULT NULL,
  `estado` enum('pendiente','preparando','servido') NOT NULL DEFAULT 'pendiente',
  `creado_en` timestamp NOT NULL DEFAULT current_timestamp(),
  `actualizado_en` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- Estructura: `gastos` (transaccional — se vacía)
-- --------------------------------------------------------

CREATE TABLE `gastos` (
  `id` int(10) UNSIGNED NOT NULL,
  `sesion_caja_id` int(10) UNSIGNED DEFAULT NULL,
  `usuario_id` int(10) UNSIGNED NOT NULL,
  `descripcion` varchar(255) NOT NULL,
  `monto` decimal(10,2) NOT NULL,
  `creado_en` timestamp NOT NULL DEFAULT current_timestamp(),
  `actualizado_en` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- Estructura: `ingredientes_producto` (transaccional — se vacía)
-- --------------------------------------------------------

CREATE TABLE `ingredientes_producto` (
  `id` int(10) UNSIGNED NOT NULL,
  `producto_id` int(10) UNSIGNED NOT NULL,
  `ingrediente_id` int(10) UNSIGNED NOT NULL,
  `cantidad` decimal(10,2) NOT NULL,
  `creado_en` timestamp NOT NULL DEFAULT current_timestamp(),
  `actualizado_en` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- Estructura: `libro_caja` (transaccional — se vacía)
-- --------------------------------------------------------

CREATE TABLE `libro_caja` (
  `id` int(10) UNSIGNED NOT NULL,
  `sesion_caja_id` int(10) UNSIGNED DEFAULT NULL,
  `usuario_id` int(10) UNSIGNED NOT NULL,
  `tipo` enum('ingreso','egreso') NOT NULL,
  `concepto` varchar(255) NOT NULL,
  `monto` decimal(10,2) NOT NULL,
  `metodo_pago` enum('efectivo','qr') NOT NULL DEFAULT 'efectivo',
  `referencia_id` int(10) UNSIGNED DEFAULT NULL,
  `creado_en` timestamp NOT NULL DEFAULT current_timestamp(),
  `actualizado_en` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- Estructura: `mesas` (maestro — se conserva, forzada a 'disponible')
-- --------------------------------------------------------

CREATE TABLE `mesas` (
  `id` int(10) UNSIGNED NOT NULL,
  `area_id` int(10) UNSIGNED NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `asientos` int(11) NOT NULL DEFAULT 4,
  `estado` enum('disponible','ocupada','reservada') NOT NULL DEFAULT 'disponible',
  `pos_x` int(11) NOT NULL DEFAULT 0,
  `pos_y` int(11) NOT NULL DEFAULT 0,
  `creado_en` timestamp NOT NULL DEFAULT current_timestamp(),
  `actualizado_en` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `mesas` (`id`, `area_id`, `nombre`, `asientos`, `estado`, `pos_x`, `pos_y`, `creado_en`, `actualizado_en`) VALUES
(9, 3, 'MESA 2', 4, 'disponible', 0, 0, '2026-07-08 19:07:23', '2026-07-11 11:38:58'),
(10, 3, 'MESA 1', 4, 'disponible', 0, 0, '2026-07-10 23:02:03', '2026-07-11 12:41:38');

-- --------------------------------------------------------
-- Estructura: `pedidos` (transaccional — se vacía)
-- --------------------------------------------------------

CREATE TABLE `pedidos` (
  `id` int(10) UNSIGNED NOT NULL,
  `mesa_id` int(10) UNSIGNED DEFAULT NULL,
  `usuario_id` int(10) UNSIGNED NOT NULL,
  `cliente_id` int(10) UNSIGNED DEFAULT NULL,
  `sesion_caja_id` int(10) UNSIGNED DEFAULT NULL,
  `estado` enum('pendiente','listo','completado','cancelado') NOT NULL DEFAULT 'pendiente',
  `tipo` enum('mesa','llevar') NOT NULL DEFAULT 'mesa',
  `numero_llevar` int(10) UNSIGNED DEFAULT NULL,
  `tipo_documento` varchar(50) NOT NULL DEFAULT 'Ticket',
  `nombre_cliente` varchar(255) NOT NULL DEFAULT 'Público General',
  `documento_cliente` varchar(50) DEFAULT NULL,
  `total` decimal(10,2) NOT NULL DEFAULT 0.00,
  `descuento` decimal(10,2) NOT NULL DEFAULT 0.00,
  `propina` decimal(10,2) NOT NULL DEFAULT 0.00,
  `metodo_pago` enum('efectivo','qr') NOT NULL DEFAULT 'efectivo',
  `monto_recibido` decimal(10,2) DEFAULT NULL,
  `cambio` decimal(10,2) NOT NULL DEFAULT 0.00,
  `notas` text DEFAULT NULL,
  `creado_en` timestamp NOT NULL DEFAULT current_timestamp(),
  `actualizado_en` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- Estructura: `permisos` (maestro — se conserva)
-- --------------------------------------------------------

CREATE TABLE `permisos` (
  `id` int(10) UNSIGNED NOT NULL,
  `modulo` varchar(50) NOT NULL,
  `accion` varchar(50) NOT NULL,
  `descripcion` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `permisos` (`id`, `modulo`, `accion`, `descripcion`) VALUES
(1, 'ventas', 'ver', 'Ver pedidos'),
(2, 'ventas', 'crear', 'Crear pedidos'),
(3, 'ventas', 'cancelar', 'Cancelar pedidos'),
(4, 'ventas', 'cobrar', 'Cobrar pedidos'),
(5, 'usuarios', 'ver', 'Ver usuarios'),
(6, 'usuarios', 'crear', 'Crear usuarios'),
(7, 'usuarios', 'editar', 'Editar usuarios'),
(8, 'inventario', 'ver', 'Ver inventario'),
(9, 'usuarios', 'eliminar', 'Eliminar usuarios'),
(10, 'inventario', 'ajustar', 'Ajustar stock'),
(11, 'inventario', 'entrada', 'Registrar entrada'),
(12, 'inventario', 'salida', 'Registrar salida'),
(13, 'caja', 'abrir', 'Abrir caja'),
(14, 'caja', 'cerrar', 'Cerrar caja'),
(15, 'caja', 'ver', 'Ver sesiones de caja'),
(16, 'libro_caja', 'ver', 'Ver libro caja'),
(17, 'libro_caja', 'crear', 'Registrar en libro caja'),
(18, 'compras', 'ver', 'Ver compras'),
(19, 'compras', 'crear', 'Crear compras'),
(20, 'compras', 'recibir', 'Marcar compra como recibida'),
(21, 'compras', 'editar', 'Editar compras'),
(22, 'proveedores', 'ver', 'Ver proveedores'),
(23, 'proveedores', 'crear', 'Crear proveedores'),
(24, 'proveedores', 'editar', 'Editar proveedores'),
(25, 'productos', 'ver', 'Ver productos'),
(26, 'productos', 'crear', 'Crear productos'),
(27, 'productos', 'editar', 'Editar productos'),
(28, 'productos', 'eliminar', 'Eliminar productos'),
(29, 'clientes', 'ver', 'Ver clientes'),
(30, 'clientes', 'crear', 'Crear clientes'),
(31, 'clientes', 'editar', 'Editar clientes'),
(32, 'configuracion', 'ver', 'Ver configuración'),
(33, 'configuracion', 'editar', 'Editar configuración'),
(34, 'roles', 'ver', 'Ver roles'),
(35, 'roles', 'crear', 'Crear roles'),
(36, 'roles', 'editar', 'Editar roles'),
(37, 'roles', 'eliminar', 'Eliminar roles'),
(38, 'reportes', 'ver', 'Ver reportes'),
(39, 'cocina', 'ver', 'Ver pantalla de cocina');

-- --------------------------------------------------------
-- Estructura: `productos` (maestro — se conserva)
-- --------------------------------------------------------

CREATE TABLE `productos` (
  `id` int(10) UNSIGNED NOT NULL,
  `categoria_id` int(10) UNSIGNED NOT NULL,
  `nombre` varchar(255) NOT NULL,
  `codigo_barras` varchar(255) DEFAULT NULL,
  `codigo` varchar(100) DEFAULT NULL,
  `precio` decimal(10,2) NOT NULL,
  `costo` decimal(10,2) DEFAULT NULL,
  `stock` int(11) DEFAULT NULL,
  `es_vendible` tinyint(1) NOT NULL DEFAULT 1,
  `imagen` varchar(255) DEFAULT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT 1,
  `creado_en` timestamp NOT NULL DEFAULT current_timestamp(),
  `actualizado_en` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `productos` (`id`, `categoria_id`, `nombre`, `codigo_barras`, `codigo`, `precio`, `costo`, `stock`, `es_vendible`, `imagen`, `activo`, `creado_en`, `actualizado_en`) VALUES
(1, 3, 'Moconchinchi', NULL, NULL, 3.00, NULL, NULL, 1, '/uploads/1782868253811-205432.jpg', 1, '2026-07-01 01:11:15', '2026-07-11 13:12:58'),
(2, 2, 'Coca Cola', NULL, NULL, 12.00, NULL, 11, 1, '/uploads/1782915282345-932520.png', 1, '2026-07-01 14:15:01', '2026-07-11 13:29:19');

-- --------------------------------------------------------
-- Estructura: `proveedores` (maestro — se conserva)
-- --------------------------------------------------------

CREATE TABLE `proveedores` (
  `id` int(10) UNSIGNED NOT NULL,
  `nombre` varchar(255) NOT NULL,
  `contacto` varchar(255) DEFAULT NULL,
  `telefono` varchar(50) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `direccion` varchar(255) DEFAULT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT 1,
  `creado_en` timestamp NOT NULL DEFAULT current_timestamp(),
  `actualizado_en` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `proveedores` (`id`, `nombre`, `contacto`, `telefono`, `email`, `direccion`, `activo`, `creado_en`, `actualizado_en`) VALUES
(1, 'Proveedor Refrescos', 'Juan David', '74819122', '', '', 1, '2026-07-01 14:16:02', '2026-07-01 14:16:02');

-- --------------------------------------------------------
-- Estructura: `registros_inventario` (transaccional — se vacía)
-- --------------------------------------------------------

CREATE TABLE `registros_inventario` (
  `id` int(10) UNSIGNED NOT NULL,
  `producto_id` int(10) UNSIGNED NOT NULL,
  `usuario_id` int(10) UNSIGNED NOT NULL,
  `tipo` enum('entrada','salida','venta','compra','ajuste') NOT NULL,
  `cantidad` int(11) NOT NULL,
  `stock_anterior` int(11) DEFAULT NULL,
  `stock_nuevo` int(11) DEFAULT NULL,
  `nota` varchar(255) DEFAULT NULL,
  `creado_en` timestamp NOT NULL DEFAULT current_timestamp(),
  `actualizado_en` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- Estructura: `reservaciones` (transaccional — se vacía)
-- --------------------------------------------------------

CREATE TABLE `reservaciones` (
  `id` int(10) UNSIGNED NOT NULL,
  `nombre_cliente` varchar(255) NOT NULL,
  `telefono` varchar(50) DEFAULT NULL,
  `hora_reserva` datetime NOT NULL,
  `personas` int(11) NOT NULL,
  `mesa_id` int(10) UNSIGNED DEFAULT NULL,
  `nota` text DEFAULT NULL,
  `estado` enum('pendiente','confirmada','cancelada') NOT NULL DEFAULT 'pendiente',
  `creado_en` timestamp NOT NULL DEFAULT current_timestamp(),
  `actualizado_en` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- Estructura: `roles` (maestro — se conserva)
-- --------------------------------------------------------

CREATE TABLE `roles` (
  `id` int(10) UNSIGNED NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `descripcion` varchar(255) DEFAULT NULL,
  `creado_en` timestamp NOT NULL DEFAULT current_timestamp(),
  `actualizado_en` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `roles` (`id`, `nombre`, `descripcion`, `creado_en`, `actualizado_en`) VALUES
(1, 'Administrador', 'Acceso total al sistema', '2026-07-01 00:23:31', '2026-07-01 00:23:31'),
(2, 'Cajero', 'Ventas, caja, clientes y libro caja', '2026-07-01 00:23:31', '2026-07-01 00:23:31'),
(3, 'Mesero', 'Toma de pedidos y vista de mesas', '2026-07-01 00:23:31', '2026-07-01 00:23:31'),
(4, 'Cocina', 'Pantalla de cocina — ver y marcar pedidos', '2026-07-01 00:23:31', '2026-07-01 00:23:31');

-- --------------------------------------------------------
-- Estructura: `roles_permisos` (maestro — se conserva)
-- --------------------------------------------------------

CREATE TABLE `roles_permisos` (
  `rol_id` int(10) UNSIGNED NOT NULL,
  `permiso_id` int(10) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `roles_permisos` (`rol_id`, `permiso_id`) VALUES
(1, 1), (1, 2), (1, 3), (1, 4), (1, 5), (1, 6), (1, 7), (1, 8), (1, 9), (1, 10),
(1, 11), (1, 12), (1, 13), (1, 14), (1, 15), (1, 16), (1, 17), (1, 18), (1, 19), (1, 20),
(1, 21), (1, 22), (1, 23), (1, 24), (1, 25), (1, 26), (1, 27), (1, 28), (1, 29), (1, 30),
(1, 31), (1, 32), (1, 33), (1, 34), (1, 35), (1, 36), (1, 37), (1, 38),
(2, 1), (2, 2), (2, 3), (2, 4), (2, 8), (2, 13), (2, 14), (2, 15), (2, 16), (2, 17),
(2, 25), (2, 26), (2, 27), (2, 28), (2, 29), (2, 30), (2, 31),
(3, 1), (3, 2), (3, 39),
(4, 39);

-- --------------------------------------------------------
-- Estructura: `sesiones_caja` (transaccional — se vacía)
-- --------------------------------------------------------

CREATE TABLE `sesiones_caja` (
  `id` int(10) UNSIGNED NOT NULL,
  `usuario_id` int(10) UNSIGNED NOT NULL,
  `monto_apertura` decimal(10,2) NOT NULL DEFAULT 0.00,
  `monto_cierre` decimal(10,2) DEFAULT NULL,
  `total_ventas` decimal(10,2) NOT NULL DEFAULT 0.00,
  `total_gastos` decimal(10,2) NOT NULL DEFAULT 0.00,
  `diferencia` decimal(10,2) DEFAULT NULL,
  `abierto_en` timestamp NOT NULL DEFAULT current_timestamp(),
  `cerrado_en` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `estado` enum('abierta','cerrada') NOT NULL DEFAULT 'abierta'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- Estructura: `usuarios` (maestro — se conserva SOLO Administrador)
-- --------------------------------------------------------

CREATE TABLE `usuarios` (
  `id` int(10) UNSIGNED NOT NULL,
  `rol_id` int(10) UNSIGNED NOT NULL,
  `nombre` varchar(255) NOT NULL,
  `email` varchar(255) NOT NULL,
  `contrasena` varchar(255) NOT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT 1,
  `token_recordar` varchar(255) DEFAULT NULL,
  `creado_en` timestamp NOT NULL DEFAULT current_timestamp(),
  `actualizado_en` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `usuarios` (`id`, `rol_id`, `nombre`, `email`, `contrasena`, `activo`, `token_recordar`, `creado_en`, `actualizado_en`) VALUES
(1, 1, 'Administrador', 'admin@restaurante.com', '$2b$12$spw0UQ5SEJHbG1RePnlfLuMEOGxqL9TRvKwg1Hi7D2E5JQUCYplPS', 1, NULL, '2026-07-01 00:23:31', '2026-07-01 00:23:31');

-- --------------------------------------------------------
-- Índices
-- --------------------------------------------------------

ALTER TABLE `areas`
  ADD PRIMARY KEY (`id`);

ALTER TABLE `categorias`
  ADD PRIMARY KEY (`id`);

ALTER TABLE `clientes`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `clientes_doc_unique` (`numero_documento`);

ALTER TABLE `compras`
  ADD PRIMARY KEY (`id`),
  ADD KEY `proveedor_id` (`proveedor_id`),
  ADD KEY `usuario_id` (`usuario_id`);

ALTER TABLE `configuraciones`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `configuraciones_clave_unique` (`clave`);

ALTER TABLE `detalle_arqueo`
  ADD PRIMARY KEY (`id`),
  ADD KEY `sesion_caja_id` (`sesion_caja_id`);

ALTER TABLE `detalle_compras`
  ADD PRIMARY KEY (`id`),
  ADD KEY `compra_id` (`compra_id`),
  ADD KEY `producto_id` (`producto_id`);

ALTER TABLE `detalle_pedidos`
  ADD PRIMARY KEY (`id`),
  ADD KEY `pedido_id` (`pedido_id`),
  ADD KEY `producto_id` (`producto_id`);

ALTER TABLE `gastos`
  ADD PRIMARY KEY (`id`),
  ADD KEY `sesion_caja_id` (`sesion_caja_id`),
  ADD KEY `usuario_id` (`usuario_id`);

ALTER TABLE `ingredientes_producto`
  ADD PRIMARY KEY (`id`),
  ADD KEY `producto_id` (`producto_id`),
  ADD KEY `ingrediente_id` (`ingrediente_id`);

ALTER TABLE `libro_caja`
  ADD PRIMARY KEY (`id`),
  ADD KEY `sesion_caja_id` (`sesion_caja_id`),
  ADD KEY `usuario_id` (`usuario_id`);

ALTER TABLE `mesas`
  ADD PRIMARY KEY (`id`),
  ADD KEY `area_id` (`area_id`);

ALTER TABLE `pedidos`
  ADD PRIMARY KEY (`id`),
  ADD KEY `mesa_id` (`mesa_id`),
  ADD KEY `usuario_id` (`usuario_id`),
  ADD KEY `cliente_id` (`cliente_id`),
  ADD KEY `sesion_caja_id` (`sesion_caja_id`);

ALTER TABLE `permisos`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `permiso_unico` (`modulo`,`accion`);

ALTER TABLE `productos`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `productos_barcode_unique` (`codigo_barras`),
  ADD KEY `categoria_id` (`categoria_id`);

ALTER TABLE `proveedores`
  ADD PRIMARY KEY (`id`);

ALTER TABLE `registros_inventario`
  ADD PRIMARY KEY (`id`),
  ADD KEY `producto_id` (`producto_id`),
  ADD KEY `usuario_id` (`usuario_id`);

ALTER TABLE `reservaciones`
  ADD PRIMARY KEY (`id`),
  ADD KEY `mesa_id` (`mesa_id`);

ALTER TABLE `roles`
  ADD PRIMARY KEY (`id`);

ALTER TABLE `roles_permisos`
  ADD PRIMARY KEY (`rol_id`,`permiso_id`),
  ADD KEY `permiso_id` (`permiso_id`);

ALTER TABLE `sesiones_caja`
  ADD PRIMARY KEY (`id`),
  ADD KEY `usuario_id` (`usuario_id`);

ALTER TABLE `usuarios`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `usuarios_email_unique` (`email`),
  ADD KEY `rol_id` (`rol_id`);

-- --------------------------------------------------------
-- AUTO_INCREMENT
-- --------------------------------------------------------

ALTER TABLE `areas`                 MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;
ALTER TABLE `categorias`            MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;
ALTER TABLE `clientes`              MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;
ALTER TABLE `compras`               MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;
ALTER TABLE `configuraciones`       MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;
ALTER TABLE `detalle_arqueo`        MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;
ALTER TABLE `detalle_compras`       MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;
ALTER TABLE `detalle_pedidos`       MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;
ALTER TABLE `gastos`                MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;
ALTER TABLE `ingredientes_producto` MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;
ALTER TABLE `libro_caja`            MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;
ALTER TABLE `mesas`                 MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;
ALTER TABLE `pedidos`               MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;
ALTER TABLE `permisos`              MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=40;
ALTER TABLE `productos`             MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;
ALTER TABLE `proveedores`           MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;
ALTER TABLE `registros_inventario`  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;
ALTER TABLE `reservaciones`         MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;
ALTER TABLE `roles`                 MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;
ALTER TABLE `sesiones_caja`         MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;
ALTER TABLE `usuarios`              MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

-- --------------------------------------------------------
-- Llaves foráneas
-- --------------------------------------------------------

ALTER TABLE `compras`
  ADD CONSTRAINT `compras_ibfk_1` FOREIGN KEY (`proveedor_id`) REFERENCES `proveedores` (`id`),
  ADD CONSTRAINT `compras_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`);

ALTER TABLE `detalle_arqueo`
  ADD CONSTRAINT `detalle_arqueo_ibfk_1` FOREIGN KEY (`sesion_caja_id`) REFERENCES `sesiones_caja` (`id`) ON DELETE CASCADE;

ALTER TABLE `detalle_compras`
  ADD CONSTRAINT `detalle_compras_ibfk_1` FOREIGN KEY (`compra_id`) REFERENCES `compras` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `detalle_compras_ibfk_2` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`id`);

ALTER TABLE `detalle_pedidos`
  ADD CONSTRAINT `detalle_pedidos_ibfk_1` FOREIGN KEY (`pedido_id`) REFERENCES `pedidos` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `detalle_pedidos_ibfk_2` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`id`);

ALTER TABLE `gastos`
  ADD CONSTRAINT `gastos_ibfk_1` FOREIGN KEY (`sesion_caja_id`) REFERENCES `sesiones_caja` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `gastos_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`);

ALTER TABLE `ingredientes_producto`
  ADD CONSTRAINT `ingredientes_producto_ibfk_1` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `ingredientes_producto_ibfk_2` FOREIGN KEY (`ingrediente_id`) REFERENCES `productos` (`id`) ON DELETE CASCADE;

ALTER TABLE `libro_caja`
  ADD CONSTRAINT `libro_caja_ibfk_1` FOREIGN KEY (`sesion_caja_id`) REFERENCES `sesiones_caja` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `libro_caja_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`);

ALTER TABLE `mesas`
  ADD CONSTRAINT `mesas_ibfk_1` FOREIGN KEY (`area_id`) REFERENCES `areas` (`id`) ON DELETE CASCADE;

ALTER TABLE `pedidos`
  ADD CONSTRAINT `pedidos_ibfk_1` FOREIGN KEY (`mesa_id`) REFERENCES `mesas` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `pedidos_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`),
  ADD CONSTRAINT `pedidos_ibfk_3` FOREIGN KEY (`cliente_id`) REFERENCES `clientes` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `pedidos_ibfk_4` FOREIGN KEY (`sesion_caja_id`) REFERENCES `sesiones_caja` (`id`) ON DELETE SET NULL;

ALTER TABLE `productos`
  ADD CONSTRAINT `productos_ibfk_1` FOREIGN KEY (`categoria_id`) REFERENCES `categorias` (`id`) ON DELETE CASCADE;

ALTER TABLE `registros_inventario`
  ADD CONSTRAINT `registros_inventario_ibfk_1` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `registros_inventario_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`);

ALTER TABLE `reservaciones`
  ADD CONSTRAINT `reservaciones_ibfk_1` FOREIGN KEY (`mesa_id`) REFERENCES `mesas` (`id`) ON DELETE SET NULL;

ALTER TABLE `roles_permisos`
  ADD CONSTRAINT `roles_permisos_ibfk_1` FOREIGN KEY (`rol_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `roles_permisos_ibfk_2` FOREIGN KEY (`permiso_id`) REFERENCES `permisos` (`id`) ON DELETE CASCADE;

ALTER TABLE `sesiones_caja`
  ADD CONSTRAINT `sesiones_caja_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`);

ALTER TABLE `usuarios`
  ADD CONSTRAINT `usuarios_ibfk_1` FOREIGN KEY (`rol_id`) REFERENCES `roles` (`id`);

SET FOREIGN_KEY_CHECKS = 1;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
