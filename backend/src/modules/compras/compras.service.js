const { Proveedor, Compra, DetalleCompra, Producto, RegistroInventario, sequelize } = require('../../models');

const INCLUDE_COMPRA = [
  { model: Proveedor, as: 'proveedor', attributes: ['id', 'nombre'] },
  {
    model: DetalleCompra, as: 'detalles',
    include: [{ model: Producto, as: 'producto', attributes: ['id', 'nombre', 'stock'] }],
  },
];

// --- Proveedores ---

async function listarProveedores() {
  return Proveedor.findAll({ where: { activo: 1 }, order: [['nombre', 'ASC']] });
}

async function crearProveedor({ nombre, contacto, telefono, email, direccion }) {
  return Proveedor.create({ nombre, contacto, telefono, email, direccion });
}

async function actualizarProveedor(id, datos) {
  const p = await Proveedor.findByPk(id);
  if (!p) throw Object.assign(new Error('Proveedor no encontrado'), { status: 404 });
  await p.update(datos);
  return p;
}

async function desactivarProveedor(id) {
  const p = await Proveedor.findByPk(id);
  if (!p) throw Object.assign(new Error('Proveedor no encontrado'), { status: 404 });
  await p.update({ activo: 0 });
}

// --- Compras ---

async function listarCompras() {
  return Compra.findAll({ include: INCLUDE_COMPRA, order: [['creado_en', 'DESC']] });
}

async function obtenerCompra(id) {
  const c = await Compra.findByPk(id, { include: INCLUDE_COMPRA });
  if (!c) throw Object.assign(new Error('Compra no encontrada'), { status: 404 });
  return c;
}

async function crearCompra(usuario_id, { proveedor_id, notas, items = [] }) {
  const proveedor = await Proveedor.findByPk(proveedor_id);
  if (!proveedor) throw Object.assign(new Error('Proveedor no encontrado'), { status: 404 });

  const total = items.reduce((sum, i) => sum + (parseFloat(i.costo_unitario) * parseInt(i.cantidad)), 0);

  const compra = await Compra.create({ proveedor_id, usuario_id, total, notas });

  await DetalleCompra.bulkCreate(
    items.map(i => ({
      compra_id: compra.id,
      producto_id: i.producto_id,
      cantidad: i.cantidad,
      costo_unitario: i.costo_unitario,
      subtotal: parseFloat(i.costo_unitario) * parseInt(i.cantidad),
    }))
  );

  return obtenerCompra(compra.id);
}

async function actualizarCompra(id, { notas }) {
  const c = await Compra.findByPk(id);
  if (!c) throw Object.assign(new Error('Compra no encontrada'), { status: 404 });
  if (c.estado !== 'pendiente') throw Object.assign(new Error('Solo se pueden editar compras pendientes'), { status: 409 });
  await c.update({ notas });
  return obtenerCompra(id);
}

async function recibirCompra(id, usuario_id) {
  const compra = await Compra.findByPk(id, { include: INCLUDE_COMPRA });
  if (!compra) throw Object.assign(new Error('Compra no encontrada'), { status: 404 });
  if (compra.estado !== 'pendiente') throw Object.assign(new Error('La compra ya fue recibida'), { status: 409 });

  await sequelize.transaction(async (t) => {
    for (const detalle of compra.detalles) {
      const producto = await Producto.findByPk(detalle.producto_id, { transaction: t });
      const stock_anterior = producto ? producto.stock : 0;
      await Producto.increment('stock', { by: detalle.cantidad, where: { id: detalle.producto_id }, transaction: t });
      await RegistroInventario.create({
        producto_id: detalle.producto_id,
        usuario_id,
        tipo: 'compra',
        cantidad: detalle.cantidad,
        stock_anterior,
        stock_nuevo: stock_anterior + detalle.cantidad,
        nota: `Compra #${compra.id}`,
      }, { transaction: t });
    }
    await compra.update({ estado: 'recibido' }, { transaction: t });
  });

  return obtenerCompra(id);
}

module.exports = { listarProveedores, crearProveedor, actualizarProveedor, desactivarProveedor, listarCompras, obtenerCompra, crearCompra, actualizarCompra, recibirCompra };
