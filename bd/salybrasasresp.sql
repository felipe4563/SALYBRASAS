-- MySQL dump 10.13  Distrib 8.4.7, for Linux (x86_64)
--
-- Host: localhost    Database: bd_salybrasasprod
-- ------------------------------------------------------
-- Server version	8.4.7-0ubuntu0.25.04.2

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `areas`
--

DROP TABLE IF EXISTS `areas`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `areas` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `sucursal_id` int unsigned NOT NULL,
  `nombre` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `creado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `sucursal_id` (`sucursal_id`),
  CONSTRAINT `areas_ibfk_1` FOREIGN KEY (`sucursal_id`) REFERENCES `sucursales` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `areas`
--

LOCK TABLES `areas` WRITE;
/*!40000 ALTER TABLE `areas` DISABLE KEYS */;
INSERT INTO `areas` VALUES (3,1,'Area principal','2026-07-01 00:25:53','2026-07-14 16:08:59');
/*!40000 ALTER TABLE `areas` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `cajas`
--

DROP TABLE IF EXISTS `cajas`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `cajas` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `sucursal_id` int unsigned NOT NULL,
  `nombre` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT '1',
  `creado_en` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `sucursal_id` (`sucursal_id`),
  CONSTRAINT `cajas_ibfk_1` FOREIGN KEY (`sucursal_id`) REFERENCES `sucursales` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `cajas`
--

LOCK TABLES `cajas` WRITE;
/*!40000 ALTER TABLE `cajas` DISABLE KEYS */;
INSERT INTO `cajas` VALUES (1,1,'CAJA SHINAHOTA',1,'2026-07-14 16:08:59','2026-07-14 17:00:42');
/*!40000 ALTER TABLE `cajas` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `categorias`
--

DROP TABLE IF EXISTS `categorias`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `categorias` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `nombre` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `imagen` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT '1',
  `creado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `categorias`
--

