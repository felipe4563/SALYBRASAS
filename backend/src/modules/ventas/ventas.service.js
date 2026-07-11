const { Op } = require('sequelize');
const { Pedido, DetallePedido, Mesa, Producto, Cliente, SesionCaja, LibroCaja, RegistroInventario, Configuracion, sequelize } = require('../../models');
const { emitir } = require('../../socket');

const INCLUDE_PEDIDO_COMPLETO = [
  { model: Mesa, as: 'mesa', attributes: ['id', 'nombre', 'estado'] },
  { model: Cliente, as: 'cliente', attributes: ['id', 'nombre', 'numero_documento'] },
  {
    model: DetallePedido, as: 'detalles',
    include: [{ model: Producto, as: 'producto', attributes: ['id', 'nombre', 'precio'] }],
  },
];

async function listar({ estado, mesa_id } = {}) {
  const where = {};
  if (estado) {
    where.estado = estado.includes(',') ? { [Op.in]: estado.split(',') } : estado;
  }
  if (mesa_id) where.mesa_id = mesa_id;
  return Pedido.findAll({ where, include: INCLUDE_PEDIDO_COMPLETO, order: [['creado_en', 'DESC']] });
}

async function listarCocina() {
  return Pedido.findAll({
    where: { estado: { [Op.in]: ['pendiente', 'listo'] } },
    include: INCLUDE_PEDIDO_COMPLETO,
    order: [['creado_en', 'ASC']],
  });
}

async function obtener(id) {
  const p = await Pedido.findByPk(id, { include: INCLUDE_PEDIDO_COMPLETO });
  if (!p) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  return p;
}

async function _siguienteNumeroLlevar() {
  const inicio = new Date();
  inicio.setHours(0, 0, 0, 0);
  const fin = new Date();
  fin.setHours(23, 59, 59, 999);
  const count = await Pedido.count({
    where: {
      tipo: 'llevar',
      creado_en: { [Op.between]: [inicio, fin] },
    },
  });
  return count + 1;
}

async function crear({ mesa_id, tipo = 'mesa', usuario_id, cliente_id, sesion_caja_id, notas, nombre_cliente, documento_cliente, tipo_documento }) {
  if (!sesion_caja_id) {
    throw Object.assign(new Error('No hay caja abierta. Abre la caja antes de crear una orden.'), { status: 409 });
  }
  const sesionActiva = await SesionCaja.findByPk(sesion_caja_id);
  if (!sesionActiva || sesionActiva.estado !== 'abierta') {
    throw Object.assign(new Error('La sesión de caja no está abierta.'), { status: 409 });
  }

  if (tipo === 'mesa') {
    const mesa = await Mesa.findByPk(mesa_id);
    if (!mesa) throw Object.assign(new Error('Mesa no encontrada'), { status: 404 });

    const pedido = await Pedido.create({
      mesa_id,
      tipo: 'mesa',
      usuario_id,
      cliente_id,
      sesion_caja_id,
      notas,
      nombre_cliente: nombre_cliente || 'Público General',
      documento_cliente,
      tipo_documento: tipo_documento || 'Ticket',
    });
    await mesa.update({ estado: 'ocupada' });
    const resultado = await obtener(pedido.id);
    emitir('restaurante:actualizar', { tipo: 'pedido_nuevo' });
    return resultado;
  }

  // tipo === 'llevar'
  const numero_llevar = await _siguienteNumeroLlevar();
  const pedido = await Pedido.create({
    mesa_id: null,
    tipo: 'llevar',
    numero_llevar,
    usuario_id,
    cliente_id,
    sesion_caja_id,
    notas,
    nombre_cliente: nombre_cliente || 'Cliente',
    documento_cliente,
    tipo_documento: tipo_documento || 'Ticket',
  });
  const resultado = await obtener(pedido.id);
  emitir('restaurante:actualizar', { tipo: 'pedido_nuevo' });
  return resultado;
}

