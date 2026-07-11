-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1
-- Tiempo de generación: 11-07-2026 a las 15:42:35
-- Versión del servidor: 10.4.32-MariaDB
-- Versión de PHP: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de datos: `bd_restaurante`
--

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `areas`
--

CREATE TABLE `areas` (
  `id` int(10) UNSIGNED NOT NULL,
  `nombre` varchar(255) NOT NULL,
  `creado_en` timestamp NOT NULL DEFAULT current_timestamp(),
  `actualizado_en` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `areas`
--

INSERT INTO `areas` (`id`, `nombre`, `creado_en`, `actualizado_en`) VALUES
(1, 'Salon principal', '2026-07-01 00:25:28', '2026-07-01 00:25:28'),
(2, 'Area afuera', '2026-07-01 00:25:38', '2026-07-01 00:25:38'),
(3, 'Area Adentro', '2026-07-01 00:25:53', '2026-07-01 00:25:53');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `categorias`
--

CREATE TABLE `categorias` (
  `id` int(10) UNSIGNED NOT NULL,
  `nombre` varchar(255) NOT NULL,
  `imagen` varchar(255) DEFAULT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT 1,
  `creado_en` timestamp NOT NULL DEFAULT current_timestamp(),
  `actualizado_en` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `categorias`
--

INSERT INTO `categorias` (`id`, `nombre`, `imagen`, `activo`, `creado_en`, `actualizado_en`) VALUES
(1, 'Platos principales', NULL, 1, '2026-07-01 01:10:11', '2026-07-01 01:10:11'),
(2, 'Bebidas', NULL, 1, '2026-07-01 01:10:18', '2026-07-01 01:10:18'),
(3, 'Refrescos', NULL, 1, '2026-07-01 01:10:34', '2026-07-01 01:10:34');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `clientes`
--

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

--
-- Estructura de tabla para la tabla `compras`
--

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

--
-- Volcado de datos para la tabla `compras`
--

INSERT INTO `compras` (`id`, `proveedor_id`, `usuario_id`, `total`, `notas`, `estado`, `creado_en`, `actualizado_en`) VALUES
(1, 1, 1, 183.00, '', 'recibido', '2026-07-01 14:16:50', '2026-07-01 14:16:54'),
(2, 1, 1, 144.00, '', 'recibido', '2026-07-11 01:39:28', '2026-07-11 01:39:32'),
(3, 1, 1, 144.00, '', 'recibido', '2026-07-11 13:21:06', '2026-07-11 13:21:08');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `configuraciones`
--

CREATE TABLE `configuraciones` (
  `id` int(10) UNSIGNED NOT NULL,
  `clave` varchar(100) NOT NULL,
  `valor` text DEFAULT NULL,
  `creado_en` timestamp NOT NULL DEFAULT current_timestamp(),
  `actualizado_en` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `configuraciones`
--

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

--
-- Estructura de tabla para la tabla `detalle_arqueo`
--

CREATE TABLE `detalle_arqueo` (
  `id` int(10) UNSIGNED NOT NULL,
  `sesion_caja_id` int(10) UNSIGNED NOT NULL,
  `denominacion` decimal(10,2) NOT NULL,
  `cantidad` int(11) NOT NULL DEFAULT 0,
  `subtotal` decimal(10,2) NOT NULL DEFAULT 0.00
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `detalle_arqueo`
--

INSERT INTO `detalle_arqueo` (`id`, `sesion_caja_id`, `denominacion`, `cantidad`, `subtotal`) VALUES
(1, 1, 10.00, 1, 10.00),
(2, 2, 10.00, 2, 20.00),
(3, 2, 5.00, 1, 5.00),
(4, 3, 20.00, 1, 20.00),
(5, 3, 10.00, 1, 10.00),
(6, 3, 5.00, 1, 5.00),
(7, 4, 100.00, 1, 100.00),
(8, 4, 10.00, 1, 10.00),
(9, 4, 2.00, 1, 2.00),
(10, 5, 20.00, 1, 20.00),
(11, 5, 5.00, 1, 5.00),
(12, 8, 100.00, 1, 100.00),
(13, 8, 10.00, 1, 10.00),
(14, 8, 1.00, 9, 9.00),
(15, 9, 20.00, 1, 20.00),
(16, 9, 10.00, 1, 10.00),
(17, 9, 5.00, 1, 5.00),
(18, 10, 20.00, 1, 20.00),
(19, 11, 200.00, 2, 400.00),
(20, 12, 20.00, 1, 20.00),
(21, 12, 10.00, 1, 10.00),
(22, 12, 5.00, 1, 5.00),
(23, 12, 1.00, 1, 1.00),
(24, 13, 10.00, 1, 10.00),
(25, 13, 2.00, 1, 2.00),
(26, 14, 20.00, 1, 20.00),
(27, 14, 10.00, 1, 10.00),
(28, 14, 5.00, 1, 5.00),
(29, 7, 100.00, 1, 100.00),
(30, 7, 50.00, 1, 50.00),
(31, 7, 20.00, 1, 20.00),
(32, 16, 5.00, 1, 5.00),
(33, 16, 1.00, 1, 1.00),
(34, 17, 10.00, 1, 10.00),
(35, 17, 5.00, 5, 25.00),
(36, 18, 10.00, 1, 10.00),
(37, 18, 5.00, 1, 5.00),
(38, 19, 10.00, 1, 10.00),
(39, 20, 20.00, 2, 40.00),
(40, 20, 2.00, 1, 2.00);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detalle_compras`
--

CREATE TABLE `detalle_compras` (
  `id` int(10) UNSIGNED NOT NULL,
  `compra_id` int(10) UNSIGNED NOT NULL,
  `producto_id` int(10) UNSIGNED NOT NULL,
  `cantidad` int(11) NOT NULL,
  `costo_unitario` decimal(10,2) NOT NULL,
  `subtotal` decimal(10,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `detalle_compras`
--

INSERT INTO `detalle_compras` (`id`, `compra_id`, `producto_id`, `cantidad`, `costo_unitario`, `subtotal`) VALUES
(1, 1, 2, 15, 12.00, 180.00),
(2, 1, 1, 1, 3.00, 3.00),
(3, 2, 2, 12, 12.00, 144.00),
(4, 3, 2, 12, 12.00, 144.00);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detalle_pedidos`
--

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

--
-- Volcado de datos para la tabla `detalle_pedidos`
--

INSERT INTO `detalle_pedidos` (`id`, `pedido_id`, `producto_id`, `cantidad`, `precio`, `nota`, `estado`, `creado_en`, `actualizado_en`) VALUES
(1, 1, 1, 1, 3.00, NULL, 'pendiente', '2026-07-01 01:11:41', '2026-07-01 01:11:41'),
(2, 3, 1, 1, 3.00, NULL, 'pendiente', '2026-07-01 01:25:38', '2026-07-01 01:25:38'),
(3, 4, 2, 1, 12.00, NULL, 'pendiente', '2026-07-01 14:27:43', '2026-07-01 14:27:43'),
(4, 5, 2, 1, 12.00, 'con 3 vasos', 'pendiente', '2026-07-01 14:39:01', '2026-07-01 14:39:15'),
(5, 6, 2, 1, 12.00, NULL, 'pendiente', '2026-07-02 00:24:00', '2026-07-02 00:24:00'),
(6, 6, 1, 3, 3.00, NULL, 'pendiente', '2026-07-02 00:24:01', '2026-07-02 00:24:29'),
(7, 7, 1, 1, 3.00, NULL, 'pendiente', '2026-07-02 00:25:35', '2026-07-02 00:25:35'),
(8, 7, 2, 1, 12.00, 'con 3 vasos', 'pendiente', '2026-07-02 00:25:35', '2026-07-02 11:10:34'),
(9, 9, 2, 1, 12.00, NULL, 'pendiente', '2026-07-02 12:11:35', '2026-07-02 12:11:35'),
(10, 9, 1, 1, 3.00, NULL, 'pendiente', '2026-07-02 12:11:36', '2026-07-02 12:11:36'),
(11, 10, 1, 1, 3.00, NULL, 'pendiente', '2026-07-02 12:11:58', '2026-07-02 12:11:58'),
(12, 10, 2, 1, 12.00, NULL, 'pendiente', '2026-07-02 12:11:58', '2026-07-02 12:11:58'),
(13, 11, 2, 1, 12.00, NULL, 'pendiente', '2026-07-02 12:12:09', '2026-07-02 12:12:09'),
(14, 11, 1, 1, 3.00, NULL, 'pendiente', '2026-07-02 12:12:09', '2026-07-02 12:12:09'),
(15, 12, 1, 1, 3.00, NULL, 'pendiente', '2026-07-02 12:37:59', '2026-07-02 12:37:59'),
(16, 12, 2, 1, 12.00, NULL, 'pendiente', '2026-07-02 12:37:59', '2026-07-02 12:37:59'),
(17, 13, 1, 3, 3.00, NULL, 'pendiente', '2026-07-02 12:38:17', '2026-07-02 12:38:18'),
(18, 13, 2, 3, 12.00, NULL, 'pendiente', '2026-07-02 12:38:17', '2026-07-02 12:38:19'),
(19, 14, 1, 1, 3.00, NULL, 'pendiente', '2026-07-02 12:38:33', '2026-07-02 12:38:33'),
(20, 14, 2, 1, 12.00, NULL, 'pendiente', '2026-07-02 12:38:34', '2026-07-02 12:38:34'),
(21, 15, 1, 1, 3.00, NULL, 'pendiente', '2026-07-02 12:39:00', '2026-07-02 12:39:00'),
(22, 15, 2, 1, 12.00, NULL, 'pendiente', '2026-07-02 12:39:01', '2026-07-02 12:39:01'),
(23, 16, 1, 1, 3.00, NULL, 'pendiente', '2026-07-02 12:39:45', '2026-07-02 12:39:45'),
(24, 16, 2, 2, 12.00, NULL, 'pendiente', '2026-07-02 12:39:45', '2026-07-02 12:39:55'),
(25, 17, 1, 1, 3.00, NULL, 'pendiente', '2026-07-02 12:41:25', '2026-07-02 12:41:25'),
(26, 17, 2, 1, 12.00, NULL, 'pendiente', '2026-07-02 12:41:25', '2026-07-02 12:41:25'),
(27, 18, 2, 1, 12.00, NULL, 'pendiente', '2026-07-02 12:42:43', '2026-07-02 12:42:43'),
(28, 18, 1, 1, 3.00, NULL, 'pendiente', '2026-07-02 12:42:46', '2026-07-02 12:42:46'),
(29, 19, 1, 2, 3.00, NULL, 'pendiente', '2026-07-02 12:43:48', '2026-07-02 12:43:50'),
(31, 20, 1, 1, 3.00, NULL, 'pendiente', '2026-07-02 12:46:30', '2026-07-02 12:46:30'),
(32, 20, 2, 1, 12.00, NULL, 'pendiente', '2026-07-02 12:46:35', '2026-07-02 12:46:35'),
(33, 21, 2, 1, 12.00, NULL, 'pendiente', '2026-07-02 12:53:58', '2026-07-02 12:53:58'),
(34, 21, 1, 1, 3.00, NULL, 'pendiente', '2026-07-02 12:53:58', '2026-07-02 12:53:58'),
(35, 22, 2, 1, 12.00, NULL, 'pendiente', '2026-07-02 16:55:45', '2026-07-02 16:55:45'),
(36, 22, 1, 1, 3.00, NULL, 'pendiente', '2026-07-02 16:58:52', '2026-07-02 16:58:52'),
(37, 23, 1, 1, 3.00, 'bbnbn', 'pendiente', '2026-07-02 17:30:24', '2026-07-02 17:35:24'),
(38, 23, 2, 11, 12.00, NULL, 'pendiente', '2026-07-02 17:30:24', '2026-07-02 21:51:49'),
(39, 24, 2, 11, 12.00, NULL, 'pendiente', '2026-07-02 21:51:58', '2026-07-02 21:52:01'),
(40, 25, 2, 12, 12.00, NULL, 'pendiente', '2026-07-02 21:52:09', '2026-07-02 21:52:14'),
(41, 29, 1, 1, 3.00, NULL, 'pendiente', '2026-07-03 13:16:01', '2026-07-03 13:16:01'),
(42, 29, 2, 1, 12.00, NULL, 'pendiente', '2026-07-03 13:16:01', '2026-07-03 13:16:01'),
(43, 30, 2, 1, 12.00, NULL, 'pendiente', '2026-07-03 13:16:28', '2026-07-03 13:16:28'),
(44, 30, 1, 1, 3.00, NULL, 'pendiente', '2026-07-03 13:16:29', '2026-07-03 13:16:29'),
(45, 31, 1, 1, 3.00, NULL, 'pendiente', '2026-07-03 13:19:54', '2026-07-03 13:19:54'),
(46, 31, 2, 1, 12.00, NULL, 'pendiente', '2026-07-03 13:19:55', '2026-07-03 13:19:55'),
(50, 32, 1, 1, 3.00, NULL, 'pendiente', '2026-07-03 13:35:24', '2026-07-03 13:35:24'),
(51, 32, 2, 1, 12.00, NULL, 'pendiente', '2026-07-03 13:35:25', '2026-07-03 13:35:25'),
(52, 34, 1, 1, 3.00, NULL, 'pendiente', '2026-07-03 13:36:13', '2026-07-03 13:36:13'),
(53, 34, 2, 1, 12.00, NULL, 'pendiente', '2026-07-03 13:36:13', '2026-07-03 13:36:13'),
(54, 35, 1, 1, 3.00, NULL, 'pendiente', '2026-07-03 13:37:10', '2026-07-03 13:37:10'),
(55, 35, 2, 1, 12.00, NULL, 'pendiente', '2026-07-03 13:37:10', '2026-07-03 13:37:10'),
(56, 36, 1, 1, 3.00, NULL, 'pendiente', '2026-07-03 14:21:43', '2026-07-03 14:21:43'),
(57, 36, 2, 1, 12.00, NULL, 'pendiente', '2026-07-03 14:21:43', '2026-07-03 14:21:43'),
(58, 37, 1, 1, 3.00, NULL, 'pendiente', '2026-07-04 17:31:11', '2026-07-04 17:31:11'),
(59, 37, 2, 1, 12.00, NULL, 'pendiente', '2026-07-04 17:31:11', '2026-07-04 17:31:11'),
(60, 38, 1, 1, 3.00, NULL, 'pendiente', '2026-07-04 17:32:47', '2026-07-04 17:32:47'),
(61, 38, 2, 1, 12.00, NULL, 'pendiente', '2026-07-04 17:32:47', '2026-07-04 17:32:47'),
(62, 39, 1, 2, 3.00, NULL, 'pendiente', '2026-07-04 17:34:43', '2026-07-04 17:34:44'),
(63, 40, 2, 1, 12.00, NULL, 'pendiente', '2026-07-04 17:37:46', '2026-07-04 17:37:46'),
(64, 40, 1, 1, 3.00, NULL, 'pendiente', '2026-07-04 17:37:46', '2026-07-04 17:37:46'),
(65, 41, 1, 1, 3.00, NULL, 'pendiente', '2026-07-04 17:48:36', '2026-07-04 17:48:36'),
(66, 41, 2, 1, 12.00, NULL, 'pendiente', '2026-07-04 17:48:36', '2026-07-04 17:48:36'),
(67, 42, 1, 6, 3.00, NULL, 'pendiente', '2026-07-04 18:46:32', '2026-07-04 18:46:35'),
(68, 42, 2, 5, 12.00, NULL, 'pendiente', '2026-07-04 18:46:33', '2026-07-04 18:46:34'),
(69, 43, 2, 1, 12.00, NULL, 'pendiente', '2026-07-04 18:46:47', '2026-07-04 18:46:47'),
(70, 43, 1, 3, 3.00, NULL, 'pendiente', '2026-07-04 18:46:48', '2026-07-04 18:46:49'),
(71, 44, 1, 1, 3.00, NULL, 'pendiente', '2026-07-04 19:17:29', '2026-07-04 19:17:29'),
(72, 44, 2, 1, 12.00, NULL, 'pendiente', '2026-07-04 19:17:29', '2026-07-04 19:17:29'),
(73, 45, 1, 1, 3.00, NULL, 'pendiente', '2026-07-04 19:23:30', '2026-07-04 19:23:30'),
(74, 45, 2, 1, 12.00, NULL, 'pendiente', '2026-07-04 19:23:30', '2026-07-04 19:23:30'),
(75, 46, 1, 1, 3.00, NULL, 'pendiente', '2026-07-04 19:41:43', '2026-07-04 19:41:43'),
(76, 46, 2, 1, 12.00, NULL, 'pendiente', '2026-07-04 19:41:44', '2026-07-04 19:41:44'),
(77, 47, 1, 12, 3.00, NULL, 'pendiente', '2026-07-04 19:45:50', '2026-07-04 19:45:52'),
(78, 47, 2, 2, 12.00, NULL, 'pendiente', '2026-07-04 19:45:50', '2026-07-04 19:45:50'),
(79, 48, 2, 2, 12.00, NULL, 'pendiente', '2026-07-06 02:00:07', '2026-07-06 02:00:08'),
(80, 48, 1, 2, 3.00, NULL, 'pendiente', '2026-07-06 02:00:07', '2026-07-06 02:00:08'),
(81, 49, 1, 1, 3.00, NULL, 'pendiente', '2026-07-06 02:01:26', '2026-07-06 02:01:26'),
(82, 49, 2, 1, 12.00, NULL, 'pendiente', '2026-07-06 02:01:26', '2026-07-06 02:01:26'),
(83, 50, 1, 1, 3.00, NULL, 'pendiente', '2026-07-06 02:21:23', '2026-07-06 02:21:23'),
(84, 50, 2, 1, 12.00, NULL, 'pendiente', '2026-07-06 02:21:24', '2026-07-06 02:21:24'),
(85, 51, 1, 1, 3.00, NULL, 'pendiente', '2026-07-06 02:21:43', '2026-07-06 02:21:43'),
(86, 51, 2, 1, 12.00, NULL, 'pendiente', '2026-07-06 02:21:43', '2026-07-06 02:21:43'),
(87, 52, 1, 1, 3.00, NULL, 'pendiente', '2026-07-06 02:31:21', '2026-07-06 02:31:21'),
(88, 52, 2, 1, 12.00, NULL, 'pendiente', '2026-07-06 02:31:21', '2026-07-06 02:31:21'),
(89, 53, 2, 1, 12.00, NULL, 'pendiente', '2026-07-06 02:32:46', '2026-07-06 02:32:46'),
(90, 53, 1, 2, 3.00, NULL, 'pendiente', '2026-07-06 02:32:46', '2026-07-06 02:32:52'),
(91, 54, 1, 4, 3.00, NULL, 'pendiente', '2026-07-06 02:39:48', '2026-07-06 02:39:49'),
(92, 54, 2, 1, 12.00, NULL, 'pendiente', '2026-07-06 02:39:49', '2026-07-06 02:39:49'),
(93, 55, 1, 3, 3.00, NULL, 'pendiente', '2026-07-06 02:46:33', '2026-07-06 02:46:34'),
(94, 55, 2, 1, 12.00, NULL, 'pendiente', '2026-07-06 02:46:34', '2026-07-06 02:46:34'),
(95, 56, 1, 2, 3.00, NULL, 'pendiente', '2026-07-06 02:48:39', '2026-07-06 02:48:41'),
(96, 57, 1, 1, 3.00, NULL, 'pendiente', '2026-07-06 02:49:16', '2026-07-06 02:49:16'),
(97, 58, 1, 1, 3.00, NULL, 'pendiente', '2026-07-06 02:57:07', '2026-07-06 02:57:07'),
(98, 58, 2, 1, 12.00, NULL, 'pendiente', '2026-07-06 02:57:08', '2026-07-06 02:57:08'),
(99, 59, 2, 1, 12.00, NULL, 'pendiente', '2026-07-06 03:01:32', '2026-07-06 03:01:32'),
(100, 59, 1, 2, 3.00, NULL, 'pendiente', '2026-07-06 03:01:33', '2026-07-06 03:01:34'),
(101, 60, 1, 1, 3.00, NULL, 'pendiente', '2026-07-06 11:59:46', '2026-07-06 11:59:46'),
(102, 61, 1, 1, 3.00, NULL, 'pendiente', '2026-07-06 12:04:22', '2026-07-06 12:04:22'),
(103, 62, 1, 1, 3.00, NULL, 'pendiente', '2026-07-06 12:04:26', '2026-07-06 12:04:26'),
(104, 62, 2, 1, 12.00, NULL, 'pendiente', '2026-07-06 12:04:26', '2026-07-06 12:04:26'),
(105, 64, 2, 1, 12.00, NULL, 'pendiente', '2026-07-06 12:08:50', '2026-07-06 12:08:50'),
(106, 64, 1, 1, 3.00, NULL, 'pendiente', '2026-07-06 12:08:51', '2026-07-06 12:08:51'),
(107, 65, 2, 1, 12.00, NULL, 'pendiente', '2026-07-06 12:13:42', '2026-07-06 12:13:42'),
(108, 65, 1, 1, 3.00, NULL, 'pendiente', '2026-07-06 12:13:42', '2026-07-06 12:13:42'),
(109, 66, 1, 1, 3.00, NULL, 'pendiente', '2026-07-06 12:26:11', '2026-07-06 12:26:11'),
(110, 66, 2, 1, 12.00, NULL, 'pendiente', '2026-07-06 12:26:11', '2026-07-06 12:26:11'),
(111, 67, 1, 1, 3.00, NULL, 'pendiente', '2026-07-06 12:27:33', '2026-07-06 12:27:33'),
(112, 67, 2, 1, 12.00, NULL, 'pendiente', '2026-07-06 12:27:33', '2026-07-06 12:27:33'),
(113, 68, 1, 2, 3.00, NULL, 'pendiente', '2026-07-06 15:50:35', '2026-07-06 15:50:36'),
(114, 68, 2, 1, 12.00, NULL, 'pendiente', '2026-07-06 15:50:38', '2026-07-06 15:50:38'),
(115, 69, 1, 1, 3.00, 'con dos pepas', 'pendiente', '2026-07-06 15:51:25', '2026-07-06 15:51:36'),
(116, 69, 2, 1, 12.00, NULL, 'pendiente', '2026-07-06 15:51:26', '2026-07-06 15:51:26'),
(117, 70, 1, 1, 3.00, NULL, 'pendiente', '2026-07-06 15:53:29', '2026-07-06 15:53:29'),
(118, 70, 2, 1, 12.00, 'con vasos ', 'pendiente', '2026-07-06 15:53:31', '2026-07-06 15:53:46'),
(119, 71, 1, 1, 3.00, NULL, 'pendiente', '2026-07-08 09:24:09', '2026-07-08 09:24:09'),
(120, 72, 1, 1, 3.00, NULL, 'pendiente', '2026-07-08 09:25:13', '2026-07-08 09:25:13'),
(121, 73, 1, 1, 3.00, NULL, 'pendiente', '2026-07-08 09:25:24', '2026-07-08 09:25:24'),
(122, 74, 2, 1, 12.00, NULL, 'pendiente', '2026-07-08 09:34:50', '2026-07-08 09:34:50'),
(123, 75, 2, 2, 12.00, NULL, 'pendiente', '2026-07-08 09:35:07', '2026-07-08 09:35:28'),
(124, 75, 1, 1, 3.00, NULL, 'pendiente', '2026-07-08 09:35:26', '2026-07-08 09:35:26'),
(125, 76, 1, 1, 3.00, NULL, 'pendiente', '2026-07-08 09:35:34', '2026-07-08 09:35:34'),
(126, 77, 1, 1, 3.00, NULL, 'pendiente', '2026-07-08 10:36:54', '2026-07-08 10:36:54'),
(127, 78, 2, 1, 12.00, NULL, 'pendiente', '2026-07-08 10:40:18', '2026-07-08 10:40:18'),
(128, 79, 1, 1, 3.00, NULL, 'pendiente', '2026-07-08 10:43:51', '2026-07-08 10:43:51'),
(130, 80, 1, 1, 3.00, NULL, 'pendiente', '2026-07-08 10:44:17', '2026-07-08 10:44:17'),
(131, 81, 2, 1, 12.00, NULL, 'pendiente', '2026-07-08 10:53:59', '2026-07-08 10:53:59'),
(132, 82, 1, 1, 3.00, NULL, 'pendiente', '2026-07-08 10:54:07', '2026-07-08 10:54:07'),
(133, 83, 2, 5, 12.00, NULL, 'pendiente', '2026-07-08 10:55:35', '2026-07-08 10:55:36'),
(134, 84, 1, 2, 3.00, NULL, 'pendiente', '2026-07-08 10:55:41', '2026-07-08 10:55:44'),
(135, 85, 1, 1, 3.00, NULL, 'pendiente', '2026-07-08 10:59:14', '2026-07-08 10:59:14'),
(136, 85, 2, 1, 12.00, NULL, 'pendiente', '2026-07-08 10:59:15', '2026-07-08 10:59:15'),
(137, 87, 1, 1, 3.00, NULL, 'pendiente', '2026-07-08 18:51:32', '2026-07-08 18:51:32'),
(138, 88, 1, 1, 3.00, NULL, 'pendiente', '2026-07-08 18:53:02', '2026-07-08 18:53:02'),
(139, 89, 2, 1, 12.00, NULL, 'pendiente', '2026-07-08 18:54:39', '2026-07-08 18:54:39'),
(140, 91, 1, 1, 3.00, NULL, 'pendiente', '2026-07-08 18:55:12', '2026-07-08 18:55:12'),
(141, 92, 1, 1, 3.00, NULL, 'pendiente', '2026-07-08 18:55:37', '2026-07-08 18:55:37'),
(142, 93, 2, 1, 12.00, NULL, 'pendiente', '2026-07-08 19:07:27', '2026-07-08 19:07:27'),
(143, 96, 2, 1, 12.00, NULL, 'pendiente', '2026-07-09 11:44:27', '2026-07-09 11:44:27'),
(144, 97, 1, 1, 3.00, NULL, 'pendiente', '2026-07-09 12:09:13', '2026-07-09 12:09:13'),
(145, 98, 1, 1, 3.00, NULL, 'pendiente', '2026-07-10 23:07:56', '2026-07-10 23:07:56'),
(146, 99, 1, 1, 3.00, NULL, 'pendiente', '2026-07-10 23:10:22', '2026-07-10 23:10:22'),
(147, 100, 1, 1, 3.00, NULL, 'pendiente', '2026-07-10 23:18:38', '2026-07-10 23:18:38'),
(148, 100, 2, 1, 12.00, NULL, 'pendiente', '2026-07-10 23:18:41', '2026-07-10 23:18:41'),
(149, 101, 2, 1, 12.00, NULL, 'pendiente', '2026-07-11 01:23:22', '2026-07-11 01:23:22'),
(150, 101, 1, 1, 3.00, NULL, 'pendiente', '2026-07-11 01:23:22', '2026-07-11 01:23:22'),
(151, 102, 2, 1, 12.00, NULL, 'pendiente', '2026-07-11 01:24:14', '2026-07-11 01:24:14'),
(152, 102, 1, 1, 3.00, NULL, 'pendiente', '2026-07-11 01:24:15', '2026-07-11 01:24:15'),
(153, 103, 2, 1, 12.00, NULL, 'pendiente', '2026-07-11 01:24:26', '2026-07-11 01:24:26'),
(154, 103, 1, 1, 3.00, NULL, 'pendiente', '2026-07-11 01:24:27', '2026-07-11 01:24:27'),
(157, 105, 2, 1, 12.00, NULL, 'pendiente', '2026-07-11 11:33:44', '2026-07-11 11:33:44'),
(158, 105, 1, 1, 3.00, NULL, 'pendiente', '2026-07-11 11:33:45', '2026-07-11 11:33:45'),
(159, 106, 2, 1, 12.00, NULL, 'pendiente', '2026-07-11 11:34:40', '2026-07-11 11:34:40'),
(160, 106, 1, 1, 3.00, NULL, 'pendiente', '2026-07-11 11:34:41', '2026-07-11 11:34:41'),
(161, 107, 2, 1, 12.00, NULL, 'pendiente', '2026-07-11 11:34:52', '2026-07-11 11:34:52'),
(162, 107, 1, 1, 3.00, NULL, 'pendiente', '2026-07-11 11:34:52', '2026-07-11 11:34:52'),
(167, 110, 2, 1, 12.00, NULL, 'pendiente', '2026-07-11 11:38:35', '2026-07-11 11:38:35'),
(168, 110, 1, 1, 3.00, NULL, 'pendiente', '2026-07-11 11:38:36', '2026-07-11 11:38:36'),
(169, 111, 1, 1, 3.00, NULL, 'pendiente', '2026-07-11 11:42:25', '2026-07-11 11:42:25'),
(170, 111, 2, 1, 12.00, NULL, 'pendiente', '2026-07-11 11:42:25', '2026-07-11 11:42:25'),
(171, 112, 1, 1, 3.00, NULL, 'pendiente', '2026-07-11 13:19:17', '2026-07-11 13:19:17'),
(172, 112, 2, 1, 12.00, NULL, 'pendiente', '2026-07-11 13:19:17', '2026-07-11 13:19:17'),
(173, 113, 2, 1, 12.00, NULL, 'pendiente', '2026-07-11 13:19:54', '2026-07-11 13:19:54'),
(174, 114, 1, 1, 3.00, NULL, 'pendiente', '2026-07-11 13:29:19', '2026-07-11 13:29:19'),
(175, 114, 2, 1, 12.00, NULL, 'pendiente', '2026-07-11 13:29:19', '2026-07-11 13:29:19');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `gastos`
--

CREATE TABLE `gastos` (
  `id` int(10) UNSIGNED NOT NULL,
  `sesion_caja_id` int(10) UNSIGNED DEFAULT NULL,
  `usuario_id` int(10) UNSIGNED NOT NULL,
  `descripcion` varchar(255) NOT NULL,
  `monto` decimal(10,2) NOT NULL,
  `creado_en` timestamp NOT NULL DEFAULT current_timestamp(),
  `actualizado_en` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `gastos`
--

INSERT INTO `gastos` (`id`, `sesion_caja_id`, `usuario_id`, `descripcion`, `monto`, `creado_en`, `actualizado_en`) VALUES
(1, 3, 1, 'Gas', 20.00, '2026-07-02 12:12:37', '2026-07-02 12:12:37'),
(2, 9, 5, 'pagos', 10.00, '2026-07-04 19:42:00', '2026-07-04 19:42:00'),
(3, 10, 5, 'luz', 40.00, '2026-07-04 19:46:09', '2026-07-04 19:46:09'),
(4, 14, 5, 'Gas', 25.00, '2026-07-08 10:56:11', '2026-07-08 10:56:11');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `ingredientes_producto`
--

CREATE TABLE `ingredientes_producto` (
  `id` int(10) UNSIGNED NOT NULL,
  `producto_id` int(10) UNSIGNED NOT NULL,
  `ingrediente_id` int(10) UNSIGNED NOT NULL,
  `cantidad` decimal(10,2) NOT NULL,
  `creado_en` timestamp NOT NULL DEFAULT current_timestamp(),
  `actualizado_en` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `libro_caja`
--

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

--
-- Volcado de datos para la tabla `libro_caja`
--

INSERT INTO `libro_caja` (`id`, `sesion_caja_id`, `usuario_id`, `tipo`, `concepto`, `monto`, `metodo_pago`, `referencia_id`, `creado_en`, `actualizado_en`) VALUES
(1, 2, 1, 'ingreso', 'Venta #7', 15.00, 'efectivo', 7, '2026-07-02 11:21:31', '2026-07-02 11:21:31'),
(2, 3, 1, 'ingreso', 'Venta #9', 15.00, 'qr', 9, '2026-07-02 12:11:41', '2026-07-02 12:11:41'),
(3, 3, 1, 'ingreso', 'Venta #10', 15.00, 'qr', 10, '2026-07-02 12:12:01', '2026-07-02 12:12:01'),
(4, 3, 1, 'ingreso', 'Venta #11', 15.00, 'qr', 11, '2026-07-02 12:12:16', '2026-07-02 12:12:16'),
(5, 3, 1, 'egreso', 'Gas', 20.00, 'efectivo', 1, '2026-07-02 12:12:37', '2026-07-02 12:12:37'),
(6, 4, 3, 'ingreso', 'Venta #12', 15.00, 'qr', 12, '2026-07-02 12:38:03', '2026-07-02 12:38:03'),
(7, 4, 3, 'ingreso', 'Venta #13', 45.00, 'qr', 13, '2026-07-02 12:38:22', '2026-07-02 12:38:22'),
(8, 4, 3, 'ingreso', 'Venta #15', 15.00, 'qr', 15, '2026-07-02 12:39:21', '2026-07-02 12:39:21'),
(9, 4, 3, 'ingreso', 'Venta #16', 27.00, 'qr', 16, '2026-07-02 12:39:58', '2026-07-02 12:39:58'),
(10, 5, 1, 'ingreso', 'Venta #18', 15.00, 'qr', 18, '2026-07-02 12:42:48', '2026-07-02 12:42:48'),
(11, 6, 3, 'ingreso', 'Venta #21', 15.00, 'qr', 21, '2026-07-02 12:54:11', '2026-07-02 12:54:11'),
(12, 7, 1, 'ingreso', 'Venta #23', 135.00, 'qr', 23, '2026-07-02 21:51:53', '2026-07-02 21:51:53'),
(13, 7, 1, 'ingreso', 'Venta #24', 132.00, 'qr', 24, '2026-07-02 21:52:05', '2026-07-02 21:52:05'),
(14, 7, 1, 'ingreso', 'Venta #25', 144.00, 'qr', 25, '2026-07-02 21:52:17', '2026-07-02 21:52:17'),
(15, 7, 1, 'ingreso', 'Venta #29', 15.00, 'qr', 29, '2026-07-03 13:16:05', '2026-07-03 13:16:05'),
(16, 7, 1, 'ingreso', 'Venta #30', 15.00, 'efectivo', 30, '2026-07-03 13:16:34', '2026-07-03 13:16:34'),
(17, 7, 1, 'ingreso', 'Venta #31', 15.00, 'efectivo', 31, '2026-07-03 13:20:02', '2026-07-03 13:20:02'),
(18, 7, 1, 'ingreso', 'Venta #32', 15.00, 'efectivo', 32, '2026-07-03 13:35:44', '2026-07-03 13:35:44'),
(19, 7, 1, 'ingreso', 'Venta #34', 15.00, 'qr', 34, '2026-07-03 13:36:18', '2026-07-03 13:36:18'),
(20, 7, 1, 'ingreso', 'Venta #35', 15.00, 'efectivo', 35, '2026-07-03 13:37:14', '2026-07-03 13:37:14'),
(21, 7, 1, 'ingreso', 'Venta #36', 15.00, 'efectivo', 36, '2026-07-03 14:21:46', '2026-07-03 14:21:46'),
(22, 7, 1, 'ingreso', 'sd', 0.01, 'efectivo', NULL, '2026-07-04 17:11:55', '2026-07-04 17:11:55'),
(23, NULL, 1, 'egreso', 'pago de empleados', 100.00, 'efectivo', NULL, '2026-07-04 17:26:38', '2026-07-04 17:26:38'),
(24, 7, 1, 'ingreso', 'Venta #37', 15.00, 'efectivo', 37, '2026-07-04 17:31:18', '2026-07-04 17:31:18'),
(25, 7, 1, 'ingreso', 'Venta #38', 15.00, 'efectivo', 38, '2026-07-04 17:32:51', '2026-07-04 17:32:51'),
(26, 7, 1, 'ingreso', 'Venta #39', 6.00, 'efectivo', 39, '2026-07-04 17:34:47', '2026-07-04 17:34:47'),
(27, 7, 1, 'ingreso', 'Venta #40', 15.00, 'efectivo', 40, '2026-07-04 17:37:50', '2026-07-04 17:37:50'),
(28, 7, 1, 'ingreso', 'Venta #41', 15.00, 'efectivo', 41, '2026-07-04 17:48:39', '2026-07-04 17:48:39'),
(29, 8, 5, 'ingreso', 'Venta #42', 78.00, 'efectivo', 42, '2026-07-04 18:46:40', '2026-07-04 18:46:40'),
(30, 8, 5, 'ingreso', 'Venta #43', 21.00, 'efectivo', 43, '2026-07-04 18:46:54', '2026-07-04 18:46:54'),
(31, 9, 5, 'ingreso', 'Venta #44', 15.00, 'efectivo', 44, '2026-07-04 19:21:22', '2026-07-04 19:21:22'),
(32, 9, 5, 'ingreso', 'Venta #45', 15.00, 'efectivo', 45, '2026-07-04 19:23:32', '2026-07-04 19:23:32'),
(33, 9, 5, 'ingreso', 'Venta #46', 15.00, 'efectivo', 46, '2026-07-04 19:41:46', '2026-07-04 19:41:46'),
(34, 9, 5, 'egreso', 'pagos', 10.00, 'efectivo', 2, '2026-07-04 19:42:00', '2026-07-04 19:42:00'),
(35, 10, 5, 'ingreso', 'Venta #47', 60.00, 'efectivo', 47, '2026-07-04 19:45:54', '2026-07-04 19:45:54'),
(36, 10, 5, 'egreso', 'luz', 40.00, 'efectivo', 3, '2026-07-04 19:46:09', '2026-07-04 19:46:09'),
(37, 11, 5, 'ingreso', 'Venta #48', 30.00, 'efectivo', 48, '2026-07-06 02:00:11', '2026-07-06 02:00:11'),
(38, 11, 5, 'ingreso', 'Venta #49', 15.00, 'efectivo', 49, '2026-07-06 02:01:28', '2026-07-06 02:01:28'),
(39, 11, 5, 'ingreso', 'Venta #50', 15.00, 'efectivo', 50, '2026-07-06 02:21:25', '2026-07-06 02:21:25'),
(40, 11, 5, 'ingreso', 'Venta #51', 15.00, 'efectivo', 51, '2026-07-06 02:21:45', '2026-07-06 02:21:45'),
(41, 11, 5, 'ingreso', 'Venta #52', 15.00, 'efectivo', 52, '2026-07-06 02:31:23', '2026-07-06 02:31:23'),
(42, 11, 5, 'ingreso', 'Venta #53', 18.00, 'efectivo', 53, '2026-07-06 02:32:54', '2026-07-06 02:32:54'),
(43, 11, 5, 'ingreso', 'Venta #54', 24.00, 'efectivo', 54, '2026-07-06 02:39:51', '2026-07-06 02:39:51'),
(44, 11, 5, 'ingreso', 'Venta #55', 21.00, 'efectivo', 55, '2026-07-06 02:46:37', '2026-07-06 02:46:37'),
(45, 11, 5, 'ingreso', 'Venta #56', 6.00, 'efectivo', 56, '2026-07-06 02:48:46', '2026-07-06 02:48:46'),
(46, 11, 5, 'ingreso', 'Venta #57', 3.00, 'efectivo', 57, '2026-07-06 02:49:18', '2026-07-06 02:49:18'),
(47, 11, 5, 'ingreso', 'Venta #58', 15.00, 'efectivo', 58, '2026-07-06 02:57:11', '2026-07-06 02:57:11'),
(48, 11, 5, 'ingreso', 'Venta #59', 18.00, 'efectivo', 59, '2026-07-06 03:01:36', '2026-07-06 03:01:36'),
(49, 11, 5, 'ingreso', 'Venta #60', 3.00, 'efectivo', 60, '2026-07-06 11:59:49', '2026-07-06 11:59:49'),
(50, 11, 5, 'ingreso', 'Venta #62', 15.00, 'efectivo', 62, '2026-07-06 12:04:29', '2026-07-06 12:04:29'),
(51, 11, 5, 'ingreso', 'Venta #64', 15.00, 'efectivo', 64, '2026-07-06 12:08:58', '2026-07-06 12:08:58'),
(52, 11, 5, 'ingreso', 'Venta #66', 15.00, 'efectivo', 66, '2026-07-06 12:26:13', '2026-07-06 12:26:13'),
(53, 11, 5, 'ingreso', 'Venta #68', 18.00, 'efectivo', 68, '2026-07-06 15:50:43', '2026-07-06 15:50:43'),
(54, 11, 5, 'ingreso', 'Venta #69', 15.00, 'efectivo', 69, '2026-07-06 15:51:46', '2026-07-06 15:51:46'),
(55, 11, 5, 'ingreso', 'Venta #70', 15.00, 'efectivo', 70, '2026-07-06 15:53:51', '2026-07-06 15:53:51'),
(56, 11, 5, 'ingreso', 'Venta #71', 3.00, 'efectivo', 71, '2026-07-08 09:24:13', '2026-07-08 09:24:13'),
(57, 11, 5, 'ingreso', 'Venta #72', 3.00, 'efectivo', 72, '2026-07-08 09:25:16', '2026-07-08 09:25:16'),
(58, 11, 5, 'ingreso', 'Venta #73', 3.00, 'efectivo', 73, '2026-07-08 09:25:29', '2026-07-08 09:25:29'),
(59, 12, 5, 'ingreso', 'Venta #74', 12.00, 'efectivo', 74, '2026-07-08 09:34:56', '2026-07-08 09:34:56'),
(60, 12, 5, 'ingreso', 'Venta #76', 3.00, 'efectivo', 76, '2026-07-08 09:35:36', '2026-07-08 09:35:36'),
(61, 12, 5, 'ingreso', 'Venta #77', 3.00, 'efectivo', 77, '2026-07-08 10:36:55', '2026-07-08 10:36:55'),
(62, 12, 5, 'ingreso', 'Venta #78', 12.00, 'efectivo', 78, '2026-07-08 10:40:22', '2026-07-08 10:40:22'),
(63, 12, 5, 'ingreso', 'Venta #79', 3.00, 'qr', 79, '2026-07-08 10:43:54', '2026-07-08 10:43:54'),
(64, 12, 5, 'ingreso', 'Venta #80', 3.00, 'qr', 80, '2026-07-08 10:44:24', '2026-07-08 10:44:24'),
(65, 13, 5, 'ingreso', 'Venta #81', 12.00, 'efectivo', 81, '2026-07-08 10:54:02', '2026-07-08 10:54:02'),
(66, 13, 5, 'ingreso', 'Venta #82', 3.00, 'qr', 82, '2026-07-08 10:54:11', '2026-07-08 10:54:11'),
(67, 14, 5, 'ingreso', 'Venta #83', 60.00, 'efectivo', 83, '2026-07-08 10:55:39', '2026-07-08 10:55:39'),
(68, 14, 5, 'ingreso', 'Venta #84', 6.00, 'qr', 84, '2026-07-08 10:55:47', '2026-07-08 10:55:47'),
(69, 14, 5, 'egreso', 'Gas', 25.00, 'efectivo', 4, '2026-07-08 10:56:11', '2026-07-08 10:56:11'),
(70, NULL, 5, 'egreso', 'pagos', 200.00, 'efectivo', NULL, '2026-07-08 10:57:31', '2026-07-08 10:57:31'),
(71, NULL, 5, 'egreso', 'extra', 395.00, 'efectivo', NULL, '2026-07-08 10:57:48', '2026-07-08 10:57:48'),
(72, NULL, 5, 'egreso', 'hi', 395.00, 'efectivo', NULL, '2026-07-08 10:58:04', '2026-07-08 10:58:04'),
(73, NULL, 5, 'egreso', 'hyddff', 210.00, 'efectivo', NULL, '2026-07-08 10:58:15', '2026-07-08 10:58:15'),
(74, NULL, 5, 'egreso', 'gtf', 0.10, 'qr', NULL, '2026-07-08 10:58:44', '2026-07-08 10:58:44'),
(75, 15, 5, 'ingreso', 'Venta #87', 3.00, 'efectivo', 87, '2026-07-08 18:51:34', '2026-07-08 18:51:34'),
(76, 15, 5, 'ingreso', 'Venta #88', 3.00, 'qr', 88, '2026-07-08 18:53:21', '2026-07-08 18:53:21'),
(77, 15, 5, 'ingreso', 'Venta #89', 12.00, 'efectivo', 89, '2026-07-08 18:54:41', '2026-07-08 18:54:41'),
(78, 15, 5, 'ingreso', 'Venta #91', 3.00, 'efectivo', 91, '2026-07-08 18:55:14', '2026-07-08 18:55:14'),
(79, 15, 5, 'ingreso', 'Venta #92', 3.00, 'efectivo', 92, '2026-07-08 18:55:39', '2026-07-08 18:55:39'),
(80, 7, 1, 'ingreso', 'Venta #93', 12.00, 'efectivo', 93, '2026-07-08 19:07:28', '2026-07-08 19:07:28'),
(81, 7, 1, 'ingreso', 'Venta #96', 12.00, 'efectivo', 96, '2026-07-09 11:44:29', '2026-07-09 11:44:29'),
(82, 7, 1, 'ingreso', 'Venta #97', 3.00, 'efectivo', 97, '2026-07-09 12:09:15', '2026-07-09 12:09:15'),
(83, 16, 1, 'ingreso', 'Venta #98', 3.00, 'efectivo', 98, '2026-07-10 23:08:01', '2026-07-10 23:08:01'),
(84, 16, 1, 'ingreso', 'Venta #99', 3.00, 'efectivo', 99, '2026-07-10 23:10:25', '2026-07-10 23:10:25'),
(85, 17, 1, 'ingreso', 'Venta #100', 15.00, 'efectivo', 100, '2026-07-10 23:18:58', '2026-07-10 23:18:58'),
(86, 18, 1, 'ingreso', 'Venta #101', 15.00, 'efectivo', 101, '2026-07-11 01:23:25', '2026-07-11 01:23:25'),
(87, 18, 1, 'ingreso', 'Venta #102', 15.00, 'qr', 102, '2026-07-11 01:24:17', '2026-07-11 01:24:17'),
(88, 18, 1, 'ingreso', 'Venta #103', 15.00, 'qr', 103, '2026-07-11 01:24:29', '2026-07-11 01:24:29'),
(89, 20, 1, 'ingreso', 'Venta #106', 15.00, 'efectivo', 106, '2026-07-11 11:38:20', '2026-07-11 11:38:20'),
(91, 20, 1, 'ingreso', 'Venta #112', 15.00, 'efectivo', 112, '2026-07-11 13:19:17', '2026-07-11 13:19:17'),
(92, 20, 1, 'ingreso', 'Venta #113', 12.00, 'efectivo', 113, '2026-07-11 13:19:54', '2026-07-11 13:19:54'),
(93, 21, 1, 'ingreso', 'Venta #114', 15.00, 'efectivo', 114, '2026-07-11 13:29:19', '2026-07-11 13:29:19');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `mesas`
--

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

--
-- Volcado de datos para la tabla `mesas`
--

INSERT INTO `mesas` (`id`, `area_id`, `nombre`, `asientos`, `estado`, `pos_x`, `pos_y`, `creado_en`, `actualizado_en`) VALUES
(9, 3, 'MESA 2', 4, 'disponible', 0, 0, '2026-07-08 19:07:23', '2026-07-11 11:38:58'),
(10, 3, 'MESA 1', 4, 'disponible', 0, 0, '2026-07-10 23:02:03', '2026-07-11 12:41:38');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `pedidos`
--

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

--
-- Volcado de datos para la tabla `pedidos`
--

INSERT INTO `pedidos` (`id`, `mesa_id`, `usuario_id`, `cliente_id`, `sesion_caja_id`, `estado`, `tipo`, `numero_llevar`, `tipo_documento`, `nombre_cliente`, `documento_cliente`, `total`, `descuento`, `propina`, `metodo_pago`, `monto_recibido`, `cambio`, `notas`, `creado_en`, `actualizado_en`) VALUES
(1, NULL, 1, NULL, 1, 'cancelado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 3.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-01 01:11:39', '2026-07-01 01:11:46'),
(2, NULL, 1, NULL, 1, 'cancelado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 0.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-01 01:22:13', '2026-07-01 01:22:16'),
(3, NULL, 1, NULL, 1, 'cancelado', 'llevar', 1, 'Ticket', 'Juan', NULL, 3.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-01 01:25:35', '2026-07-01 01:26:34'),
(4, NULL, 1, NULL, 2, 'cancelado', 'llevar', 1, 'Ticket', 'Juan', NULL, 12.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-01 14:27:42', '2026-07-01 14:38:58'),
(5, NULL, 1, NULL, 2, 'cancelado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 12.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-01 14:38:59', '2026-07-01 15:04:26'),
(6, NULL, 1, NULL, 2, 'cancelado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 21.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-02 00:23:58', '2026-07-02 00:24:31'),
(7, NULL, 1, NULL, 2, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', 20.00, 5.00, NULL, '2026-07-02 00:25:34', '2026-07-02 11:21:31'),
(8, NULL, 1, NULL, 2, 'cancelado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 0.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-02 11:21:35', '2026-07-02 11:22:57'),
(9, NULL, 1, NULL, 3, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'qr', 15.00, 0.00, NULL, '2026-07-02 12:11:34', '2026-07-02 12:11:41'),
(10, NULL, 1, NULL, 3, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'qr', 15.00, 0.00, NULL, '2026-07-02 12:11:57', '2026-07-02 12:12:01'),
(11, NULL, 1, NULL, 3, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'qr', 15.00, 0.00, NULL, '2026-07-02 12:12:07', '2026-07-02 12:12:16'),
(12, NULL, 3, NULL, 4, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'qr', 15.00, 0.00, NULL, '2026-07-02 12:37:58', '2026-07-02 12:38:03'),
(13, NULL, 3, NULL, 4, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 45.00, 0.00, 0.00, 'qr', 45.00, 0.00, NULL, '2026-07-02 12:38:16', '2026-07-02 12:38:22'),
(14, NULL, 3, NULL, 4, 'cancelado', 'llevar', 1, 'Ticket', 'juan', NULL, 15.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-02 12:38:33', '2026-07-02 12:38:41'),
(15, NULL, 3, NULL, 4, 'completado', 'llevar', 2, 'Ticket', 'Juan', NULL, 15.00, 0.00, 0.00, 'qr', 15.00, 0.00, NULL, '2026-07-02 12:38:59', '2026-07-02 12:39:21'),
(16, NULL, 3, NULL, 4, 'completado', 'llevar', 3, 'Ticket', 'juan', NULL, 27.00, 0.00, 0.00, 'qr', 27.00, 0.00, NULL, '2026-07-02 12:39:41', '2026-07-02 12:39:58'),
(17, NULL, 1, NULL, 5, 'pendiente', 'llevar', 4, 'Ticket', 'Guimer', NULL, 15.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-02 12:41:24', '2026-07-02 12:41:25'),
(18, NULL, 1, NULL, 5, 'completado', 'llevar', 5, 'Ticket', 'Gim', NULL, 15.00, 0.00, 0.00, 'qr', 15.00, 0.00, NULL, '2026-07-02 12:42:42', '2026-07-02 12:42:48'),
(19, NULL, 3, NULL, 6, 'pendiente', 'llevar', 6, 'Ticket', 'Guimer', NULL, 6.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-02 12:43:46', '2026-07-02 12:44:15'),
(20, NULL, 3, NULL, 6, 'cancelado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-02 12:46:28', '2026-07-02 12:46:42'),
(21, NULL, 3, NULL, 6, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'qr', 15.00, 0.00, NULL, '2026-07-02 12:53:56', '2026-07-02 12:54:11'),
(22, NULL, 1, NULL, 7, 'cancelado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-02 16:55:43', '2026-07-02 17:14:06'),
(23, NULL, 1, NULL, 7, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 135.00, 0.00, 0.00, 'qr', 135.00, 0.00, NULL, '2026-07-02 17:30:23', '2026-07-02 21:51:53'),
(24, NULL, 1, NULL, 7, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 132.00, 0.00, 0.00, 'qr', 132.00, 0.00, NULL, '2026-07-02 21:51:56', '2026-07-02 21:52:05'),
(25, NULL, 1, NULL, 7, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 144.00, 0.00, 0.00, 'qr', 144.00, 0.00, NULL, '2026-07-02 21:52:07', '2026-07-02 21:52:17'),
(26, NULL, 1, NULL, 7, 'cancelado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 0.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-02 21:52:20', '2026-07-02 21:52:30'),
(27, NULL, 1, NULL, 7, 'cancelado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 0.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-02 21:52:25', '2026-07-02 21:52:34'),
(28, NULL, 1, NULL, 7, 'cancelado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 0.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-02 23:30:46', '2026-07-03 13:15:58'),
(29, NULL, 1, NULL, 7, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'qr', 15.00, 0.00, NULL, '2026-07-03 13:15:59', '2026-07-03 13:16:05'),
(30, NULL, 1, NULL, 7, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', 20.00, 5.00, NULL, '2026-07-03 13:16:26', '2026-07-03 13:16:34'),
(31, NULL, 1, NULL, 7, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', 20.00, 5.00, NULL, '2026-07-03 13:19:50', '2026-07-03 13:20:02'),
(32, NULL, 1, NULL, 7, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', 20.00, 5.00, NULL, '2026-07-03 13:20:25', '2026-07-03 13:35:44'),
(33, NULL, 1, NULL, 7, 'cancelado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 0.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-03 13:35:37', '2026-07-03 13:36:04'),
(34, NULL, 1, NULL, 7, 'completado', 'llevar', 1, 'Ticket', 'Juancito', NULL, 15.00, 0.00, 0.00, 'qr', 15.00, 0.00, NULL, '2026-07-03 13:36:12', '2026-07-03 13:36:18'),
(35, NULL, 1, NULL, 7, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', 20.00, 5.00, NULL, '2026-07-03 13:37:09', '2026-07-03 13:37:14'),
(36, NULL, 1, NULL, 7, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', 20.00, 5.00, NULL, '2026-07-03 14:21:42', '2026-07-03 14:21:46'),
(37, NULL, 1, NULL, 7, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', 20.00, 5.00, NULL, '2026-07-04 17:31:10', '2026-07-04 17:31:18'),
(38, NULL, 1, NULL, 7, 'completado', 'llevar', 1, 'Ticket', 'Juan', NULL, 15.00, 0.00, 0.00, 'efectivo', 20.00, 5.00, NULL, '2026-07-04 17:32:46', '2026-07-04 17:32:51'),
(39, NULL, 1, NULL, 7, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 6.00, 0.00, 0.00, 'efectivo', 10.00, 4.00, NULL, '2026-07-04 17:34:42', '2026-07-04 17:34:47'),
(40, NULL, 1, NULL, 7, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', 20.00, 5.00, NULL, '2026-07-04 17:37:45', '2026-07-04 17:37:50'),
(41, NULL, 1, NULL, 7, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', 20.00, 5.00, NULL, '2026-07-04 17:48:35', '2026-07-04 17:48:39'),
(42, NULL, 5, NULL, 8, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 78.00, 0.00, 0.00, 'efectivo', 80.00, 2.00, NULL, '2026-07-04 18:46:31', '2026-07-04 18:46:40'),
(43, NULL, 5, NULL, 8, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 21.00, 0.00, 0.00, 'efectivo', 30.00, 9.00, NULL, '2026-07-04 18:46:47', '2026-07-04 18:46:54'),
(44, NULL, 5, NULL, 9, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', 15.00, 0.00, NULL, '2026-07-04 19:17:28', '2026-07-04 19:21:22'),
(45, NULL, 5, NULL, 9, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', 15.00, 0.00, NULL, '2026-07-04 19:23:29', '2026-07-04 19:23:32'),
(46, NULL, 5, NULL, 9, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', 15.00, 0.00, NULL, '2026-07-04 19:41:43', '2026-07-04 19:41:46'),
(47, NULL, 5, NULL, 10, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 60.00, 0.00, 0.00, 'efectivo', 60.00, 0.00, NULL, '2026-07-04 19:45:49', '2026-07-04 19:45:54'),
(48, NULL, 5, NULL, 11, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 30.00, 0.00, 0.00, 'efectivo', 30.00, 0.00, NULL, '2026-07-06 02:00:06', '2026-07-06 02:00:11'),
(49, NULL, 5, NULL, 11, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', 15.00, 0.00, NULL, '2026-07-06 02:01:25', '2026-07-06 02:01:28'),
(50, NULL, 5, NULL, 11, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', 15.00, 0.00, NULL, '2026-07-06 02:21:22', '2026-07-06 02:21:25'),
(51, NULL, 5, NULL, 11, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', 15.00, 0.00, NULL, '2026-07-06 02:21:42', '2026-07-06 02:21:45'),
(52, NULL, 5, NULL, 11, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', 15.00, 0.00, NULL, '2026-07-06 02:31:20', '2026-07-06 02:31:23'),
(53, NULL, 5, NULL, 11, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 18.00, 0.00, 0.00, 'efectivo', 18.00, 0.00, NULL, '2026-07-06 02:32:44', '2026-07-06 02:32:54'),
(54, NULL, 5, NULL, 11, 'completado', 'llevar', 1, 'Ticket', 'Juan', NULL, 24.00, 0.00, 0.00, 'efectivo', 24.00, 0.00, NULL, '2026-07-06 02:39:48', '2026-07-06 02:39:51'),
(55, NULL, 5, NULL, 11, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 21.00, 0.00, 0.00, 'efectivo', 21.00, 0.00, NULL, '2026-07-06 02:46:33', '2026-07-06 02:46:37'),
(56, NULL, 5, NULL, 11, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 6.00, 0.00, 0.00, 'efectivo', 6.00, 0.00, NULL, '2026-07-06 02:48:38', '2026-07-06 02:48:46'),
(57, NULL, 5, NULL, 11, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 3.00, 0.00, 0.00, 'efectivo', 3.00, 0.00, NULL, '2026-07-06 02:49:15', '2026-07-06 02:49:18'),
(58, NULL, 5, NULL, 11, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', 15.00, 0.00, NULL, '2026-07-06 02:57:06', '2026-07-06 02:57:11'),
(59, NULL, 5, NULL, 11, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 18.00, 0.00, 0.00, 'efectivo', 18.00, 0.00, NULL, '2026-07-06 03:01:31', '2026-07-06 03:01:36'),
(60, NULL, 5, NULL, 11, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 3.00, 0.00, 0.00, 'efectivo', 3.00, 0.00, NULL, '2026-07-06 11:59:45', '2026-07-06 11:59:49'),
(61, NULL, 5, NULL, 11, 'cancelado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 3.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-06 12:04:21', '2026-07-06 12:04:57'),
(62, NULL, 5, NULL, 11, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', 15.00, 0.00, NULL, '2026-07-06 12:04:25', '2026-07-06 12:04:29'),
(63, NULL, 5, NULL, 11, 'cancelado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 0.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-06 12:04:59', '2026-07-06 12:08:42'),
(64, NULL, 5, NULL, 11, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', 15.00, 0.00, NULL, '2026-07-06 12:08:47', '2026-07-06 12:08:58'),
(65, NULL, 5, NULL, 11, 'cancelado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-06 12:13:39', '2026-07-06 12:13:59'),
(66, NULL, 5, NULL, 11, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', 15.00, 0.00, NULL, '2026-07-06 12:14:03', '2026-07-06 12:26:13'),
(67, NULL, 5, NULL, 11, 'cancelado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-06 12:27:31', '2026-07-06 12:27:42'),
(68, NULL, 5, NULL, 11, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 18.00, 0.00, 0.00, 'efectivo', 18.00, 0.00, NULL, '2026-07-06 15:50:33', '2026-07-06 15:50:43'),
(69, NULL, 5, NULL, 11, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', 15.00, 0.00, NULL, '2026-07-06 15:51:24', '2026-07-06 15:51:46'),
(70, NULL, 5, NULL, 11, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', 15.00, 0.00, NULL, '2026-07-06 15:53:28', '2026-07-06 15:53:51'),
(71, NULL, 5, NULL, 11, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 3.00, 0.00, 0.00, 'efectivo', 3.00, 0.00, NULL, '2026-07-08 09:24:08', '2026-07-08 09:24:13'),
(72, NULL, 5, NULL, 11, 'completado', 'llevar', 1, 'Ticket', 'Felipe', NULL, 3.00, 0.00, 0.00, 'efectivo', 3.00, 0.00, NULL, '2026-07-08 09:25:13', '2026-07-08 09:25:16'),
(73, NULL, 5, NULL, 11, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 3.00, 0.00, 0.00, 'efectivo', 3.00, 0.00, NULL, '2026-07-08 09:25:23', '2026-07-08 09:25:29'),
(74, NULL, 5, NULL, 12, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 12.00, 0.00, 0.00, 'efectivo', 12.00, 0.00, NULL, '2026-07-08 09:34:48', '2026-07-08 09:34:56'),
(75, NULL, 5, NULL, 12, 'cancelado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 27.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-08 09:35:06', '2026-07-08 09:35:32'),
(76, NULL, 5, NULL, 12, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 3.00, 0.00, 0.00, 'efectivo', 3.00, 0.00, NULL, '2026-07-08 09:35:33', '2026-07-08 09:35:36'),
(77, NULL, 5, NULL, 12, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 3.00, 0.00, 0.00, 'efectivo', 3.00, 0.00, NULL, '2026-07-08 10:36:53', '2026-07-08 10:36:55'),
(78, NULL, 5, NULL, 12, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 12.00, 0.00, 0.00, 'efectivo', 12.00, 0.00, NULL, '2026-07-08 10:40:17', '2026-07-08 10:40:22'),
(79, NULL, 5, NULL, 12, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 3.00, 0.00, 0.00, 'qr', 3.00, 0.00, NULL, '2026-07-08 10:43:50', '2026-07-08 10:43:54'),
(80, NULL, 5, NULL, 12, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 3.00, 0.00, 0.00, 'qr', 3.00, 0.00, NULL, '2026-07-08 10:44:10', '2026-07-08 10:44:24'),
(81, NULL, 5, NULL, 13, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 12.00, 0.00, 0.00, 'efectivo', 12.00, 0.00, NULL, '2026-07-08 10:53:58', '2026-07-08 10:54:02'),
(82, NULL, 5, NULL, 13, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 3.00, 0.00, 0.00, 'qr', 3.00, 0.00, NULL, '2026-07-08 10:54:06', '2026-07-08 10:54:11'),
(83, NULL, 5, NULL, 14, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 60.00, 0.00, 0.00, 'efectivo', 60.00, 0.00, NULL, '2026-07-08 10:55:34', '2026-07-08 10:55:39'),
(84, NULL, 5, NULL, 14, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 6.00, 0.00, 0.00, 'qr', 6.00, 0.00, NULL, '2026-07-08 10:55:40', '2026-07-08 10:55:47'),
(85, NULL, 5, NULL, 15, 'cancelado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-08 10:59:13', '2026-07-08 11:39:11'),
(86, NULL, 5, NULL, 15, 'cancelado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 0.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-08 11:39:58', '2026-07-08 18:51:30'),
(87, NULL, 5, NULL, 15, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 3.00, 0.00, 0.00, 'efectivo', 3.00, 0.00, NULL, '2026-07-08 18:51:31', '2026-07-08 18:51:34'),
(88, NULL, 5, NULL, 15, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 3.00, 0.00, 0.00, 'qr', 3.00, 0.00, NULL, '2026-07-08 18:53:01', '2026-07-08 18:53:21'),
(89, NULL, 5, NULL, 15, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 12.00, 0.00, 0.00, 'efectivo', 12.00, 0.00, NULL, '2026-07-08 18:54:38', '2026-07-08 18:54:41'),
(90, NULL, 5, NULL, 15, 'cancelado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 0.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-08 18:55:08', '2026-07-08 18:55:33'),
(91, NULL, 5, NULL, 15, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 3.00, 0.00, 0.00, 'efectivo', 3.00, 0.00, NULL, '2026-07-08 18:55:10', '2026-07-08 18:55:14'),
(92, NULL, 5, NULL, 15, 'completado', 'llevar', 2, 'Ticket', 'Cliente', NULL, 3.00, 0.00, 0.00, 'efectivo', 3.00, 0.00, NULL, '2026-07-08 18:55:36', '2026-07-08 18:55:39'),
(93, 9, 1, NULL, 7, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 12.00, 0.00, 0.00, 'efectivo', 12.00, 0.00, NULL, '2026-07-08 19:07:26', '2026-07-08 19:07:28'),
(94, 9, 1, NULL, 7, 'cancelado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 0.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-09 01:35:44', '2026-07-09 01:36:05'),
(95, 9, 1, NULL, 7, 'cancelado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 0.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-09 01:39:39', '2026-07-09 11:44:25'),
(96, 9, 1, NULL, 7, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 12.00, 0.00, 0.00, 'efectivo', 12.00, 0.00, NULL, '2026-07-09 11:44:26', '2026-07-09 11:44:29'),
(97, 9, 1, NULL, 7, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 3.00, 0.00, 0.00, 'efectivo', 3.00, 0.00, NULL, '2026-07-09 12:09:12', '2026-07-09 12:09:15'),
(98, 10, 1, NULL, 16, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 3.00, 0.00, 0.00, 'efectivo', 3.00, 0.00, NULL, '2026-07-10 23:07:55', '2026-07-10 23:08:01'),
(99, 10, 1, NULL, 16, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 3.00, 0.00, 0.00, 'efectivo', 3.00, 0.00, NULL, '2026-07-10 23:10:20', '2026-07-10 23:10:25'),
(100, 9, 1, NULL, 17, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', 15.00, 0.00, NULL, '2026-07-10 23:18:27', '2026-07-10 23:18:58'),
(101, 9, 1, NULL, 18, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', 15.00, 0.00, NULL, '2026-07-11 01:23:21', '2026-07-11 01:23:25'),
(102, 9, 1, NULL, 18, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'qr', 15.00, 0.00, NULL, '2026-07-11 01:24:14', '2026-07-11 01:24:17'),
(103, 10, 1, NULL, 18, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'qr', 15.00, 0.00, NULL, '2026-07-11 01:24:25', '2026-07-11 01:24:29'),
(105, 9, 1, NULL, 20, 'cancelado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-11 11:33:44', '2026-07-11 11:34:35'),
(106, 10, 1, NULL, 20, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', 15.00, 0.00, NULL, '2026-07-11 11:34:40', '2026-07-11 11:38:20'),
(107, 9, 1, NULL, 20, 'cancelado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-11 11:34:52', '2026-07-11 11:38:58'),
(110, NULL, 1, NULL, 20, 'pendiente', 'llevar', 1, 'Ticket', 'juan', NULL, 15.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-11 11:38:35', '2026-07-11 11:38:43'),
(111, 10, 1, NULL, 20, 'cancelado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', NULL, 0.00, NULL, '2026-07-11 11:42:25', '2026-07-11 12:41:38'),
(112, 10, 1, NULL, 20, 'completado', 'mesa', NULL, 'Ticket', 'Público General', NULL, 15.00, 0.00, 0.00, 'efectivo', 15.00, 0.00, NULL, '2026-07-11 13:19:17', '2026-07-11 13:19:17'),
(113, NULL, 1, NULL, 20, 'completado', 'llevar', 2, 'Ticket', 'juan', NULL, 12.00, 0.00, 0.00, 'efectivo', 12.00, 0.00, NULL, '2026-07-11 13:19:54', '2026-07-11 13:19:54'),
(114, NULL, 1, NULL, 21, 'completado', 'llevar', 3, 'Ticket', 'Cliente', NULL, 15.00, 0.00, 0.00, 'efectivo', 15.00, 0.00, NULL, '2026-07-11 13:29:19', '2026-07-11 13:29:19');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `permisos`
--

CREATE TABLE `permisos` (
  `id` int(10) UNSIGNED NOT NULL,
  `modulo` varchar(50) NOT NULL,
  `accion` varchar(50) NOT NULL,
  `descripcion` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `permisos`
--

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

--
-- Estructura de tabla para la tabla `productos`
--

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

--
-- Volcado de datos para la tabla `productos`
--

INSERT INTO `productos` (`id`, `categoria_id`, `nombre`, `codigo_barras`, `codigo`, `precio`, `costo`, `stock`, `es_vendible`, `imagen`, `activo`, `creado_en`, `actualizado_en`) VALUES
(1, 3, 'Moconchinchi', NULL, NULL, 3.00, NULL, NULL, 1, '/uploads/1782868253811-205432.jpg', 1, '2026-07-01 01:11:15', '2026-07-11 13:12:58'),
(2, 2, 'Coca Cola', NULL, NULL, 12.00, NULL, 11, 1, '/uploads/1782915282345-932520.png', 1, '2026-07-01 14:15:01', '2026-07-11 13:29:19');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `proveedores`
--

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

--
-- Volcado de datos para la tabla `proveedores`
--

INSERT INTO `proveedores` (`id`, `nombre`, `contacto`, `telefono`, `email`, `direccion`, `activo`, `creado_en`, `actualizado_en`) VALUES
(1, 'Proveedor Refrescos', 'Juan David', '74819122', '', '', 1, '2026-07-01 14:16:02', '2026-07-01 14:16:02');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `registros_inventario`
--

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

--
-- Volcado de datos para la tabla `registros_inventario`
--

INSERT INTO `registros_inventario` (`id`, `producto_id`, `usuario_id`, `tipo`, `cantidad`, `stock_anterior`, `stock_nuevo`, `nota`, `creado_en`, `actualizado_en`) VALUES
(1, 2, 1, 'entrada', 14, 0, 14, '', '2026-07-01 14:15:14', '2026-07-01 14:15:14'),
(2, 2, 1, 'compra', 15, 14, 29, 'Compra #1', '2026-07-01 14:16:54', '2026-07-01 14:16:54'),
(3, 1, 1, 'compra', 1, NULL, 1, 'Compra #1', '2026-07-01 14:16:54', '2026-07-01 14:16:54'),
(4, 1, 1, 'ajuste', 3, 1, 3, '', '2026-07-01 14:27:01', '2026-07-01 14:27:01'),
(5, 1, 1, 'venta', 1, 3, 2, 'Venta #7', '2026-07-02 11:21:31', '2026-07-02 11:21:31'),
(6, 2, 1, 'venta', 1, 29, 28, 'Venta #7', '2026-07-02 11:21:31', '2026-07-02 11:21:31'),
(7, 2, 1, 'venta', 1, 28, 27, 'Venta #9', '2026-07-02 12:11:41', '2026-07-02 12:11:41'),
(8, 1, 1, 'venta', 1, 2, 1, 'Venta #9', '2026-07-02 12:11:41', '2026-07-02 12:11:41'),
(9, 1, 1, 'venta', 1, 1, 0, 'Venta #10', '2026-07-02 12:12:01', '2026-07-02 12:12:01'),
(10, 2, 1, 'venta', 1, 27, 26, 'Venta #10', '2026-07-02 12:12:01', '2026-07-02 12:12:01'),
(11, 2, 1, 'venta', 1, 26, 25, 'Venta #11', '2026-07-02 12:12:16', '2026-07-02 12:12:16'),
(12, 1, 1, 'venta', 1, 0, -1, 'Venta #11', '2026-07-02 12:12:16', '2026-07-02 12:12:16'),
(13, 1, 3, 'venta', 1, -1, -2, 'Venta #12', '2026-07-02 12:38:03', '2026-07-02 12:38:03'),
(14, 2, 3, 'venta', 1, 25, 24, 'Venta #12', '2026-07-02 12:38:03', '2026-07-02 12:38:03'),
(15, 1, 3, 'venta', 3, -2, -5, 'Venta #13', '2026-07-02 12:38:22', '2026-07-02 12:38:22'),
(16, 2, 3, 'venta', 3, 24, 21, 'Venta #13', '2026-07-02 12:38:22', '2026-07-02 12:38:22'),
(17, 1, 3, 'venta', 1, -5, -6, 'Venta #15', '2026-07-02 12:39:21', '2026-07-02 12:39:21'),
(18, 2, 3, 'venta', 1, 21, 20, 'Venta #15', '2026-07-02 12:39:21', '2026-07-02 12:39:21'),
(19, 1, 3, 'venta', 1, -6, -7, 'Venta #16', '2026-07-02 12:39:58', '2026-07-02 12:39:58'),
(20, 2, 3, 'venta', 2, 20, 18, 'Venta #16', '2026-07-02 12:39:58', '2026-07-02 12:39:58'),
(21, 2, 1, 'venta', 1, 18, 17, 'Venta #18', '2026-07-02 12:42:48', '2026-07-02 12:42:48'),
(22, 1, 1, 'venta', 1, -7, -8, 'Venta #18', '2026-07-02 12:42:48', '2026-07-02 12:42:48'),
(23, 2, 3, 'venta', 1, 17, 16, 'Venta #21', '2026-07-02 12:54:11', '2026-07-02 12:54:11'),
(24, 1, 3, 'venta', 1, -8, -9, 'Venta #21', '2026-07-02 12:54:11', '2026-07-02 12:54:11'),
(25, 1, 1, 'venta', 1, -9, -10, 'Venta #23', '2026-07-02 21:51:53', '2026-07-02 21:51:53'),
(26, 2, 1, 'venta', 11, 16, 5, 'Venta #23', '2026-07-02 21:51:53', '2026-07-02 21:51:53'),
(27, 2, 1, 'venta', 11, 5, -6, 'Venta #24', '2026-07-02 21:52:05', '2026-07-02 21:52:05'),
(28, 2, 1, 'venta', 12, -6, -18, 'Venta #25', '2026-07-02 21:52:17', '2026-07-02 21:52:17'),
(29, 1, 1, 'venta', 1, -10, -11, 'Venta #29', '2026-07-03 13:16:05', '2026-07-03 13:16:05'),
(30, 2, 1, 'venta', 1, -18, -19, 'Venta #29', '2026-07-03 13:16:05', '2026-07-03 13:16:05'),
(31, 2, 1, 'venta', 1, -19, -20, 'Venta #30', '2026-07-03 13:16:34', '2026-07-03 13:16:34'),
(32, 1, 1, 'venta', 1, -11, -12, 'Venta #30', '2026-07-03 13:16:34', '2026-07-03 13:16:34'),
(33, 1, 1, 'venta', 1, -12, -13, 'Venta #31', '2026-07-03 13:20:02', '2026-07-03 13:20:02'),
(34, 2, 1, 'venta', 1, -20, -21, 'Venta #31', '2026-07-03 13:20:02', '2026-07-03 13:20:02'),
(35, 1, 1, 'venta', 1, -13, -14, 'Venta #32', '2026-07-03 13:35:44', '2026-07-03 13:35:44'),
(36, 2, 1, 'venta', 1, -21, -22, 'Venta #32', '2026-07-03 13:35:44', '2026-07-03 13:35:44'),
(37, 1, 1, 'venta', 1, -14, -15, 'Venta #34', '2026-07-03 13:36:18', '2026-07-03 13:36:18'),
(38, 2, 1, 'venta', 1, -22, -23, 'Venta #34', '2026-07-03 13:36:18', '2026-07-03 13:36:18'),
(39, 1, 1, 'venta', 1, -15, -16, 'Venta #35', '2026-07-03 13:37:14', '2026-07-03 13:37:14'),
(40, 2, 1, 'venta', 1, -23, -24, 'Venta #35', '2026-07-03 13:37:14', '2026-07-03 13:37:14'),
(41, 1, 1, 'venta', 1, -16, -17, 'Venta #36', '2026-07-03 14:21:46', '2026-07-03 14:21:46'),
(42, 2, 1, 'venta', 1, -24, -25, 'Venta #36', '2026-07-03 14:21:46', '2026-07-03 14:21:46'),
(43, 1, 1, 'venta', 1, -17, -18, 'Venta #37', '2026-07-04 17:31:18', '2026-07-04 17:31:18'),
(44, 2, 1, 'venta', 1, -25, -26, 'Venta #37', '2026-07-04 17:31:18', '2026-07-04 17:31:18'),
(45, 1, 1, 'venta', 1, -18, -19, 'Venta #38', '2026-07-04 17:32:51', '2026-07-04 17:32:51'),
(46, 2, 1, 'venta', 1, -26, -27, 'Venta #38', '2026-07-04 17:32:51', '2026-07-04 17:32:51'),
(47, 1, 1, 'venta', 2, -19, -21, 'Venta #39', '2026-07-04 17:34:47', '2026-07-04 17:34:47'),
(48, 2, 1, 'venta', 1, -27, -28, 'Venta #40', '2026-07-04 17:37:50', '2026-07-04 17:37:50'),
(49, 1, 1, 'venta', 1, -21, -22, 'Venta #40', '2026-07-04 17:37:50', '2026-07-04 17:37:50'),
(50, 1, 1, 'venta', 1, -22, -23, 'Venta #41', '2026-07-04 17:48:39', '2026-07-04 17:48:39'),
(51, 2, 1, 'venta', 1, -28, -29, 'Venta #41', '2026-07-04 17:48:39', '2026-07-04 17:48:39'),
(52, 1, 5, 'venta', 6, -23, -29, 'Venta #42', '2026-07-04 18:46:40', '2026-07-04 18:46:40'),
(53, 2, 5, 'venta', 5, -29, -34, 'Venta #42', '2026-07-04 18:46:40', '2026-07-04 18:46:40'),
(54, 2, 5, 'venta', 1, -34, -35, 'Venta #43', '2026-07-04 18:46:54', '2026-07-04 18:46:54'),
(55, 1, 5, 'venta', 3, -29, -32, 'Venta #43', '2026-07-04 18:46:54', '2026-07-04 18:46:54'),
(56, 1, 5, 'venta', 1, -32, -33, 'Venta #44', '2026-07-04 19:21:22', '2026-07-04 19:21:22'),
(57, 2, 5, 'venta', 1, -35, -36, 'Venta #44', '2026-07-04 19:21:22', '2026-07-04 19:21:22'),
(58, 1, 5, 'venta', 1, -33, -34, 'Venta #45', '2026-07-04 19:23:32', '2026-07-04 19:23:32'),
(59, 2, 5, 'venta', 1, -36, -37, 'Venta #45', '2026-07-04 19:23:32', '2026-07-04 19:23:32'),
(60, 1, 5, 'venta', 1, -34, -35, 'Venta #46', '2026-07-04 19:41:46', '2026-07-04 19:41:46'),
(61, 2, 5, 'venta', 1, -37, -38, 'Venta #46', '2026-07-04 19:41:46', '2026-07-04 19:41:46'),
(62, 1, 5, 'venta', 12, -35, -47, 'Venta #47', '2026-07-04 19:45:54', '2026-07-04 19:45:54'),
(63, 2, 5, 'venta', 2, -38, -40, 'Venta #47', '2026-07-04 19:45:54', '2026-07-04 19:45:54'),
(64, 2, 5, 'venta', 2, -40, -42, 'Venta #48', '2026-07-06 02:00:11', '2026-07-06 02:00:11'),
(65, 1, 5, 'venta', 2, -47, -49, 'Venta #48', '2026-07-06 02:00:11', '2026-07-06 02:00:11'),
(66, 1, 5, 'venta', 1, -49, -50, 'Venta #49', '2026-07-06 02:01:28', '2026-07-06 02:01:28'),
(67, 2, 5, 'venta', 1, -42, -43, 'Venta #49', '2026-07-06 02:01:28', '2026-07-06 02:01:28'),
(68, 1, 5, 'venta', 1, -50, -51, 'Venta #50', '2026-07-06 02:21:25', '2026-07-06 02:21:25'),
(69, 2, 5, 'venta', 1, -43, -44, 'Venta #50', '2026-07-06 02:21:25', '2026-07-06 02:21:25'),
(70, 1, 5, 'venta', 1, -51, -52, 'Venta #51', '2026-07-06 02:21:45', '2026-07-06 02:21:45'),
(71, 2, 5, 'venta', 1, -44, -45, 'Venta #51', '2026-07-06 02:21:45', '2026-07-06 02:21:45'),
(72, 1, 5, 'venta', 1, -52, -53, 'Venta #52', '2026-07-06 02:31:23', '2026-07-06 02:31:23'),
(73, 2, 5, 'venta', 1, -45, -46, 'Venta #52', '2026-07-06 02:31:23', '2026-07-06 02:31:23'),
(74, 2, 5, 'venta', 1, -46, -47, 'Venta #53', '2026-07-06 02:32:54', '2026-07-06 02:32:54'),
(75, 1, 5, 'venta', 2, -53, -55, 'Venta #53', '2026-07-06 02:32:54', '2026-07-06 02:32:54'),
(76, 1, 5, 'venta', 4, -55, -59, 'Venta #54', '2026-07-06 02:39:51', '2026-07-06 02:39:51'),
(77, 2, 5, 'venta', 1, -47, -48, 'Venta #54', '2026-07-06 02:39:51', '2026-07-06 02:39:51'),
(78, 1, 5, 'venta', 3, -59, -62, 'Venta #55', '2026-07-06 02:46:37', '2026-07-06 02:46:37'),
(79, 2, 5, 'venta', 1, -48, -49, 'Venta #55', '2026-07-06 02:46:37', '2026-07-06 02:46:37'),
(80, 1, 5, 'venta', 2, -62, -64, 'Venta #56', '2026-07-06 02:48:46', '2026-07-06 02:48:46'),
(81, 1, 5, 'venta', 1, -64, -65, 'Venta #57', '2026-07-06 02:49:18', '2026-07-06 02:49:18'),
(82, 1, 5, 'venta', 1, -65, -66, 'Venta #58', '2026-07-06 02:57:11', '2026-07-06 02:57:11'),
(83, 2, 5, 'venta', 1, -49, -50, 'Venta #58', '2026-07-06 02:57:11', '2026-07-06 02:57:11'),
(84, 2, 5, 'venta', 1, -50, -51, 'Venta #59', '2026-07-06 03:01:36', '2026-07-06 03:01:36'),
(85, 1, 5, 'venta', 2, -66, -68, 'Venta #59', '2026-07-06 03:01:36', '2026-07-06 03:01:36'),
(86, 1, 5, 'venta', 1, -68, -69, 'Venta #60', '2026-07-06 11:59:49', '2026-07-06 11:59:49'),
(87, 1, 5, 'venta', 1, -69, -70, 'Venta #62', '2026-07-06 12:04:29', '2026-07-06 12:04:29'),
(88, 2, 5, 'venta', 1, -51, -52, 'Venta #62', '2026-07-06 12:04:29', '2026-07-06 12:04:29'),
(89, 2, 5, 'venta', 1, -52, -53, 'Venta #64', '2026-07-06 12:08:58', '2026-07-06 12:08:58'),
(90, 1, 5, 'venta', 1, -70, -71, 'Venta #64', '2026-07-06 12:08:58', '2026-07-06 12:08:58'),
(91, 1, 5, 'venta', 1, -71, -72, 'Venta #66', '2026-07-06 12:26:13', '2026-07-06 12:26:13'),
(92, 2, 5, 'venta', 1, -53, -54, 'Venta #66', '2026-07-06 12:26:13', '2026-07-06 12:26:13'),
(93, 1, 5, 'venta', 2, -72, -74, 'Venta #68', '2026-07-06 15:50:43', '2026-07-06 15:50:43'),
(94, 2, 5, 'venta', 1, -54, -55, 'Venta #68', '2026-07-06 15:50:43', '2026-07-06 15:50:43'),
(95, 1, 5, 'venta', 1, -74, -75, 'Venta #69', '2026-07-06 15:51:46', '2026-07-06 15:51:46'),
(96, 2, 5, 'venta', 1, -55, -56, 'Venta #69', '2026-07-06 15:51:46', '2026-07-06 15:51:46'),
(97, 1, 5, 'venta', 1, -75, -76, 'Venta #70', '2026-07-06 15:53:51', '2026-07-06 15:53:51'),
(98, 2, 5, 'venta', 1, -56, -57, 'Venta #70', '2026-07-06 15:53:51', '2026-07-06 15:53:51'),
(99, 1, 5, 'venta', 1, -76, -77, 'Venta #71', '2026-07-08 09:24:13', '2026-07-08 09:24:13'),
(100, 1, 5, 'venta', 1, -77, -78, 'Venta #72', '2026-07-08 09:25:16', '2026-07-08 09:25:16'),
(101, 1, 5, 'venta', 1, -78, -79, 'Venta #73', '2026-07-08 09:25:29', '2026-07-08 09:25:29'),
(102, 2, 5, 'venta', 1, -57, -58, 'Venta #74', '2026-07-08 09:34:56', '2026-07-08 09:34:56'),
(103, 1, 5, 'venta', 1, -79, -80, 'Venta #76', '2026-07-08 09:35:36', '2026-07-08 09:35:36'),
(104, 1, 5, 'venta', 1, -80, -81, 'Venta #77', '2026-07-08 10:36:55', '2026-07-08 10:36:55'),
(105, 2, 5, 'venta', 1, -58, -59, 'Venta #78', '2026-07-08 10:40:22', '2026-07-08 10:40:22'),
(106, 1, 5, 'venta', 1, -81, -82, 'Venta #79', '2026-07-08 10:43:54', '2026-07-08 10:43:54'),
(107, 1, 5, 'venta', 1, -82, -83, 'Venta #80', '2026-07-08 10:44:24', '2026-07-08 10:44:24'),
(108, 2, 5, 'venta', 1, -59, -60, 'Venta #81', '2026-07-08 10:54:02', '2026-07-08 10:54:02'),
(109, 1, 5, 'venta', 1, -83, -84, 'Venta #82', '2026-07-08 10:54:11', '2026-07-08 10:54:11'),
(110, 2, 5, 'venta', 5, -60, -65, 'Venta #83', '2026-07-08 10:55:39', '2026-07-08 10:55:39'),
(111, 1, 5, 'venta', 2, -84, -86, 'Venta #84', '2026-07-08 10:55:47', '2026-07-08 10:55:47'),
(112, 1, 5, 'venta', 1, -86, -87, 'Venta #87', '2026-07-08 18:51:34', '2026-07-08 18:51:34'),
(113, 1, 5, 'venta', 1, -87, -88, 'Venta #88', '2026-07-08 18:53:21', '2026-07-08 18:53:21'),
(114, 2, 5, 'venta', 1, -65, -66, 'Venta #89', '2026-07-08 18:54:41', '2026-07-08 18:54:41'),
(115, 1, 5, 'venta', 1, -88, -89, 'Venta #91', '2026-07-08 18:55:14', '2026-07-08 18:55:14'),
(116, 1, 5, 'venta', 1, -89, -90, 'Venta #92', '2026-07-08 18:55:39', '2026-07-08 18:55:39'),
(117, 2, 1, 'venta', 1, -66, -67, 'Venta #93', '2026-07-08 19:07:28', '2026-07-08 19:07:28'),
(118, 2, 1, 'venta', 1, -67, -68, 'Venta #96', '2026-07-09 11:44:29', '2026-07-09 11:44:29'),
(119, 1, 1, 'venta', 1, -90, -91, 'Venta #97', '2026-07-09 12:09:15', '2026-07-09 12:09:15'),
(120, 1, 1, 'venta', 1, -91, -92, 'Venta #98', '2026-07-10 23:08:01', '2026-07-10 23:08:01'),
(121, 1, 1, 'venta', 1, -92, -93, 'Venta #99', '2026-07-10 23:10:25', '2026-07-10 23:10:25'),
(122, 1, 1, 'venta', 1, -93, -94, 'Venta #100', '2026-07-10 23:18:59', '2026-07-10 23:18:59'),
(123, 2, 1, 'venta', 1, -68, -69, 'Venta #100', '2026-07-10 23:18:59', '2026-07-10 23:18:59'),
(124, 2, 1, 'venta', 1, -69, -70, 'Venta #101', '2026-07-11 01:23:25', '2026-07-11 01:23:25'),
(125, 1, 1, 'venta', 1, -94, -95, 'Venta #101', '2026-07-11 01:23:25', '2026-07-11 01:23:25'),
(126, 2, 1, 'venta', 1, -70, -71, 'Venta #102', '2026-07-11 01:24:17', '2026-07-11 01:24:17'),
(127, 1, 1, 'venta', 1, -95, -96, 'Venta #102', '2026-07-11 01:24:17', '2026-07-11 01:24:17'),
(128, 2, 1, 'venta', 1, -71, -72, 'Venta #103', '2026-07-11 01:24:29', '2026-07-11 01:24:29'),
(129, 1, 1, 'venta', 1, -96, -97, 'Venta #103', '2026-07-11 01:24:29', '2026-07-11 01:24:29'),
(130, 2, 1, 'compra', 12, -72, -60, 'Compra #2', '2026-07-11 01:39:32', '2026-07-11 01:39:32'),
(131, 2, 1, 'venta', 1, 50, 49, 'Venta #106', '2026-07-11 11:38:20', '2026-07-11 11:38:20'),
(132, 1, 1, 'venta', 1, 50, 49, 'Venta #106', '2026-07-11 11:38:20', '2026-07-11 11:38:20'),
(135, 2, 1, 'venta', 1, 1, 0, 'Venta #113', '2026-07-11 13:19:54', '2026-07-11 13:19:54'),
(136, 2, 1, 'compra', 12, 0, 12, 'Compra #3', '2026-07-11 13:21:08', '2026-07-11 13:21:08'),
(137, 2, 1, 'venta', 1, 12, 11, 'Venta #114', '2026-07-11 13:29:19', '2026-07-11 13:29:19');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `reservaciones`
--

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

--
-- Estructura de tabla para la tabla `roles`
--

CREATE TABLE `roles` (
  `id` int(10) UNSIGNED NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `descripcion` varchar(255) DEFAULT NULL,
  `creado_en` timestamp NOT NULL DEFAULT current_timestamp(),
  `actualizado_en` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `roles`
--

INSERT INTO `roles` (`id`, `nombre`, `descripcion`, `creado_en`, `actualizado_en`) VALUES
(1, 'Administrador', 'Acceso total al sistema', '2026-07-01 00:23:31', '2026-07-01 00:23:31'),
(2, 'Cajero', 'Ventas, caja, clientes y libro caja', '2026-07-01 00:23:31', '2026-07-01 00:23:31'),
(3, 'Mesero', 'Toma de pedidos y vista de mesas', '2026-07-01 00:23:31', '2026-07-01 00:23:31'),
(4, 'Cocina', 'Pantalla de cocina — ver y marcar pedidos', '2026-07-01 00:23:31', '2026-07-01 00:23:31');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `roles_permisos`
--

CREATE TABLE `roles_permisos` (
  `rol_id` int(10) UNSIGNED NOT NULL,
  `permiso_id` int(10) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `roles_permisos`
--

INSERT INTO `roles_permisos` (`rol_id`, `permiso_id`) VALUES
(1, 1),
(1, 2),
(1, 3),
(1, 4),
(1, 5),
(1, 6),
(1, 7),
(1, 8),
(1, 9),
(1, 10),
(1, 11),
(1, 12),
(1, 13),
(1, 14),
(1, 15),
(1, 16),
(1, 17),
(1, 18),
(1, 19),
(1, 20),
(1, 21),
(1, 22),
(1, 23),
(1, 24),
(1, 25),
(1, 26),
(1, 27),
(1, 28),
(1, 29),
(1, 30),
(1, 31),
(1, 32),
(1, 33),
(1, 34),
(1, 35),
(1, 36),
(1, 37),
(1, 38),
(2, 1),
(2, 2),
(2, 3),
(2, 4),
(2, 8),
(2, 13),
(2, 14),
(2, 15),
(2, 16),
(2, 17),
(2, 25),
(2, 26),
(2, 27),
(2, 28),
(2, 29),
(2, 30),
(2, 31),
(3, 1),
(3, 2),
(3, 39),
(4, 39);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `sesiones_caja`
--

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

--
-- Volcado de datos para la tabla `sesiones_caja`
--

INSERT INTO `sesiones_caja` (`id`, `usuario_id`, `monto_apertura`, `monto_cierre`, `total_ventas`, `total_gastos`, `diferencia`, `abierto_en`, `cerrado_en`, `estado`) VALUES
(1, 1, 10.00, 10.00, 0.00, 0.00, 0.00, '2026-07-01 01:11:25', '2026-07-01 13:22:06', 'cerrada'),
(2, 1, 10.00, 25.00, 15.00, 0.00, 0.00, '2026-07-01 14:27:26', '2026-07-02 11:22:00', 'cerrada'),
(3, 1, 10.00, 35.00, 45.00, 20.00, 45.00, '2026-07-02 11:23:09', '2026-07-02 12:13:11', 'cerrada'),
(4, 3, 10.00, 112.00, 102.00, 0.00, 102.00, '2026-07-02 12:37:48', '2026-07-02 12:40:16', 'cerrada'),
(5, 1, 10.00, 25.00, 15.00, 0.00, 15.00, '2026-07-02 12:41:11', '2026-07-02 12:43:06', 'cerrada'),
(6, 3, 10.00, NULL, 15.00, 0.00, NULL, '2026-07-02 12:43:39', '0000-00-00 00:00:00', 'abierta'),
(7, 1, 10.00, 170.00, 609.00, 0.00, -8.01, '2026-07-02 16:55:41', '2026-07-10 23:07:27', 'cerrada'),
(8, 5, 20.00, 119.00, 99.00, 0.00, 0.00, '2026-07-04 18:46:27', '2026-07-04 18:47:12', 'cerrada'),
(9, 5, 0.00, 35.00, 45.00, 10.00, 0.00, '2026-07-04 19:17:25', '2026-07-04 19:42:20', 'cerrada'),
(10, 5, 0.00, 20.00, 60.00, 40.00, 0.00, '2026-07-04 19:45:45', '2026-07-04 19:46:15', 'cerrada'),
(11, 5, 100.00, 400.00, 300.00, 0.00, 0.00, '2026-07-06 02:00:02', '2026-07-08 09:26:41', 'cerrada'),
(12, 5, 0.00, 36.00, 36.00, 0.00, 6.00, '2026-07-08 09:34:46', '2026-07-08 10:44:52', 'cerrada'),
(13, 5, 0.00, 12.00, 15.00, 0.00, 0.00, '2026-07-08 10:53:56', '2026-07-08 10:54:49', 'cerrada'),
(14, 5, 0.00, 35.00, 66.00, 25.00, 0.00, '2026-07-08 10:55:31', '2026-07-08 10:56:27', 'cerrada'),
(15, 5, 0.00, NULL, 24.00, 0.00, NULL, '2026-07-08 10:59:08', '0000-00-00 00:00:00', 'abierta'),
(16, 1, 0.00, 6.00, 6.00, 0.00, 0.00, '2026-07-10 23:07:49', '2026-07-10 23:14:07', 'cerrada'),
(17, 1, 0.00, 35.00, 15.00, 0.00, 20.00, '2026-07-10 23:18:18', '2026-07-10 23:23:37', 'cerrada'),
(18, 1, 0.00, 15.00, 45.00, 0.00, 0.00, '2026-07-11 01:23:17', '2026-07-11 01:25:05', 'cerrada'),
(19, 1, 10.00, 10.00, 0.00, 0.00, 0.00, '2026-07-11 01:37:42', '2026-07-11 01:38:00', 'cerrada'),
(20, 1, 0.00, 42.00, 42.00, 0.00, 0.00, '2026-07-11 11:31:44', '2026-07-11 13:22:12', 'cerrada'),
(21, 1, 0.00, NULL, 15.00, 0.00, NULL, '2026-07-11 13:28:25', '0000-00-00 00:00:00', 'abierta');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `usuarios`
--

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

--
-- Volcado de datos para la tabla `usuarios`
--

INSERT INTO `usuarios` (`id`, `rol_id`, `nombre`, `email`, `contrasena`, `activo`, `token_recordar`, `creado_en`, `actualizado_en`) VALUES
(1, 1, 'Administrador', 'admin@restaurante.com', '$2b$12$spw0UQ5SEJHbG1RePnlfLuMEOGxqL9TRvKwg1Hi7D2E5JQUCYplPS', 1, NULL, '2026-07-01 00:23:31', '2026-07-01 00:23:31'),
(3, 2, 'Cajero', 'cajero@restaurante.com', '$2b$10$Wa2Id4WTi6QtkSgl6hh1Du.19d9PNZFX4Xmy2d6wWaDtRh.PpK8Be', 0, NULL, '2026-07-02 12:36:56', '2026-07-04 18:17:32'),
(5, 2, 'sadsd', 'sdsd@restaurante.com', '$2b$10$cpl4yrDRGZ2OFk12ZimVTeLP8BI/kR5KX/tj1UUY8QRUEK9P0777e', 1, NULL, '2026-07-04 18:18:02', '2026-07-04 18:18:26');

--
-- Índices para tablas volcadas
--

--
-- Indices de la tabla `areas`
--
ALTER TABLE `areas`
  ADD PRIMARY KEY (`id`);

--
-- Indices de la tabla `categorias`
--
ALTER TABLE `categorias`
  ADD PRIMARY KEY (`id`);

--
-- Indices de la tabla `clientes`
--
ALTER TABLE `clientes`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `clientes_doc_unique` (`numero_documento`);

--
-- Indices de la tabla `compras`
--
ALTER TABLE `compras`
  ADD PRIMARY KEY (`id`),
  ADD KEY `proveedor_id` (`proveedor_id`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `configuraciones`
--
ALTER TABLE `configuraciones`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `configuraciones_clave_unique` (`clave`);

--
-- Indices de la tabla `detalle_arqueo`
--
ALTER TABLE `detalle_arqueo`
  ADD PRIMARY KEY (`id`),
  ADD KEY `sesion_caja_id` (`sesion_caja_id`);

--
-- Indices de la tabla `detalle_compras`
--
ALTER TABLE `detalle_compras`
  ADD PRIMARY KEY (`id`),
  ADD KEY `compra_id` (`compra_id`),
  ADD KEY `producto_id` (`producto_id`);

--
-- Indices de la tabla `detalle_pedidos`
--
ALTER TABLE `detalle_pedidos`
  ADD PRIMARY KEY (`id`),
  ADD KEY `pedido_id` (`pedido_id`),
  ADD KEY `producto_id` (`producto_id`);

--
-- Indices de la tabla `gastos`
--
ALTER TABLE `gastos`
  ADD PRIMARY KEY (`id`),
  ADD KEY `sesion_caja_id` (`sesion_caja_id`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `ingredientes_producto`
--
ALTER TABLE `ingredientes_producto`
  ADD PRIMARY KEY (`id`),
  ADD KEY `producto_id` (`producto_id`),
  ADD KEY `ingrediente_id` (`ingrediente_id`);

--
-- Indices de la tabla `libro_caja`
--
ALTER TABLE `libro_caja`
  ADD PRIMARY KEY (`id`),
  ADD KEY `sesion_caja_id` (`sesion_caja_id`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `mesas`
--
ALTER TABLE `mesas`
  ADD PRIMARY KEY (`id`),
  ADD KEY `area_id` (`area_id`);

--
-- Indices de la tabla `pedidos`
--
ALTER TABLE `pedidos`
  ADD PRIMARY KEY (`id`),
  ADD KEY `mesa_id` (`mesa_id`),
  ADD KEY `usuario_id` (`usuario_id`),
  ADD KEY `cliente_id` (`cliente_id`),
  ADD KEY `sesion_caja_id` (`sesion_caja_id`);

--
-- Indices de la tabla `permisos`
--
ALTER TABLE `permisos`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `permiso_unico` (`modulo`,`accion`);

--
-- Indices de la tabla `productos`
--
ALTER TABLE `productos`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `productos_barcode_unique` (`codigo_barras`),
  ADD KEY `categoria_id` (`categoria_id`);

--
-- Indices de la tabla `proveedores`
--
ALTER TABLE `proveedores`
  ADD PRIMARY KEY (`id`);

--
-- Indices de la tabla `registros_inventario`
--
ALTER TABLE `registros_inventario`
  ADD PRIMARY KEY (`id`),
  ADD KEY `producto_id` (`producto_id`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `reservaciones`
--
ALTER TABLE `reservaciones`
  ADD PRIMARY KEY (`id`),
  ADD KEY `mesa_id` (`mesa_id`);

--
-- Indices de la tabla `roles`
--
ALTER TABLE `roles`
  ADD PRIMARY KEY (`id`);

--
-- Indices de la tabla `roles_permisos`
--
ALTER TABLE `roles_permisos`
  ADD PRIMARY KEY (`rol_id`,`permiso_id`),
  ADD KEY `permiso_id` (`permiso_id`);

--
-- Indices de la tabla `sesiones_caja`
--
ALTER TABLE `sesiones_caja`
  ADD PRIMARY KEY (`id`),
  ADD KEY `usuario_id` (`usuario_id`);

--
-- Indices de la tabla `usuarios`
--
ALTER TABLE `usuarios`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `usuarios_email_unique` (`email`),
  ADD KEY `rol_id` (`rol_id`);

--
-- AUTO_INCREMENT de las tablas volcadas
--

--
-- AUTO_INCREMENT de la tabla `areas`
--
ALTER TABLE `areas`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `categorias`
--
ALTER TABLE `categorias`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `clientes`
--
ALTER TABLE `clientes`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `compras`
--
ALTER TABLE `compras`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `configuraciones`
--
ALTER TABLE `configuraciones`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=42;

--
-- AUTO_INCREMENT de la tabla `detalle_arqueo`
--
ALTER TABLE `detalle_arqueo`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=41;

--
-- AUTO_INCREMENT de la tabla `detalle_compras`
--
ALTER TABLE `detalle_compras`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT de la tabla `detalle_pedidos`
--
ALTER TABLE `detalle_pedidos`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=176;

--
-- AUTO_INCREMENT de la tabla `gastos`
--
ALTER TABLE `gastos`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT de la tabla `ingredientes_producto`
--
ALTER TABLE `ingredientes_producto`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `libro_caja`
--
ALTER TABLE `libro_caja`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=94;

--
-- AUTO_INCREMENT de la tabla `mesas`
--
ALTER TABLE `mesas`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT de la tabla `pedidos`
--
ALTER TABLE `pedidos`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=115;

--
-- AUTO_INCREMENT de la tabla `permisos`
--
ALTER TABLE `permisos`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=40;

--
-- AUTO_INCREMENT de la tabla `productos`
--
ALTER TABLE `productos`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT de la tabla `proveedores`
--
ALTER TABLE `proveedores`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `registros_inventario`
--
ALTER TABLE `registros_inventario`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=138;

--
-- AUTO_INCREMENT de la tabla `reservaciones`
--
ALTER TABLE `reservaciones`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `roles`
--
ALTER TABLE `roles`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT de la tabla `sesiones_caja`
--
ALTER TABLE `sesiones_caja`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=22;

--
-- AUTO_INCREMENT de la tabla `usuarios`
--
ALTER TABLE `usuarios`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- Restricciones para tablas volcadas
--

--
-- Filtros para la tabla `compras`
--
ALTER TABLE `compras`
  ADD CONSTRAINT `compras_ibfk_1` FOREIGN KEY (`proveedor_id`) REFERENCES `proveedores` (`id`),
  ADD CONSTRAINT `compras_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`);

--
-- Filtros para la tabla `detalle_arqueo`
--
ALTER TABLE `detalle_arqueo`
  ADD CONSTRAINT `detalle_arqueo_ibfk_1` FOREIGN KEY (`sesion_caja_id`) REFERENCES `sesiones_caja` (`id`) ON DELETE CASCADE;

--
-- Filtros para la tabla `detalle_compras`
--
ALTER TABLE `detalle_compras`
  ADD CONSTRAINT `detalle_compras_ibfk_1` FOREIGN KEY (`compra_id`) REFERENCES `compras` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `detalle_compras_ibfk_2` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`id`);

--
-- Filtros para la tabla `detalle_pedidos`
--
ALTER TABLE `detalle_pedidos`
  ADD CONSTRAINT `detalle_pedidos_ibfk_1` FOREIGN KEY (`pedido_id`) REFERENCES `pedidos` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `detalle_pedidos_ibfk_2` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`id`);

--
-- Filtros para la tabla `gastos`
--
ALTER TABLE `gastos`
  ADD CONSTRAINT `gastos_ibfk_1` FOREIGN KEY (`sesion_caja_id`) REFERENCES `sesiones_caja` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `gastos_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`);

--
-- Filtros para la tabla `ingredientes_producto`
--
ALTER TABLE `ingredientes_producto`
  ADD CONSTRAINT `ingredientes_producto_ibfk_1` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `ingredientes_producto_ibfk_2` FOREIGN KEY (`ingrediente_id`) REFERENCES `productos` (`id`) ON DELETE CASCADE;

--
-- Filtros para la tabla `libro_caja`
--
ALTER TABLE `libro_caja`
  ADD CONSTRAINT `libro_caja_ibfk_1` FOREIGN KEY (`sesion_caja_id`) REFERENCES `sesiones_caja` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `libro_caja_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`);

--
-- Filtros para la tabla `mesas`
--
ALTER TABLE `mesas`
  ADD CONSTRAINT `mesas_ibfk_1` FOREIGN KEY (`area_id`) REFERENCES `areas` (`id`) ON DELETE CASCADE;

--
-- Filtros para la tabla `pedidos`
--
ALTER TABLE `pedidos`
  ADD CONSTRAINT `pedidos_ibfk_1` FOREIGN KEY (`mesa_id`) REFERENCES `mesas` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `pedidos_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`),
  ADD CONSTRAINT `pedidos_ibfk_3` FOREIGN KEY (`cliente_id`) REFERENCES `clientes` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `pedidos_ibfk_4` FOREIGN KEY (`sesion_caja_id`) REFERENCES `sesiones_caja` (`id`) ON DELETE SET NULL;

--
-- Filtros para la tabla `productos`
--
ALTER TABLE `productos`
  ADD CONSTRAINT `productos_ibfk_1` FOREIGN KEY (`categoria_id`) REFERENCES `categorias` (`id`) ON DELETE CASCADE;

--
-- Filtros para la tabla `registros_inventario`
--
ALTER TABLE `registros_inventario`
  ADD CONSTRAINT `registros_inventario_ibfk_1` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `registros_inventario_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`);

--
-- Filtros para la tabla `reservaciones`
--
ALTER TABLE `reservaciones`
  ADD CONSTRAINT `reservaciones_ibfk_1` FOREIGN KEY (`mesa_id`) REFERENCES `mesas` (`id`) ON DELETE SET NULL;

--
-- Filtros para la tabla `roles_permisos`
--
ALTER TABLE `roles_permisos`
  ADD CONSTRAINT `roles_permisos_ibfk_1` FOREIGN KEY (`rol_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `roles_permisos_ibfk_2` FOREIGN KEY (`permiso_id`) REFERENCES `permisos` (`id`) ON DELETE CASCADE;

--
-- Filtros para la tabla `sesiones_caja`
--
ALTER TABLE `sesiones_caja`
  ADD CONSTRAINT `sesiones_caja_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`);

--
-- Filtros para la tabla `usuarios`
--
ALTER TABLE `usuarios`
  ADD CONSTRAINT `usuarios_ibfk_1` FOREIGN KEY (`rol_id`) REFERENCES `roles` (`id`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