LOCK TABLES `categorias` WRITE;
/*!40000 ALTER TABLE `categorias` DISABLE KEYS */;
INSERT INTO `categorias` VALUES (2,'Vinos',NULL,1,'2026-07-01 01:10:18','2026-07-13 15:53:40'),(3,'Gaseosas',NULL,1,'2026-07-01 01:10:34','2026-07-13 15:48:56'),(4,'Alimentos',NULL,1,'2026-07-12 18:52:34','2026-07-13 15:52:36'),(5,'Jugos',NULL,1,'2026-07-13 15:50:17','2026-07-13 15:50:17'),(7,'Aguas',NULL,1,'2026-07-13 15:50:40','2026-07-13 15:50:40'),(9,'Combos',NULL,1,'2026-07-13 16:48:28','2026-07-13 16:48:28'),(10,'100',NULL,1,'2026-07-13 16:48:37','2026-07-13 18:11:20'),(11,'Extras',NULL,1,'2026-07-13 17:17:40','2026-07-13 17:17:40'),(12,'Refrecos',NULL,1,'2026-07-13 19:01:19','2026-07-13 19:01:19'),(13,'Jugos Preparados',NULL,1,'2026-07-13 19:34:03','2026-07-13 19:34:03'),(14,'Cerveza',NULL,1,'2026-07-13 20:22:54','2026-07-13 20:22:54');
/*!40000 ALTER TABLE `categorias` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `clientes`
--

DROP TABLE IF EXISTS `clientes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `clientes` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `nombre` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `tipo_documento` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'CI',
  `numero_documento` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `telefono` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `direccion` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `creado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `clientes_doc_unique` (`numero_documento`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `clientes`
--

LOCK TABLES `clientes` WRITE;
/*!40000 ALTER TABLE `clientes` DISABLE KEYS */;
/*!40000 ALTER TABLE `clientes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `compras`
--

DROP TABLE IF EXISTS `compras`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `compras` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `sucursal_id` int unsigned NOT NULL,
  `proveedor_id` int unsigned NOT NULL,
  `usuario_id` int unsigned NOT NULL,
  `total` decimal(10,2) NOT NULL DEFAULT '0.00',
  `notas` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `estado` enum('pendiente','recibido') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pendiente',
  `creado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `proveedor_id` (`proveedor_id`),
  KEY `usuario_id` (`usuario_id`),
  KEY `sucursal_id` (`sucursal_id`),
  CONSTRAINT `compras_ibfk_1` FOREIGN KEY (`proveedor_id`) REFERENCES `proveedores` (`id`),
  CONSTRAINT `compras_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`),
  CONSTRAINT `compras_ibfk_3` FOREIGN KEY (`sucursal_id`) REFERENCES `sucursales` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `compras`
--

LOCK TABLES `compras` WRITE;
/*!40000 ALTER TABLE `compras` DISABLE KEYS */;
/*!40000 ALTER TABLE `compras` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `configuraciones`
--

DROP TABLE IF EXISTS `configuraciones`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `configuraciones` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `clave` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `valor` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `creado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `configuraciones_clave_unique` (`clave`)
) ENGINE=InnoDB AUTO_INCREMENT=43 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `configuraciones`
--

LOCK TABLES `configuraciones` WRITE;
/*!40000 ALTER TABLE `configuraciones` DISABLE KEYS */;
INSERT INTO `configuraciones` VALUES (1,'nombre_negocio','SAL Y BRASAS','2026-07-01 00:23:31','2026-07-15 14:55:46'),(2,'direccion','Shinahota','2026-07-01 00:23:31','2026-07-15 14:55:46'),(3,'telefono','74819122','2026-07-01 00:23:31','2026-07-15 14:55:46'),(4,'moneda','Bs','2026-07-01 00:23:31','2026-07-15 14:55:46'),(5,'simbolo_moneda','Bs.','2026-07-01 00:23:31','2026-07-15 14:55:46'),(6,'zona_horaria','America/La_Paz','2026-07-01 00:23:31','2026-07-15 14:55:46'),(7,'pie_ticket','¡Gracias por su preferencia!','2026-07-01 00:23:31','2026-07-15 14:55:46'),(8,'logo','/uploads/1783956982292-423683.png','2026-07-01 00:23:31','2026-07-15 14:55:46'),(9,'flujo_cocina','fisico','2026-07-01 00:23:31','2026-07-15 14:26:09');
/*!40000 ALTER TABLE `configuraciones` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `detalle_arqueo`
--

DROP TABLE IF EXISTS `detalle_arqueo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `detalle_arqueo` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `sesion_caja_id` int unsigned NOT NULL,
  `denominacion` decimal(10,2) NOT NULL,
  `cantidad` int NOT NULL DEFAULT '0',
  `subtotal` decimal(10,2) NOT NULL DEFAULT '0.00',
  PRIMARY KEY (`id`),
  KEY `sesion_caja_id` (`sesion_caja_id`),
  CONSTRAINT `detalle_arqueo_ibfk_1` FOREIGN KEY (`sesion_caja_id`) REFERENCES `sesiones_caja` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `detalle_arqueo`
--

LOCK TABLES `detalle_arqueo` WRITE;
/*!40000 ALTER TABLE `detalle_arqueo` DISABLE KEYS */;
-- (tabla reseteada a 0 filas)
/*!40000 ALTER TABLE `detalle_arqueo` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `detalle_compras`
--

DROP TABLE IF EXISTS `detalle_compras`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `detalle_compras` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `compra_id` int unsigned NOT NULL,
  `producto_id` int unsigned NOT NULL,
  `cantidad` int NOT NULL,
  `costo_unitario` decimal(10,2) NOT NULL,
  `subtotal` decimal(10,2) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `compra_id` (`compra_id`),
  KEY `producto_id` (`producto_id`),
  CONSTRAINT `detalle_compras_ibfk_1` FOREIGN KEY (`compra_id`) REFERENCES `compras` (`id`) ON DELETE CASCADE,
  CONSTRAINT `detalle_compras_ibfk_2` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `detalle_compras`
--

LOCK TABLES `detalle_compras` WRITE;
/*!40000 ALTER TABLE `detalle_compras` DISABLE KEYS */;
/*!40000 ALTER TABLE `detalle_compras` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `detalle_pedidos`
--

DROP TABLE IF EXISTS `detalle_pedidos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `detalle_pedidos` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `pedido_id` int unsigned NOT NULL,
  `producto_id` int unsigned NOT NULL,
  `cantidad` int NOT NULL DEFAULT '1',
  `precio` decimal(10,2) NOT NULL,
  `nota` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `estado` enum('pendiente','preparando','servido') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pendiente',
  `creado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `pedido_id` (`pedido_id`),
  KEY `producto_id` (`producto_id`),
  CONSTRAINT `detalle_pedidos_ibfk_1` FOREIGN KEY (`pedido_id`) REFERENCES `pedidos` (`id`) ON DELETE CASCADE,
  CONSTRAINT `detalle_pedidos_ibfk_2` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=737 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `detalle_pedidos`
--

LOCK TABLES `detalle_pedidos` WRITE;
/*!40000 ALTER TABLE `detalle_pedidos` DISABLE KEYS */;
-- (tabla reseteada a 0 filas)
/*!40000 ALTER TABLE `detalle_pedidos` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `gastos`
--

DROP TABLE IF EXISTS `gastos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `gastos` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `sesion_caja_id` int unsigned DEFAULT NULL,
  `usuario_id` int unsigned NOT NULL,
  `descripcion` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `monto` decimal(10,2) NOT NULL,
  `creado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `sesion_caja_id` (`sesion_caja_id`),
  KEY `usuario_id` (`usuario_id`),
  CONSTRAINT `gastos_ibfk_1` FOREIGN KEY (`sesion_caja_id`) REFERENCES `sesiones_caja` (`id`) ON DELETE SET NULL,
  CONSTRAINT `gastos_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `gastos`
--

LOCK TABLES `gastos` WRITE;
/*!40000 ALTER TABLE `gastos` DISABLE KEYS */;
/*!40000 ALTER TABLE `gastos` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `grupos_opciones`
--

DROP TABLE IF EXISTS `grupos_opciones`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `grupos_opciones` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `nombre` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `creado_en` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `grupos_opciones`
--

LOCK TABLES `grupos_opciones` WRITE;
/*!40000 ALTER TABLE `grupos_opciones` DISABLE KEYS */;
INSERT INTO `grupos_opciones` VALUES (1,'TERMINOS DE CARNE','2026-07-15 04:21:45','2026-07-15 13:01:36'),(2,'Sabores De Refresco','2026-07-15 04:22:41','2026-07-15 13:31:16'),(3,'Sobores de Fanta','2026-07-15 04:49:11','2026-07-15 13:30:21'),(4,'Sabores De Valle 1Lts','2026-07-15 13:33:14','2026-07-15 13:33:14'),(5,'Sabores de Acuarios','2026-07-15 13:34:02','2026-07-15 13:34:02'),(6,'Sabores Del Valle 2L y 3 L','2026-07-15 13:34:51','2026-07-15 13:34:51'),(7,'Sabores De Simba','2026-07-15 13:35:30','2026-07-15 13:35:30');
/*!40000 ALTER TABLE `grupos_opciones` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ingredientes_producto`
--

DROP TABLE IF EXISTS `ingredientes_producto`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ingredientes_producto` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `producto_id` int unsigned NOT NULL,
  `ingrediente_id` int unsigned NOT NULL,
  `cantidad` decimal(10,2) NOT NULL,
  `creado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `producto_id` (`producto_id`),
  KEY `ingrediente_id` (`ingrediente_id`),
  CONSTRAINT `ingredientes_producto_ibfk_1` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`id`) ON DELETE CASCADE,
  CONSTRAINT `ingredientes_producto_ibfk_2` FOREIGN KEY (`ingrediente_id`) REFERENCES `productos` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ingredientes_producto`
--

LOCK TABLES `ingredientes_producto` WRITE;
/*!40000 ALTER TABLE `ingredientes_producto` DISABLE KEYS */;
/*!40000 ALTER TABLE `ingredientes_producto` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `libro_caja`
--

DROP TABLE IF EXISTS `libro_caja`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `libro_caja` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `sesion_caja_id` int unsigned DEFAULT NULL,
  `usuario_id` int unsigned NOT NULL,
  `tipo` enum('ingreso','egreso') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `concepto` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `monto` decimal(10,2) NOT NULL,
  `metodo_pago` enum('efectivo','qr') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'efectivo',
  `referencia_id` int unsigned DEFAULT NULL,
  `creado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `sesion_caja_id` (`sesion_caja_id`),
  KEY `usuario_id` (`usuario_id`),
  CONSTRAINT `libro_caja_ibfk_1` FOREIGN KEY (`sesion_caja_id`) REFERENCES `sesiones_caja` (`id`) ON DELETE SET NULL,
  CONSTRAINT `libro_caja_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=441 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `libro_caja`
--

LOCK TABLES `libro_caja` WRITE;
/*!40000 ALTER TABLE `libro_caja` DISABLE KEYS */;
-- (tabla reseteada a 0 filas)
/*!40000 ALTER TABLE `libro_caja` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mesas`
--

DROP TABLE IF EXISTS `mesas`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `mesas` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `area_id` int unsigned NOT NULL,
  `nombre` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `asientos` int NOT NULL DEFAULT '4',
  `estado` enum('disponible','ocupada','reservada') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'disponible',
  `pos_x` int NOT NULL DEFAULT '0',
  `pos_y` int NOT NULL DEFAULT '0',
  `creado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `area_id` (`area_id`),
  CONSTRAINT `mesas_ibfk_1` FOREIGN KEY (`area_id`) REFERENCES `areas` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=122 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mesas`
--

LOCK TABLES `mesas` WRITE;
/*!40000 ALTER TABLE `mesas` DISABLE KEYS */;
INSERT INTO `mesas` VALUES (9,3,'MESA 1',4,'disponible',0,0,'2026-07-08 19:07:23','2026-07-15 16:08:32'),(10,3,'MESA 2',4,'disponible',0,0,'2026-07-10 23:02:03','2026-07-14 22:16:09'),(12,3,'MESA 3',6,'disponible',0,0,'2026-07-13 20:45:02','2026-07-15 20:14:37'),(19,3,'MESA 4',4,'disponible',0,0,'2026-07-13 20:54:29','2026-07-15 16:19:54'),(20,3,'MESA 5',4,'disponible',0,0,'2026-07-13 20:54:35','2026-07-13 20:54:35'),(21,3,'MESA 6',4,'disponible',0,0,'2026-07-13 20:54:40','2026-07-13 20:54:40'),(22,3,'MESA 7',4,'disponible',0,0,'2026-07-13 20:54:46','2026-07-13 20:54:46'),(23,3,'MESA 8',4,'disponible',0,0,'2026-07-13 20:54:51','2026-07-15 15:47:37'),(24,3,'MESA 9',4,'disponible',0,0,'2026-07-13 20:54:56','2026-07-13 20:54:56'),(26,3,'MESA 10',4,'disponible',0,0,'2026-07-13 20:55:19','2026-07-14 22:16:09'),(27,3,'MESA 11',4,'disponible',0,0,'2026-07-13 20:55:27','2026-07-14 22:16:09'),(28,3,'MESA 12',4,'disponible',0,0,'2026-07-13 20:55:34','2026-07-14 22:16:09'),(29,3,'MESA 13',4,'disponible',0,0,'2026-07-13 20:55:39','2026-07-14 22:16:09'),(30,3,'MESA 14',4,'disponible',0,0,'2026-07-13 20:55:45','2026-07-14 22:16:09'),(31,3,'MESA 15',4,'disponible',0,0,'2026-07-13 20:56:00','2026-07-14 17:48:30'),(32,3,'MESA 16',4,'disponible',0,0,'2026-07-13 20:56:07','2026-07-14 17:08:52'),(33,3,'MESA 17',4,'disponible',0,0,'2026-07-13 20:56:12','2026-07-13 20:56:12'),(34,3,'MESA 18',4,'disponible',0,0,'2026-07-13 20:56:23','2026-07-13 20:56:23'),(35,3,'MESA 19',4,'disponible',0,0,'2026-07-13 20:56:35','2026-07-14 22:16:09'),(36,3,'MESA 20',4,'disponible',0,0,'2026-07-13 20:56:59','2026-07-14 22:16:09'),(37,3,'MESA 21',4,'disponible',0,0,'2026-07-13 20:57:11','2026-07-14 22:16:09'),(38,3,'MESA 22',4,'disponible',0,0,'2026-07-13 20:57:21','2026-07-14 22:16:09'),(39,3,'MESA 23',4,'disponible',0,0,'2026-07-13 20:57:28','2026-07-14 22:16:09'),(40,3,'MESA 24',4,'disponible',0,0,'2026-07-13 20:57:33','2026-07-14 22:16:09'),(41,3,'MESA 25',4,'disponible',0,0,'2026-07-13 20:57:37','2026-07-14 22:16:09'),(42,3,'MESA 26',4,'disponible',0,0,'2026-07-13 20:57:45','2026-07-14 22:16:09'),(43,3,'MESA 27',4,'disponible',0,0,'2026-07-13 20:57:51','2026-07-15 14:52:33'),(44,3,'MESA 28',4,'disponible',0,0,'2026-07-13 20:57:56','2026-07-14 22:16:09'),(45,3,'MESA 29',4,'disponible',0,0,'2026-07-13 20:58:02','2026-07-14 22:16:09'),(46,3,'MESA 30',4,'disponible',0,0,'2026-07-13 20:58:07','2026-07-14 22:16:09'),(47,3,'MESA 31',4,'disponible',0,0,'2026-07-13 20:58:12','2026-07-14 22:16:09'),(49,3,'MESA 32',4,'disponible',0,0,'2026-07-13 20:58:23','2026-07-15 00:43:58'),(50,3,'MESA 33',4,'disponible',0,0,'2026-07-13 20:58:42','2026-07-14 22:16:09'),(51,3,'MESA 34',4,'disponible',0,0,'2026-07-13 20:58:47','2026-07-14 22:16:09'),(52,3,'MESA 35',4,'disponible',0,0,'2026-07-13 20:58:53','2026-07-14 22:16:09'),(53,3,'MESA 36',4,'disponible',0,0,'2026-07-13 20:58:59','2026-07-14 22:16:09'),(54,3,'MESA 37',4,'disponible',0,0,'2026-07-13 20:59:16','2026-07-14 22:16:09'),(55,3,'MESA 38',4,'disponible',0,0,'2026-07-13 20:59:22','2026-07-14 22:16:09'),(56,3,'MESA 39',4,'disponible',0,0,'2026-07-13 20:59:28','2026-07-14 22:16:09'),(57,3,'MESA 40',4,'disponible',0,0,'2026-07-13 20:59:33','2026-07-14 22:16:09'),(58,3,'MESA 41',4,'disponible',0,0,'2026-07-13 20:59:36','2026-07-15 01:15:30'),(59,3,'MESA 42',4,'disponible',0,0,'2026-07-13 20:59:38','2026-07-14 22:16:09'),(60,3,'MESA 43',4,'disponible',0,0,'2026-07-13 20:59:44','2026-07-14 22:16:09'),(61,3,'MESA 44',4,'disponible',0,0,'2026-07-13 20:59:45','2026-07-14 22:16:09'),(62,3,'MESA 45',4,'disponible',0,0,'2026-07-13 20:59:49','2026-07-14 22:16:09'),(63,3,'MESA 46',4,'disponible',0,0,'2026-07-13 20:59:55','2026-07-14 22:16:09'),(64,3,'MESA 47',4,'disponible',0,0,'2026-07-13 21:00:03','2026-07-14 22:16:09'),(65,3,'MESA 48',4,'disponible',0,0,'2026-07-13 21:00:10','2026-07-14 22:16:09'),(66,3,'MESA 49',4,'disponible',0,0,'2026-07-13 21:00:19','2026-07-14 22:16:09'),(67,3,'MESA 50',4,'disponible',0,0,'2026-07-13 21:00:26','2026-07-14 22:16:09'),(68,3,'MESA 51',4,'disponible',0,0,'2026-07-13 21:00:32','2026-07-14 22:16:09'),(70,3,'MESA 53',4,'disponible',0,0,'2026-07-13 21:00:51','2026-07-14 22:16:09'),(73,3,'MESA 52',4,'disponible',0,0,'2026-07-15 12:50:20','2026-07-15 12:50:20');
/*!40000 ALTER TABLE `mesas` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `opciones`
--

DROP TABLE IF EXISTS `opciones`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `opciones` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `grupo_opciones_id` int unsigned NOT NULL,
  `nombre` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `orden` int NOT NULL DEFAULT '0',
  `creado_en` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `grupo_opciones_id` (`grupo_opciones_id`),
  CONSTRAINT `opciones_ibfk_1` FOREIGN KEY (`grupo_opciones_id`) REFERENCES `grupos_opciones` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=33 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `opciones`
--

LOCK TABLES `opciones` WRITE;
/*!40000 ALTER TABLE `opciones` DISABLE KEYS */;
INSERT INTO `opciones` VALUES (9,1,'T Medio',0,'2026-07-15 13:01:36','2026-07-15 13:01:36'),(10,1,'T 3/4',1,'2026-07-15 13:01:36','2026-07-15 13:01:36'),(11,1,'T Cocido',2,'2026-07-15 13:01:36','2026-07-15 13:01:36'),(15,3,'Papaya',0,'2026-07-15 13:30:21','2026-07-15 13:30:21'),(16,3,'Mandarina',1,'2026-07-15 13:30:21','2026-07-15 13:30:21'),(17,3,'Naranja',2,'2026-07-15 13:30:21','2026-07-15 13:30:21'),(18,3,'Guarana',3,'2026-07-15 13:30:21','2026-07-15 13:30:21'),(19,2,'Copoazú',0,'2026-07-15 13:31:16','2026-07-15 13:31:16'),(20,2,'Limonada',1,'2026-07-15 13:31:16','2026-07-15 13:31:16'),(21,2,'Maracuya',2,'2026-07-15 13:31:16','2026-07-15 13:31:16'),(22,4,'Manzana',0,'2026-07-15 13:33:14','2026-07-15 13:33:14'),(23,4,'Durazno',1,'2026-07-15 13:33:14','2026-07-15 13:33:14'),(24,4,'Guayaba',2,'2026-07-15 13:33:14','2026-07-15 13:33:14'),(25,4,'Tumbo',3,'2026-07-15 13:33:14','2026-07-15 13:33:14'),(26,5,'Pera',0,'2026-07-15 13:34:02','2026-07-15 13:34:02'),(27,5,'Pomelo',1,'2026-07-15 13:34:02','2026-07-15 13:34:02'),(28,6,'Durazno',0,'2026-07-15 13:34:51','2026-07-15 13:34:51'),(29,6,'Manzana',1,'2026-07-15 13:34:51','2026-07-15 13:34:51'),(30,7,'Manzana',0,'2026-07-15 13:35:30','2026-07-15 13:35:30'),(31,7,'Piña',1,'2026-07-15 13:35:30','2026-07-15 13:35:30'),(32,7,'Durazno',2,'2026-07-15 13:35:30','2026-07-15 13:35:30');
/*!40000 ALTER TABLE `opciones` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `pagos_qr`
--

DROP TABLE IF EXISTS `pagos_qr`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `pagos_qr` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `pedido_id` int unsigned NOT NULL,
  `sucursal_id` int unsigned NOT NULL,
  `order_id` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `tx_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `estado` enum('pendiente','completado','fallido','expirado','cancelado') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pendiente',
  `estado_previo` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `moneda` varchar(3) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'BOB',
  `monto_neto` decimal(10,2) NOT NULL,
  `comision` decimal(10,2) DEFAULT NULL,
  `monto_total` decimal(10,2) DEFAULT NULL,
  `qr_code` mediumtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `expires_at` datetime NOT NULL,
  `datos_webhook` json DEFAULT NULL,
  `creado_en` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `order_id` (`order_id`),
  KEY `pedido_id` (`pedido_id`),
  KEY `sucursal_id` (`sucursal_id`),
  CONSTRAINT `pagos_qr_ibfk_1` FOREIGN KEY (`pedido_id`) REFERENCES `pedidos` (`id`),
  CONSTRAINT `pagos_qr_ibfk_2` FOREIGN KEY (`sucursal_id`) REFERENCES `sucursales` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=32 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `pagos_qr`
--

LOCK TABLES `pagos_qr` WRITE;
/*!40000 ALTER TABLE `pagos_qr` DISABLE KEYS */;
-- (tabla reseteada a 0 filas)
-- (tabla reseteada a 0 filas)
/*!40000 ALTER TABLE `pagos_qr` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `pedidos`
--

DROP TABLE IF EXISTS `pedidos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `pedidos` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `sucursal_id` int unsigned NOT NULL,
  `mesa_id` int unsigned DEFAULT NULL,
  `usuario_id` int unsigned NOT NULL,
  `cliente_id` int unsigned DEFAULT NULL,
  `sesion_caja_id` int unsigned DEFAULT NULL,
  `estado` enum('pendiente','listo','pendiente_pago','completado','cancelado') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pendiente',
  `tipo` enum('mesa','llevar') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'mesa',
  `numero_llevar` int unsigned DEFAULT NULL,
  `tipo_documento` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Ticket',
  `nombre_cliente` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Público General',
  `documento_cliente` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `total` decimal(10,2) NOT NULL DEFAULT '0.00',
  `descuento` decimal(10,2) NOT NULL DEFAULT '0.00',
  `propina` decimal(10,2) NOT NULL DEFAULT '0.00',
  `metodo_pago` enum('efectivo','qr') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'efectivo',
  `monto_recibido` decimal(10,2) DEFAULT NULL,
  `cambio` decimal(10,2) NOT NULL DEFAULT '0.00',
  `notas` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `creado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `mesa_id` (`mesa_id`),
  KEY `usuario_id` (`usuario_id`),
  KEY `cliente_id` (`cliente_id`),
  KEY `sesion_caja_id` (`sesion_caja_id`),
  KEY `sucursal_id` (`sucursal_id`),
  CONSTRAINT `pedidos_ibfk_1` FOREIGN KEY (`mesa_id`) REFERENCES `mesas` (`id`) ON DELETE SET NULL,
  CONSTRAINT `pedidos_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`),
  CONSTRAINT `pedidos_ibfk_3` FOREIGN KEY (`cliente_id`) REFERENCES `clientes` (`id`) ON DELETE SET NULL,
  CONSTRAINT `pedidos_ibfk_4` FOREIGN KEY (`sesion_caja_id`) REFERENCES `sesiones_caja` (`id`) ON DELETE SET NULL,
  CONSTRAINT `pedidos_ibfk_5` FOREIGN KEY (`sucursal_id`) REFERENCES `sucursales` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=447 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `pedidos`
--

LOCK TABLES `pedidos` WRITE;
/*!40000 ALTER TABLE `pedidos` DISABLE KEYS */;
-- (tabla reseteada a 0 filas)
/*!40000 ALTER TABLE `pedidos` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `permisos`
--

DROP TABLE IF EXISTS `permisos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `permisos` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `modulo` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `accion` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `descripcion` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `permiso_unico` (`modulo`,`accion`)
) ENGINE=InnoDB AUTO_INCREMENT=55 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `permisos`
--

LOCK TABLES `permisos` WRITE;
/*!40000 ALTER TABLE `permisos` DISABLE KEYS */;
INSERT INTO `permisos` VALUES (1,'ventas','ver','Ver pedidos'),(2,'ventas','crear','Crear pedidos'),(3,'ventas','cancelar','Cancelar pedidos'),(4,'ventas','cobrar','Cobrar pedidos'),(5,'usuarios','ver','Ver usuarios'),(6,'usuarios','crear','Crear usuarios'),(7,'usuarios','editar','Editar usuarios'),(8,'inventario','ver','Ver inventario'),(9,'usuarios','eliminar','Eliminar usuarios'),(10,'inventario','ajustar','Ajustar stock'),(11,'inventario','entrada','Registrar entrada'),(12,'inventario','salida','Registrar salida'),(13,'caja','abrir','Abrir caja'),(14,'caja','cerrar','Cerrar caja'),(15,'caja','ver','Ver sesiones de caja'),(16,'libro_caja','ver','Ver libro caja'),(17,'libro_caja','crear','Registrar en libro caja'),(18,'compras','ver','Ver compras'),(19,'compras','crear','Crear compras'),(20,'compras','recibir','Marcar compra como recibida'),(21,'compras','editar','Editar compras'),(22,'proveedores','ver','Ver proveedores'),(23,'proveedores','crear','Crear proveedores'),(24,'proveedores','editar','Editar proveedores'),(25,'productos','ver','Ver productos'),(26,'productos','crear','Crear productos'),(27,'productos','editar','Editar productos'),(28,'productos','eliminar','Eliminar productos'),(29,'clientes','ver','Ver clientes'),(30,'clientes','crear','Crear clientes'),(31,'clientes','editar','Editar clientes'),(32,'configuracion','ver','Ver configuración'),(33,'configuracion','editar','Editar configuración'),(34,'roles','ver','Ver roles'),(35,'roles','crear','Crear roles'),(36,'roles','editar','Editar roles'),(37,'roles','eliminar','Eliminar roles'),(38,'reportes','ver','Ver reportes'),(39,'cocina','ver','Ver pantalla de cocina'),(40,'sucursales','ver','Ver sucursales'),(41,'sucursales','crear','Crear sucursales'),(42,'sucursales','editar','Editar sucursales'),(43,'sucursales','eliminar','Eliminar sucursales'),(44,'cajas','ver','Ver cajas'),(45,'cajas','crear','Crear cajas'),(46,'cajas','editar','Editar cajas'),(47,'cajas','eliminar','Eliminar cajas');
/*!40000 ALTER TABLE `permisos` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `producto_stock_sucursal`
--

DROP TABLE IF EXISTS `producto_stock_sucursal`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `producto_stock_sucursal` (
  `producto_id` int unsigned NOT NULL,
  `sucursal_id` int unsigned NOT NULL,
  `stock` int NOT NULL DEFAULT '0',
  `actualizado_en` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`producto_id`,`sucursal_id`),
  KEY `sucursal_id` (`sucursal_id`),
  CONSTRAINT `producto_stock_sucursal_ibfk_1` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`id`) ON DELETE CASCADE,
  CONSTRAINT `producto_stock_sucursal_ibfk_2` FOREIGN KEY (`sucursal_id`) REFERENCES `sucursales` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `producto_stock_sucursal`
--

LOCK TABLES `producto_stock_sucursal` WRITE;
/*!40000 ALTER TABLE `producto_stock_sucursal` DISABLE KEYS */;
INSERT INTO `producto_stock_sucursal` VALUES (2,1,8,'2026-07-14 16:08:59'),(13,1,10,'2026-07-15 04:33:55'),(20,1,25,'2026-07-15 12:56:20');
/*!40000 ALTER TABLE `producto_stock_sucursal` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `productos`
--

DROP TABLE IF EXISTS `productos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `productos` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `categoria_id` int unsigned NOT NULL,
  `grupo_opciones_id` int unsigned DEFAULT NULL,
  `nombre` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `codigo_barras` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `codigo` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `precio` decimal(10,2) NOT NULL,
  `costo` decimal(10,2) DEFAULT NULL,
  `stock` int DEFAULT NULL,
  `es_vendible` tinyint(1) NOT NULL DEFAULT '1',
  `imagen` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT '1',
  `creado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `productos_barcode_unique` (`codigo_barras`),
  KEY `categoria_id` (`categoria_id`),
  KEY `grupo_opciones_id` (`grupo_opciones_id`),
  CONSTRAINT `productos_ibfk_1` FOREIGN KEY (`categoria_id`) REFERENCES `categorias` (`id`) ON DELETE CASCADE,
  CONSTRAINT `productos_ibfk_2` FOREIGN KEY (`grupo_opciones_id`) REFERENCES `grupos_opciones` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=84 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `productos`
--

LOCK TABLES `productos` WRITE;
/*!40000 ALTER TABLE `productos` DISABLE KEYS */;
INSERT INTO `productos` VALUES (1,3,NULL,'Moconchinchi',NULL,NULL,3.00,NULL,NULL,1,'/uploads/1782868253811-205432.jpg',0,'2026-07-01 01:11:15','2026-07-13 15:49:23'),(2,2,NULL,'Coca Cola',NULL,NULL,12.00,NULL,8,1,'/uploads/1783882446262-709930.png',0,'2026-07-01 14:15:01','2026-07-13 15:49:19'),(3,2,NULL,'po',NULL,NULL,15.00,NULL,NULL,1,'/uploads/1783779308620-386489.png',0,'2026-07-11 14:15:23','2026-07-13 15:49:25'),(4,4,NULL,'gibas',NULL,NULL,50.00,NULL,NULL,1,'/uploads/1783882378195-729856.png',0,'2026-07-12 18:53:54','2026-07-13 15:49:21'),(5,3,NULL,'Sprite 3Lts',NULL,NULL,24.00,NULL,NULL,1,'/uploads/1783958324362-172271.webp',1,'2026-07-13 15:59:43','2026-07-13 19:26:56'),(6,5,6,'Del Valle  2Lts',NULL,NULL,20.00,NULL,NULL,1,'/uploads/1783958274406-111922.jpg',1,'2026-07-13 16:00:18','2026-07-15 13:41:11'),(7,3,NULL,'Sprite 2Lts',NULL,NULL,20.00,NULL,NULL,1,'/uploads/1783958523741-630821.jpg',1,'2026-07-13 16:02:37','2026-07-13 19:26:47'),(8,5,6,'Del Valle 3Lts',NULL,NULL,24.00,NULL,NULL,1,'/uploads/1783958551420-421569.jpg',1,'2026-07-13 16:02:39','2026-07-15 13:41:26'),(9,3,NULL,'Sprite 1Lts',NULL,NULL,12.00,NULL,NULL,1,'/uploads/1783958695982-659216.jpg',1,'2026-07-13 16:05:25','2026-07-13 19:26:37'),(10,3,NULL,'Sprite Personal',NULL,NULL,0.00,NULL,NULL,1,'/uploads/1783958809443-982792.webp',0,'2026-07-13 16:07:13','2026-07-13 19:29:41'),(11,5,NULL,'Del Valle 300 ml',NULL,NULL,7.00,NULL,NULL,1,'/uploads/1783959047334-761142.png',1,'2026-07-13 16:10:57','2026-07-13 19:24:00'),(12,3,NULL,'Sprite  popular 600 ml',NULL,NULL,8.00,NULL,NULL,1,'/uploads/1783959960179-9252.webp',1,'2026-07-13 16:11:58','2026-07-13 19:28:25'),(13,5,4,'Del Valle 1 Ltr',NULL,NULL,15.00,NULL,10,1,'/uploads/1783959154112-306282.png',0,'2026-07-13 16:12:37','2026-07-15 13:57:17'),(14,3,NULL,'Sprite Personal 190 ml',NULL,NULL,3.00,NULL,NULL,1,'/uploads/1784055695831-942911.png',1,'2026-07-13 16:15:23','2026-07-14 19:01:42'),(15,7,NULL,'Agua 600 ml',NULL,NULL,6.00,NULL,NULL,1,'/uploads/1783959323492-684274.png',1,'2026-07-13 16:15:52','2026-07-13 19:22:06'),(16,7,NULL,'Agua 1 Ltr',NULL,NULL,8.00,NULL,NULL,1,'/uploads/1783959430168-728602.jpg',1,'2026-07-13 16:17:30','2026-07-13 19:21:16'),(17,3,NULL,'Sprite Personal',NULL,NULL,0.00,NULL,NULL,1,'/uploads/1783959426686-433760.png',0,'2026-07-13 16:17:48','2026-07-13 16:24:06'),(18,7,NULL,'Agua 2 Ltrs',NULL,NULL,10.00,NULL,NULL,1,'/uploads/1783959500367-849291.jpg',1,'2026-07-13 16:18:34','2026-07-13 19:21:34'),(19,7,NULL,'Agua 3 Ltrs',NULL,NULL,12.00,NULL,NULL,1,'/uploads/1783959701437-230513.jpg',1,'2026-07-13 16:21:49','2026-07-13 19:21:47'),(20,3,NULL,'Coca-Cola 3Lts',NULL,NULL,24.00,NULL,25,1,'/uploads/1783959701929-226427.jpg',0,'2026-07-13 16:22:10','2026-07-15 13:57:06'),(21,3,NULL,'Coca-Cola 2Lts',NULL,NULL,20.00,NULL,NULL,1,'/uploads/1783959803144-605606.jpg',1,'2026-07-13 16:23:42','2026-07-13 19:14:03'),(22,3,NULL,'Coca-Cola 1Lts',NULL,NULL,12.00,NULL,NULL,1,'/uploads/1783960141627-187137.webp',1,'2026-07-13 16:29:19','2026-07-13 19:13:46'),(23,2,NULL,'Terruño Tinto',NULL,NULL,50.00,NULL,NULL,1,'/uploads/1783967554078-221279.png',1,'2026-07-13 16:30:32','2026-07-13 18:33:14'),(24,3,NULL,'Coca-Cola Personal',NULL,NULL,0.00,NULL,NULL,1,'/uploads/1783960218120-414198.webp',0,'2026-07-13 16:30:44','2026-07-13 19:17:37'),(25,3,NULL,'Coca-Cola Popular 600ml',NULL,NULL,8.00,NULL,NULL,1,'/uploads/1783960435577-511963.webp',1,'2026-07-13 16:34:52','2026-07-13 19:19:22'),(26,3,NULL,'Coca-Cola Personal 190ml',NULL,NULL,3.00,NULL,NULL,1,'/uploads/1783960636772-271676.webp',1,'2026-07-13 16:37:36','2026-07-13 19:18:00'),(27,3,3,'Fanta 3Lts',NULL,NULL,24.00,NULL,NULL,1,'/uploads/1783961327082-177546.webp',1,'2026-07-13 16:49:04','2026-07-15 13:37:57'),(28,3,3,'Fanta  2Lts',NULL,NULL,20.00,NULL,NULL,1,'/uploads/1783961413702-818114.webp',1,'2026-07-13 16:50:31','2026-07-15 13:37:45'),(29,3,7,'Simba 2Lts',NULL,NULL,18.00,NULL,NULL,1,'/uploads/1783961765742-329615.jpg',1,'2026-07-13 16:56:23','2026-07-15 13:40:29'),(30,3,7,'Simba 3Lts',NULL,NULL,20.00,NULL,NULL,1,'/uploads/1783961926409-349143.jpg',1,'2026-07-13 16:58:59','2026-07-15 13:40:38'),(31,5,5,'Aquarios 3Lts',NULL,NULL,24.00,NULL,NULL,1,'/uploads/1783962339331-584749.webp',1,'2026-07-13 17:06:36','2026-07-15 13:39:46'),(32,4,1,'Bife Chorizo ',NULL,NULL,75.00,NULL,NULL,1,'/uploads/1783962182486-614924.jpeg',1,'2026-07-13 17:08:11','2026-07-15 13:02:02'),(33,5,5,'Aquarios 2Lts',NULL,NULL,20.00,NULL,NULL,1,'/uploads/1783962485599-180905.webp',1,'2026-07-13 17:08:40','2026-07-15 13:39:39'),(34,4,1,'Picaña',NULL,NULL,85.00,NULL,NULL,1,'/uploads/1783962594261-287767.jpeg',1,'2026-07-13 17:11:38','2026-07-15 13:02:58'),(35,4,1,'Tira De Costilla de res ',NULL,NULL,65.00,NULL,NULL,1,'/uploads/1784078419104-502301.jpeg',1,'2026-07-13 17:52:12','2026-07-15 13:03:18'),(36,4,1,'Costilla de cerdo',NULL,NULL,50.00,NULL,NULL,1,'/uploads/1784075186600-153897.jpg',1,'2026-07-13 17:57:14','2026-07-15 13:02:30'),(37,10,NULL,'Chorizo Servido',NULL,NULL,15.00,NULL,NULL,1,'/uploads/1783965858266-303871.jpg',0,'2026-07-13 18:04:26','2026-07-13 18:10:17'),(38,4,1,'Cuadril ',NULL,NULL,65.00,NULL,NULL,1,'/uploads/1783965842525-945446.png',1,'2026-07-13 18:05:07','2026-07-15 13:02:39'),(39,11,NULL,'Chorizo Aumado',NULL,NULL,10.00,NULL,NULL,1,'/uploads/1783965982235-501034.jpg',1,'2026-07-13 18:06:45','2026-07-13 18:13:17'),(40,4,1,'Colita De Cuadril',NULL,NULL,65.00,NULL,NULL,1,'/uploads/1783966030673-478086.png',1,'2026-07-13 18:08:50','2026-07-15 13:02:17'),(41,11,NULL,'Chorizo Servido',NULL,NULL,14.89,NULL,NULL,1,'/uploads/1783966295145-402999.jpg',0,'2026-07-13 18:12:09','2026-07-15 13:07:45'),(42,11,NULL,'Chorizo Criollo',NULL,NULL,10.00,NULL,NULL,1,'/uploads/1783966344976-307594.webp',1,'2026-07-13 18:12:59','2026-07-13 18:12:59'),(43,11,NULL,'Chorizo Morcilla',NULL,NULL,10.00,NULL,NULL,1,'/uploads/1784057073217-958450.png',1,'2026-07-13 18:16:00','2026-07-14 19:24:35'),(44,2,NULL,'Santa Ana',NULL,NULL,60.00,NULL,NULL,1,'/uploads/1783966406834-722681.png',1,'2026-07-13 18:16:53','2026-07-14 02:05:20'),(45,11,NULL,'Papas Fritas',NULL,NULL,10.00,NULL,NULL,1,'/uploads/1783966740026-29575.jpg',1,'2026-07-13 18:19:18','2026-07-13 18:19:18'),(46,2,NULL,'Casa Vieja Semiseco',NULL,NULL,70.00,NULL,NULL,1,'/uploads/1783966681514-134828.png',1,'2026-07-13 18:19:59','2026-07-13 18:22:31'),(47,11,NULL,'Arroz',NULL,NULL,8.00,NULL,NULL,1,'/uploads/1784053275007-315237.png',1,'2026-07-13 18:21:58','2026-07-14 18:21:18'),(48,11,NULL,'Yuca',NULL,NULL,5.00,NULL,NULL,1,'/uploads/1784057317184-564608.png',1,'2026-07-13 18:23:46','2026-07-14 19:28:37'),(49,2,NULL,'Red Blend Kohlberg',NULL,NULL,120.00,NULL,NULL,1,'/uploads/1783967101356-266350.png',1,'2026-07-13 18:25:06','2026-07-13 18:25:06'),(50,11,NULL,'Ensalada',NULL,NULL,8.00,NULL,NULL,1,'/uploads/1783967162490-402832.webp',1,'2026-07-13 18:26:08','2026-07-13 18:26:08'),(51,2,NULL,'Campos Clasico ',NULL,NULL,50.00,NULL,NULL,1,'/uploads/1783967162316-917440.png',1,'2026-07-13 18:28:11','2026-07-13 18:41:13'),(52,4,1,'Azado Americano',NULL,NULL,65.00,NULL,NULL,1,'/uploads/1784077074207-918671.jpeg',1,'2026-07-13 18:34:52','2026-07-15 13:01:57'),(53,4,1,'Pollerita',NULL,NULL,65.00,NULL,NULL,1,'/uploads/1784077347671-648381.jpeg',1,'2026-07-13 18:38:13','2026-07-15 13:03:12'),(54,10,NULL,'Casa Vieja Semidulce ',NULL,NULL,70.00,NULL,NULL,1,'/uploads/1783967725068-939691.png',0,'2026-07-13 18:39:40','2026-07-13 18:41:07'),(55,4,1,'Giba ',NULL,NULL,65.00,NULL,NULL,1,'/uploads/1783980297362-765797.png',1,'2026-07-13 18:40:21','2026-07-15 13:02:52'),(56,2,NULL,'Casa Vieja Semidulce',NULL,NULL,70.00,NULL,NULL,1,'/uploads/1783968042437-410293.png',1,'2026-07-13 18:40:58','2026-07-13 18:40:58'),(57,4,NULL,'Pollo a la Parrilla',NULL,NULL,40.00,NULL,NULL,1,'/uploads/1784054871946-256185.png',1,'2026-07-13 18:42:50','2026-07-14 18:47:56'),(58,4,NULL,'Hamburguesa Gruesa',NULL,NULL,35.00,NULL,NULL,1,'/uploads/1784054184854-815448.jpg',1,'2026-07-13 18:43:48','2026-07-14 18:36:32'),(59,2,NULL,'Casa Vieja Oporto',NULL,NULL,80.00,NULL,NULL,1,'/uploads/1783968253212-669123.png',1,'2026-07-13 18:44:17','2026-07-13 18:44:31'),(60,9,NULL,'Combo Parrilla',NULL,NULL,300.00,NULL,NULL,1,'/uploads/1784053042324-268406.jpeg',1,'2026-07-13 18:45:28','2026-07-14 18:17:24'),(61,2,NULL,'Campos Oporto',NULL,NULL,80.00,NULL,NULL,1,'/uploads/1783968398679-915388.png',1,'2026-07-13 18:47:46','2026-07-13 18:47:46'),(62,2,NULL,'Blend Kohlberg ',NULL,NULL,120.00,NULL,NULL,1,'/uploads/1783970425766-201206.png',1,'2026-07-13 19:20:31','2026-07-13 19:20:55'),(63,2,NULL,'Kohlberg Fundador',NULL,NULL,80.00,NULL,NULL,1,'/uploads/1783970843133-182480.png',1,'2026-07-13 19:27:34','2026-07-13 19:27:34'),(64,13,NULL,'Copoazu',NULL,NULL,25.00,NULL,NULL,1,'/uploads/1783971680474-366640.jpeg',1,'2026-07-13 19:34:50','2026-07-13 19:41:26'),(65,2,NULL,'Duo Bonarda ',NULL,NULL,100.00,NULL,NULL,1,'/uploads/1783971668146-6516.png',1,'2026-07-13 19:37:38','2026-07-13 20:34:40'),(66,2,NULL,'Duo Tannat Merlot',NULL,NULL,100.00,NULL,NULL,1,'/uploads/1783971866393-456363.png',1,'2026-07-13 19:44:46','2026-07-13 20:34:50'),(67,13,NULL,'Maracuya',NULL,NULL,25.00,NULL,NULL,1,'/uploads/1783971897602-801777.jpg',1,'2026-07-13 19:45:25','2026-07-13 19:45:25'),(68,13,NULL,'Piña',NULL,NULL,25.00,NULL,NULL,1,'/uploads/1783972105877-785905.jpg',1,'2026-07-13 19:49:52','2026-07-13 19:50:29'),(69,12,2,'Vaso',NULL,NULL,3.00,NULL,NULL,1,'/uploads/1784053901025-228027.png',1,'2026-07-13 19:57:02','2026-07-15 04:23:40'),(70,12,2,'Jarra 1Lts',NULL,NULL,8.00,NULL,NULL,1,'/uploads/1784053766781-804409.png',1,'2026-07-13 20:03:17','2026-07-15 04:23:22'),(71,12,2,'Jarra 2Lts',NULL,NULL,15.00,NULL,NULL,1,'/uploads/1784054510596-165695.jpeg',1,'2026-07-13 20:06:00','2026-07-15 04:23:31'),(72,14,NULL,'Corona',NULL,NULL,20.00,NULL,NULL,1,'/uploads/1783974251242-743682.webp',1,'2026-07-13 20:24:44','2026-07-13 20:39:43'),(73,14,NULL,'Huari',NULL,NULL,20.00,NULL,NULL,1,'/uploads/1783974398024-726491.webp',1,'2026-07-13 20:26:55','2026-07-13 20:39:49'),(74,14,NULL,'Burguesa',NULL,NULL,20.00,NULL,NULL,1,'/uploads/1783974463885-266938.png',1,'2026-07-13 20:27:58','2026-07-13 20:39:38'),(75,4,NULL,'Chorizo Servido',NULL,NULL,15.00,NULL,NULL,1,'/uploads/1784053545604-311701.jpeg',1,'2026-07-14 18:25:49','2026-07-14 18:25:49'),(76,3,3,'Fanta Personal 190 ml',NULL,NULL,3.00,NULL,NULL,1,'/uploads/1784055317160-672959.webp',1,'2026-07-14 18:55:27','2026-07-15 13:38:05'),(77,3,3,'Fanta Popular 600 ml ',NULL,NULL,8.00,NULL,NULL,1,'/uploads/1784055561464-424760.png',1,'2026-07-14 18:59:32','2026-07-15 13:38:17'),(78,10,NULL,'1',NULL,NULL,1.00,NULL,0,1,NULL,0,'2026-07-15 00:25:29','2026-07-15 04:02:51'),(79,10,NULL,'1',NULL,NULL,1.00,NULL,1,1,NULL,0,'2026-07-15 03:54:07','2026-07-15 04:02:46'),(80,10,NULL,'1',NULL,NULL,1.00,NULL,NULL,1,NULL,0,'2026-07-15 11:32:28','2026-07-16 11:45:26'),(81,9,NULL,'Plato Expo Toro',NULL,NULL,75.00,NULL,NULL,1,'/uploads/1784304996704-312090.jpeg',1,'2026-07-15 13:26:01','2026-07-17 16:17:13'),(82,3,NULL,'Coca - Cola 3 Ltrs',NULL,NULL,25.00,NULL,NULL,1,'/uploads/1784123880550-205460.jpg',1,'2026-07-15 14:00:03','2026-07-15 20:31:10'),(83,5,4,'Del Valle 1 Ltr',NULL,NULL,15.00,NULL,NULL,1,'/uploads/1784124085391-757681.jpg',1,'2026-07-15 14:01:51','2026-07-15 20:31:30');
/*!40000 ALTER TABLE `productos` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `proveedores`
--

DROP TABLE IF EXISTS `proveedores`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `proveedores` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `nombre` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `contacto` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `telefono` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `direccion` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT '1',
  `creado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `proveedores`
--

LOCK TABLES `proveedores` WRITE;
/*!40000 ALTER TABLE `proveedores` DISABLE KEYS */;
INSERT INTO `proveedores` VALUES (1,'Coca cola agencia 1','Juan','65484544','','chimoré',1,'2026-07-15 04:39:46','2026-07-15 04:39:46');
/*!40000 ALTER TABLE `proveedores` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `registros_inventario`
--

DROP TABLE IF EXISTS `registros_inventario`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `registros_inventario` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `producto_id` int unsigned NOT NULL,
  `sucursal_id` int unsigned NOT NULL,
  `usuario_id` int unsigned NOT NULL,
  `tipo` enum('entrada','salida','venta','compra','ajuste') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `cantidad` int NOT NULL,
  `stock_anterior` int DEFAULT NULL,
  `stock_nuevo` int DEFAULT NULL,
  `nota` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `creado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `producto_id` (`producto_id`),
  KEY `usuario_id` (`usuario_id`),
  KEY `sucursal_id` (`sucursal_id`),
  CONSTRAINT `registros_inventario_ibfk_1` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`id`) ON DELETE CASCADE,
  CONSTRAINT `registros_inventario_ibfk_2` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`),
  CONSTRAINT `registros_inventario_ibfk_3` FOREIGN KEY (`sucursal_id`) REFERENCES `sucursales` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `registros_inventario`
--

LOCK TABLES `registros_inventario` WRITE;
/*!40000 ALTER TABLE `registros_inventario` DISABLE KEYS */;
/*!40000 ALTER TABLE `registros_inventario` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `reservaciones`
--

DROP TABLE IF EXISTS `reservaciones`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reservaciones` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `nombre_cliente` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `telefono` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `hora_reserva` datetime NOT NULL,
  `personas` int NOT NULL,
  `mesa_id` int unsigned DEFAULT NULL,
  `nota` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `estado` enum('pendiente','confirmada','cancelada') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pendiente',
  `creado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `mesa_id` (`mesa_id`),
  CONSTRAINT `reservaciones_ibfk_1` FOREIGN KEY (`mesa_id`) REFERENCES `mesas` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `reservaciones`
--

LOCK TABLES `reservaciones` WRITE;
/*!40000 ALTER TABLE `reservaciones` DISABLE KEYS */;
/*!40000 ALTER TABLE `reservaciones` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `roles`
--

DROP TABLE IF EXISTS `roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `roles` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `nombre` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `descripcion` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `creado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `roles`
--

LOCK TABLES `roles` WRITE;
/*!40000 ALTER TABLE `roles` DISABLE KEYS */;
INSERT INTO `roles` VALUES (1,'Administrador','Acceso total al sistema','2026-07-01 00:23:31','2026-07-01 00:23:31'),(2,'Cajero','Ventas, caja, clientes y libro caja','2026-07-01 00:23:31','2026-07-01 00:23:31'),(3,'Mesero','Toma de pedidos y vista de mesas','2026-07-01 00:23:31','2026-07-01 00:23:31'),(4,'Cocina','Pantalla de cocina — ver y marcar pedidos','2026-07-01 00:23:31','2026-07-01 00:23:31');
/*!40000 ALTER TABLE `roles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `roles_permisos`
--

DROP TABLE IF EXISTS `roles_permisos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `roles_permisos` (
  `rol_id` int unsigned NOT NULL,
  `permiso_id` int unsigned NOT NULL,
  PRIMARY KEY (`rol_id`,`permiso_id`),
  KEY `permiso_id` (`permiso_id`),
  CONSTRAINT `roles_permisos_ibfk_1` FOREIGN KEY (`rol_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE,
  CONSTRAINT `roles_permisos_ibfk_2` FOREIGN KEY (`permiso_id`) REFERENCES `permisos` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `roles_permisos`
--

LOCK TABLES `roles_permisos` WRITE;
/*!40000 ALTER TABLE `roles_permisos` DISABLE KEYS */;
INSERT INTO `roles_permisos` VALUES (1,1),(2,1),(3,1),(1,2),(2,2),(3,2),(1,3),(2,3),(1,4),(2,4),(1,5),(1,6),(1,7),(1,8),(2,8),(1,9),(1,10),(1,11),(1,12),(1,13),(2,13),(1,14),(2,14),(1,15),(2,15),(1,16),(2,16),(1,17),(2,17),(1,18),(1,19),(1,20),(1,21),(1,22),(1,23),(1,24),(1,25),(2,25),(1,26),(2,26),(1,27),(2,27),(1,28),(2,28),(1,29),(2,29),(1,30),(2,30),(1,31),(2,31),(1,32),(1,33),(1,34),(1,35),(1,36),(1,37),(1,38),(3,39),(4,39),(1,40),(1,41),(1,42),(1,43),(1,44),(1,45),(1,46),(1,47);
/*!40000 ALTER TABLE `roles_permisos` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `sesiones_caja`
--

DROP TABLE IF EXISTS `sesiones_caja`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sesiones_caja` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `usuario_id` int unsigned NOT NULL,
  `sucursal_id` int unsigned NOT NULL,
  `caja_id` int unsigned NOT NULL,
  `monto_apertura` decimal(10,2) NOT NULL DEFAULT '0.00',
  `monto_cierre` decimal(10,2) DEFAULT NULL,
  `total_ventas` decimal(10,2) NOT NULL DEFAULT '0.00',
  `total_gastos` decimal(10,2) NOT NULL DEFAULT '0.00',
  `diferencia` decimal(10,2) DEFAULT NULL,
  `abierto_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `cerrado_en` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `estado` enum('abierta','cerrada') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'abierta',
  PRIMARY KEY (`id`),
  KEY `usuario_id` (`usuario_id`),
  KEY `sucursal_id` (`sucursal_id`),
  KEY `caja_id` (`caja_id`),
  CONSTRAINT `sesiones_caja_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`),
  CONSTRAINT `sesiones_caja_ibfk_2` FOREIGN KEY (`sucursal_id`) REFERENCES `sucursales` (`id`),
  CONSTRAINT `sesiones_caja_ibfk_3` FOREIGN KEY (`caja_id`) REFERENCES `cajas` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `sesiones_caja`
--

LOCK TABLES `sesiones_caja` WRITE;
/*!40000 ALTER TABLE `sesiones_caja` DISABLE KEYS */;
-- (tabla reseteada a 0 filas)
/*!40000 ALTER TABLE `sesiones_caja` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `sucursales`
--

DROP TABLE IF EXISTS `sucursales`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sucursales` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `nombre` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `direccion` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `telefono` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT '1',
  `creado_en` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `sucursales`
--

LOCK TABLES `sucursales` WRITE;
/*!40000 ALTER TABLE `sucursales` DISABLE KEYS */;
INSERT INTO `sucursales` VALUES (1,'SHINAHOTA','Av. Peru','74819122',1,'2026-07-14 16:08:59','2026-07-14 16:08:59');
/*!40000 ALTER TABLE `sucursales` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `usuarios`
--

DROP TABLE IF EXISTS `usuarios`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `usuarios` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `rol_id` int unsigned NOT NULL,
  `acceso_todas_sucursales` tinyint(1) NOT NULL DEFAULT '0',
  `nombre` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `contrasena` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT '1',
  `token_recordar` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `creado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `usuarios_email_unique` (`email`),
  KEY `rol_id` (`rol_id`),
  CONSTRAINT `usuarios_ibfk_1` FOREIGN KEY (`rol_id`) REFERENCES `roles` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `usuarios`
--

LOCK TABLES `usuarios` WRITE;
/*!40000 ALTER TABLE `usuarios` DISABLE KEYS */;
INSERT INTO `usuarios` VALUES (1,1,1,'Administrador','admin@salybrasas.com','$2b$10$tvvijjWvfNhTOXiCbqrmQ.dSrVOBvmNn8hVmLM.hiAiYMTePWEVmK',1,NULL,'2026-07-01 00:23:31','2026-07-20 03:30:13');
/*!40000 ALTER TABLE `usuarios` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `usuarios_sucursales`
--

DROP TABLE IF EXISTS `usuarios_sucursales`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `usuarios_sucursales` (
  `usuario_id` int unsigned NOT NULL,
  `sucursal_id` int unsigned NOT NULL,
  PRIMARY KEY (`usuario_id`,`sucursal_id`),
  KEY `sucursal_id` (`sucursal_id`),
  CONSTRAINT `usuarios_sucursales_ibfk_1` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`) ON DELETE CASCADE,
  CONSTRAINT `usuarios_sucursales_ibfk_2` FOREIGN KEY (`sucursal_id`) REFERENCES `sucursales` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `usuarios_sucursales`
--

LOCK TABLES `usuarios_sucursales` WRITE;
/*!40000 ALTER TABLE `usuarios_sucursales` DISABLE KEYS */;
INSERT INTO `usuarios_sucursales` VALUES (1,1);
/*!40000 ALTER TABLE `usuarios_sucursales` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-07-20 13:01:56