async function crearCompleta({ tipo, mesa_id, nombre_cliente, documento_cliente, tipo_documento, items, metodo_pago, monto_recibido, descuento = 0, propina = 0, sesion_caja_id, usuario_id }) {
  if (!sesion_caja_id) {
    throw Object.assign(new Error('No hay caja abierta. Abre la caja antes de crear una orden.'), { status: 409 });
  }
  const sesionActiva = await SesionCaja.findByPk(sesion_caja_id);
  if (!sesionActiva || sesionActiva.estado !== 'abierta') {
    throw Object.assign(new Error('La sesión de caja no está abierta.'), { status: 409 });
  }

  if (!items || items.length === 0) {
    throw Object.assign(new Error('El pedido no tiene productos'), { status: 409 });
  }

  const productos = [];
  for (const item of items) {
    const producto = await Producto.findByPk(item.producto_id);
    if (!producto) throw Object.assign(new Error('Producto no encontrado'), { status: 404 });
    if (!producto.activo || !producto.es_vendible) throw Object.assign(new Error('Producto no disponible'), { status: 409 });
    if (producto.stock !== null && producto.stock < item.cantidad) {
      throw Object.assign(new Error(`Stock insuficiente: ${producto.nombre}`), { status: 409 });
    }
    productos.push({ item, producto });
  }

  let mesa = null;
  if (tipo === 'mesa') {
    if (!mesa_id) throw Object.assign(new Error('mesa_id es requerido'), { status: 400 });
    mesa = await Mesa.findByPk(mesa_id);
    if (!mesa) throw Object.assign(new Error('Mesa no encontrada'), { status: 404 });
    if (mesa.estado !== 'disponible') throw Object.assign(new Error('Mesa ya ocupada'), { status: 409 });
  } else if (tipo !== 'llevar') {
    throw Object.assign(new Error("tipo debe ser 'mesa' o 'llevar'"), { status: 400 });
  }

  const total = productos.reduce((sum, { item, producto }) => sum + item.cantidad * parseFloat(producto.precio), 0);
  const monto_neto = total - parseFloat(descuento) + parseFloat(propina);

  if (metodo_pago === 'efectivo') {
    if (!monto_recibido || parseFloat(monto_recibido) < monto_neto) {
      throw Object.assign(new Error('Monto recibido insuficiente'), { status: 400 });
    }
  }
  const cambio = metodo_pago === 'efectivo' ? parseFloat(monto_recibido) - monto_neto : 0;

  const numero_llevar = tipo === 'llevar' ? await _siguienteNumeroLlevar() : null;

  const pedidoId = await sequelize.transaction(async (t) => {
    const pedido = await Pedido.create({
      mesa_id: tipo === 'mesa' ? mesa_id : null,
      tipo,
      numero_llevar,
      usuario_id,
      sesion_caja_id,
      estado: 'completado',
      total,
      descuento,
      propina,
      metodo_pago,
      monto_recibido: monto_recibido || monto_neto,
      cambio,
      nombre_cliente: nombre_cliente || (tipo === 'llevar' ? 'Cliente' : 'Público General'),
      documento_cliente,
      tipo_documento: tipo_documento || 'Ticket',
    }, { transaction: t });

    for (const { item, producto } of productos) {
      await DetallePedido.create({
        pedido_id: pedido.id,
        producto_id: item.producto_id,
        cantidad: item.cantidad,
        precio: producto.precio,
        nota: item.nota,
      }, { transaction: t });

      if (producto.stock !== null) {
        const stock_anterior = producto.stock;
        const stock_nuevo = stock_anterior - item.cantidad;
        await producto.update({ stock: stock_nuevo }, { transaction: t });
        await RegistroInventario.create({
          producto_id: item.producto_id,
          usuario_id,
          tipo: 'venta',
          cantidad: item.cantidad,
          stock_anterior,
          stock_nuevo,
          nota: `Venta #${pedido.id}`,
        }, { transaction: t });
      }
    }

    await LibroCaja.create({
      sesion_caja_id,
      usuario_id,
      tipo: 'ingreso',
      concepto: `Venta #${pedido.id}`,
      monto: monto_neto,
      metodo_pago,
      referencia_id: pedido.id,
    }, { transaction: t });

    await SesionCaja.increment('total_ventas', { by: monto_neto, where: { id: sesion_caja_id }, transaction: t });

    return pedido.id;
  });

  const creado = await obtener(pedidoId);
  emitir('restaurante:actualizar', { tipo: 'pedido_cobrado' });

  const cfgRows = await Configuracion.findAll({ where: { clave: ['nombre_negocio', 'simbolo_moneda', 'direccion', 'telefono', 'flujo_cocina'] } });
  const cfg = cfgRows.reduce((o, r) => { o[r.clave] = r.valor; return o; }, {});

  const inicioDia = new Date(); inicioDia.setHours(0, 0, 0, 0);
  const finDia    = new Date(); finDia.setHours(23, 59, 59, 999);
  const numero_orden_diario = await Pedido.count({
    where: { creado_en: { [Op.between]: [inicioDia, finDia] }, estado: { [Op.ne]: 'cancelado' } },
  });

  emitir('print:caja', { pedido: creado.toJSON(), metodo_pago, cambio, config: cfg, numero_orden_diario });
  if (cfg.flujo_cocina === 'fisico') {
    emitir('print:cocina', { pedido: creado.toJSON(), config: cfg, numero_orden_diario });
  }
  return creado;
}

