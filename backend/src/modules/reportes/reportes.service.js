const { Op } = require('sequelize');
const {
  Pedido, DetallePedido, Mesa, Cliente, Producto, Usuario,
  RegistroInventario, Compra, Proveedor, LibroCaja,
} = require('../../models');

function filtroFecha(desde, hasta) {
  if (!desde && !hasta) return {};
  const range = {};
  if (desde) range[Op.gte] = new Date(desde + 'T00:00:00');
  if (hasta) range[Op.lte] = new Date(hasta + 'T23:59:59');
  return { creado_en: range };
}

async function ventas({ desde, hasta } = {}) {
  return Pedido.findAll({
    where: { estado: 'completado', ...filtroFecha(desde, hasta) },
    include: [
      { model: Mesa,    as: 'mesa',    attributes: ['id', 'nombre'] },
      { model: Cliente, as: 'cliente', attributes: ['id', 'nombre'] },
      { model: Usuario, as: 'usuario', attributes: ['id', 'nombre'] },
      {
        model: DetallePedido, as: 'detalles',
        include: [{ model: Producto, as: 'producto', attributes: ['id', 'nombre'] }],
      },
    ],
    order: [['creado_en', 'DESC']],
  });
}

async function inventario({ desde, hasta } = {}) {
  return RegistroInventario.findAll({
    where: filtroFecha(desde, hasta),
    include: [
      { model: Producto, as: 'producto', attributes: ['id', 'nombre', 'stock'] },
      { model: Usuario,  as: 'usuario',  attributes: ['id', 'nombre'] },
    ],
    order: [['creado_en', 'DESC']],
  });
}

async function compras({ desde, hasta } = {}) {
  return Compra.findAll({
    where: filtroFecha(desde, hasta),
    include: [
      { model: Proveedor, as: 'proveedor', attributes: ['id', 'nombre'] },
      { model: Usuario,   as: 'usuario',   attributes: ['id', 'nombre'] },
    ],
    order: [['creado_en', 'DESC']],
  });
}

async function caja({ desde, hasta } = {}) {
  return LibroCaja.findAll({
    where: filtroFecha(desde, hasta),
    include: [
      { model: Usuario, as: 'usuario', attributes: ['id', 'nombre'] },
    ],
    order: [['creado_en', 'DESC']],
  });
}

module.exports = { ventas, inventario, compras, caja };
