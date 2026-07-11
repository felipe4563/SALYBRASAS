const { RegistroInventario, Producto, Usuario } = require('../../models');

const INCLUDE_REGISTRO = [
  { model: Producto, as: 'producto', attributes: ['id', 'nombre', 'stock'] },
  { model: Usuario, as: 'usuario', attributes: ['id', 'nombre'] },
];

async function listar({ producto_id } = {}) {
  const where = {};
  if (producto_id) where.producto_id = producto_id;
  return RegistroInventario.findAll({ where, include: INCLUDE_REGISTRO, order: [['creado_en', 'DESC']], limit: 200 });
}

async function listarPorProducto(producto_id) {
  const producto = await Producto.findByPk(producto_id);
  if (!producto) throw Object.assign(new Error('Producto no encontrado'), { status: 404 });
  return RegistroInventario.findAll({
    where: { producto_id },
    include: INCLUDE_REGISTRO,
    order: [['creado_en', 'DESC']],
  });
}

async function _movimiento(usuario_id, producto_id, tipo, cantidad, nota) {
  const producto = await Producto.findByPk(producto_id);
  if (!producto) throw Object.assign(new Error('Producto no encontrado'), { status: 404 });

  const stock_anterior = producto.stock || 0;
  let stock_nuevo;

  if (tipo === 'entrada' || tipo === 'compra') {
    stock_nuevo = stock_anterior + cantidad;
  } else if (tipo === 'salida' || tipo === 'venta') {
    if (stock_anterior < cantidad) throw Object.assign(new Error('Stock insuficiente'), { status: 409 });
    stock_nuevo = stock_anterior - cantidad;
  } else if (tipo === 'ajuste') {
    stock_nuevo = cantidad; // ajuste fija el valor absoluto
  }

  await Producto.update({ stock: stock_nuevo }, { where: { id: producto_id } });

  return RegistroInventario.create({ producto_id, usuario_id, tipo, cantidad, stock_anterior, stock_nuevo, nota });
}

async function entrada(usuario_id, { producto_id, cantidad, nota }) {
  return _movimiento(usuario_id, producto_id, 'entrada', cantidad, nota);
}

async function salida(usuario_id, { producto_id, cantidad, nota }) {
  return _movimiento(usuario_id, producto_id, 'salida', cantidad, nota);
}

async function ajuste(usuario_id, { producto_id, cantidad, nota }) {
  return _movimiento(usuario_id, producto_id, 'ajuste', cantidad, nota);
}

module.exports = { listar, listarPorProducto, entrada, salida, ajuste };