async function agregarItem(pedido_id, { producto_id, cantidad = 1, nota }) {
  const pedido = await Pedido.findByPk(pedido_id);
  if (!pedido) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  if (pedido.estado !== 'pendiente') throw Object.assign(new Error('El pedido no está pendiente'), { status: 409 });

  const producto = await Producto.findByPk(producto_id);
  if (!producto) throw Object.assign(new Error('Producto no encontrado'), { status: 404 });
  if (!producto.activo || !producto.es_vendible) throw Object.assign(new Error('Producto no disponible'), { status: 409 });

  const item = await DetallePedido.create({
    pedido_id,
    producto_id,
    cantidad,
    precio: producto.precio,
    nota,
  });

  await _recalcularTotal(pedido_id);
  emitir('restaurante:actualizar', { tipo: 'pedido_items' });
  return item;
}

async function actualizarItem(pedido_id, item_id, { cantidad, nota, estado }) {
  const item = await DetallePedido.findOne({ where: { id: item_id, pedido_id } });
  if (!item) throw Object.assign(new Error('Item no encontrado'), { status: 404 });
  await item.update({ cantidad, nota, estado });
  await _recalcularTotal(pedido_id);
  emitir('restaurante:actualizar', { tipo: 'pedido_items' });
  return item;
}

async function eliminarItem(pedido_id, item_id) {
  const pedido = await Pedido.findByPk(pedido_id);
  if (!pedido || pedido.estado !== 'pendiente') throw Object.assign(new Error('Pedido no modificable'), { status: 409 });
  const item = await DetallePedido.findOne({ where: { id: item_id, pedido_id } });
  if (!item) throw Object.assign(new Error('Item no encontrado'), { status: 404 });
  await item.destroy();
  await _recalcularTotal(pedido_id);
  emitir('restaurante:actualizar', { tipo: 'pedido_items' });
}

