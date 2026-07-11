const { Categoria, Producto } = require('../../models');
const sequelize = require('../../config/database');

// --- Categorías ---

async function listarCategorias() {
  return Categoria.findAll({ order: [['nombre', 'ASC']] });
}

async function crearCategoria({ nombre, imagen }) {
  return Categoria.create({ nombre, imagen });
}

async function actualizarCategoria(id, { nombre, imagen, activo }) {
  const cat = await Categoria.findByPk(id);
  if (!cat) throw Object.assign(new Error('Categoría no encontrada'), { status: 404 });
  await cat.update({ nombre, imagen, activo });
  return cat;
}

async function eliminarCategoria(id) {
  const cat = await Categoria.findByPk(id);
  if (!cat) throw Object.assign(new Error('Categoría no encontrada'), { status: 404 });
  const productos = await Producto.count({ where: { categoria_id: id } });
  if (productos > 0) throw Object.assign(new Error('La categoría tiene productos asignados'), { status: 409 });
  await cat.destroy();
}

// --- Productos ---

async function listarProductos({ categoria_id, solo_vendibles, order_by } = {}) {
  const where = { activo: 1 };
  if (categoria_id) where.categoria_id = categoria_id;
  if (solo_vendibles === 'true' || solo_vendibles === true) where.es_vendible = 1;

  const order = order_by === 'mas_vendido'
    ? [
        [sequelize.literal('(SELECT COALESCE(SUM(cantidad), 0) FROM detalle_pedidos WHERE producto_id = `Producto`.`id`)'), 'DESC'],
        ['nombre', 'ASC'],
      ]
    : [['nombre', 'ASC']];

  return Producto.findAll({
    where,
    include: [{ model: Categoria, as: 'categoria', attributes: ['id', 'nombre'] }],
    order,
  });
}

async function obtenerProducto(id) {
  const p = await Producto.findByPk(id, {
    include: [{ model: Categoria, as: 'categoria', attributes: ['id', 'nombre'] }],
  });
  if (!p) throw Object.assign(new Error('Producto no encontrado'), { status: 404 });
  return p;
}

async function crearProducto({ categoria_id, nombre, codigo_barras, codigo, precio, costo, stock, es_vendible, imagen }) {
  return Producto.create({ categoria_id, nombre, codigo_barras, codigo, precio, costo, stock, es_vendible, imagen });
}

async function actualizarProducto(id, datos) {
  const p = await Producto.findByPk(id);
  if (!p) throw Object.assign(new Error('Producto no encontrado'), { status: 404 });
  await p.update(datos);
  return obtenerProducto(id);
}

async function eliminarProducto(id) {
  const p = await Producto.findByPk(id);
  if (!p) throw Object.assign(new Error('Producto no encontrado'), { status: 404 });
  await p.update({ activo: 0 });
}

module.exports = { listarCategorias, crearCategoria, actualizarCategoria, eliminarCategoria, listarProductos, obtenerProducto, crearProducto, actualizarProducto, eliminarProducto };