async function cobrar(pedido_id, usuario_id, { metodo_pago, monto_recibido, descuento = 0, propina = 0 }) {
  const pedido = await Pedido.findByPk(pedido_id, { include: INCLUDE_PEDIDO_COMPLETO });
  if (!pedido) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  if (!['pendiente', 'listo'].includes(pedido.estado)) throw Object.assign(new Error('El pedido no puede cobrarse'), { status: 409 });
  if (!pedido.sesion_caja_id) throw Object.assign(new Error('No hay sesión de caja activa en este pedido'), { status: 409 });

  const sesion = await SesionCaja.findByPk(pedido.sesion_caja_id);
  if (!sesion || sesion.estado !== 'abierta') throw Object.assign(new Error('La sesión de caja está cerrada'), { status: 409 });

  const monto_neto = parseFloat(pedido.total) - parseFloat(descuento) + parseFloat(propina);

  if (metodo_pago === 'efectivo') {
    if (!monto_recibido || parseFloat(monto_recibido) < monto_neto) {
      throw Object.assign(new Error('Monto recibido insuficiente'), { status: 400 });
    }
  }

  const cambio = metodo_pago === 'efectivo' ? parseFloat(monto_recibido) - monto_neto : 0;

  for (const detalle of pedido.detalles) {
    const producto = await Producto.findByPk(detalle.producto_id);
    if (producto && producto.stock !== null && producto.stock < detalle.cantidad) {
      throw Object.assign(
        new Error(`Stock insuficiente: ${producto.nombre}`),
        { status: 409 }
      );
    }
  }

  await sequelize.transaction(async (t) => {
    await pedido.update({
      estado: 'completado',
      metodo_pago,
      monto_recibido: monto_recibido || monto_neto,
      cambio,
      descuento,
      propina,
    }, { transaction: t });

    if (pedido.tipo !== 'llevar' && pedido.mesa_id) {
      const pendientes = await Pedido.count({ where: { mesa_id: pedido.mesa_id, estado: 'pendiente' }, transaction: t });
      if (pendientes === 0) {
        await Mesa.update({ estado: 'disponible' }, { where: { id: pedido.mesa_id }, transaction: t });
      }
    }

    await LibroCaja.create({
      sesion_caja_id: pedido.sesion_caja_id,
      usuario_id,
      tipo: 'ingreso',
      concepto: `Venta #${pedido.id}`,
      monto: monto_neto,
      metodo_pago,
      referencia_id: pedido.id,
    }, { transaction: t });

    await SesionCaja.increment('total_ventas', { by: monto_neto, where: { id: pedido.sesion_caja_id }, transaction: t });

    for (const detalle of pedido.detalles) {
      const producto = await Producto.findByPk(detalle.producto_id, { transaction: t });
      if (producto && producto.stock !== null) {
        const stock_anterior = producto.stock;
        const stock_nuevo = stock_anterior - detalle.cantidad;
        await producto.update({ stock: stock_nuevo }, { transaction: t });
        await RegistroInventario.create({
          producto_id: detalle.producto_id,
          usuario_id,
          tipo: 'venta',
          cantidad: detalle.cantidad,
          stock_anterior,
          stock_nuevo,
          nota: `Venta #${pedido.id}`,
        }, { transaction: t });
      }
    }
  });

  const cobrado = await obtener(pedido_id);
  emitir('restaurante:actualizar', { tipo: 'pedido_cobrado' });

  // Incluir config del negocio en el evento para que el agente la use directamente
  const cfgRows = await Configuracion.findAll({ where: { clave: ['nombre_negocio', 'simbolo_moneda', 'direccion', 'telefono', 'flujo_cocina'] } });
  const cfg = cfgRows.reduce((o, r) => { o[r.clave] = r.valor; return o; }, {});

  // Número de orden diario (se reinicia cada día, aplica a mesa y llevar)
  const inicioDia = new Date(); inicioDia.setHours(0, 0, 0, 0);
  const finDia    = new Date(); finDia.setHours(23, 59, 59, 999);
  const numero_orden_diario = await Pedido.count({
    where: { creado_en: { [Op.between]: [inicioDia, finDia] }, estado: { [Op.ne]: 'cancelado' } },
  });

  emitir('print:caja', { pedido: cobrado.toJSON(), metodo_pago, cambio, config: cfg, numero_orden_diario });
  if (cfg.flujo_cocina === 'fisico') {
    emitir('print:cocina', { pedido: cobrado.toJSON(), config: cfg, numero_orden_diario });
  }
  return cobrado;
}

async function cancelar(pedido_id, usuario_id) {
  const pedido = await Pedido.findByPk(pedido_id);
  if (!pedido) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  if (pedido.estado !== 'pendiente') throw Object.assign(new Error('Solo se pueden cancelar pedidos pendientes'), { status: 409 });

  await pedido.update({ estado: 'cancelado' });

  if (pedido.tipo !== 'llevar' && pedido.mesa_id) {
    const pendientes = await Pedido.count({ where: { mesa_id: pedido.mesa_id, estado: 'pendiente' } });
    if (pendientes === 0) {
      await Mesa.update({ estado: 'disponible' }, { where: { id: pedido.mesa_id } });
    }
  }

  const cancelado = await obtener(pedido_id);
  emitir('restaurante:actualizar', { tipo: 'pedido_cancelado' });
  return cancelado;
}

async function _recalcularTotal(pedido_id) {
  const [result] = await sequelize.query(
    'SELECT COALESCE(SUM(cantidad * precio), 0) as total FROM detalle_pedidos WHERE pedido_id = ?',
    { replacements: [pedido_id], type: sequelize.QueryTypes.SELECT }
  );
  await Pedido.update({ total: result.total }, { where: { id: pedido_id } });
}

async function marcarListo(pedido_id) {
  const pedido = await Pedido.findByPk(pedido_id);
  if (!pedido) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  if (pedido.estado !== 'pendiente') throw Object.assign(new Error('Solo pedidos pendientes pueden marcarse como listos'), { status: 409 });
  await pedido.update({ estado: 'listo' });
  const listo = await obtener(pedido_id);
  emitir('restaurante:actualizar', { tipo: 'pedido_listo' });
  return listo;
}

module.exports = { listar, listarCocina, obtener, crear, crearCompleta, agregarItem, actualizarItem, eliminarItem, cobrar, cancelar, marcarListo };
