### Task 3: `ventas.service.js` — flujo de cobro con QR (iniciar, confirmar, cancelar)

**Files:**
- Modify: `backend/src/modules/ventas/ventas.service.js`
- Modify: `backend/src/modules/ventas/ventas.controller.js`
- Modify: `backend/src/modules/ventas/ventas.routes.js`
- Modify: `backend/tests/ventas.test.js`

**Interfaces:**
- Consumes: `codepayClient.generarQr`/`consultarEstado` (Task 2), modelo `PagoQr` (Task 1).
- Produces: `ventas.service.js` exporta además `consultarEstadoPagoQr(pedido_id, alcance)`, `cancelarPagoQr(pedido_id, alcance)` y `procesarWebhookPagoQr({ event, order_id, tx_id })` (esta última la usará el módulo de webhook en Task 4 — no la llama nada más en este task).
  Cuando `metodo_pago === 'qr'`, `cobrar(...)` y `crearCompleta(...)` devuelven `{ pedido, pago_qr: { qr_code, tx_id, expires_at, monto_neto, comision, monto_total } }` en vez del pedido completado directamente (comportamiento sin cambios para `metodo_pago === 'efectivo'`).
  Nuevas rutas: `GET /api/v1/ventas/:id/pago-qr/estado`, `POST /api/v1/ventas/:id/pago-qr/cancelar` (mismos permisos que `/:id/cobrar`: `verificarPermiso('ventas', 'cobrar')`).

**IMPORTANTE — este task reemplaza el archivo completo `ventas.service.js`.** El archivo actual tiene 352 líneas; el contenido de abajo es el reemplazo completo, no un diff. Reescribir el archivo entero con este contenido.

- [ ] **Step 1: Reescribir `backend/src/modules/ventas/ventas.service.js` completo**

```javascript
const { Op } = require('sequelize');
const {
  Pedido, DetallePedido, Mesa, Producto, Cliente, SesionCaja, LibroCaja, Configuracion, PagoQr, sequelize,
} = require('../../models');
const { emitir } = require('../../socket');
const { ajustarStockSucursal } = require('../inventario/stock.service');
const codepayClient = require('../../integrations/codepay/codepay.client');

const INCLUDE_PEDIDO_COMPLETO = [
  { model: Mesa, as: 'mesa', attributes: ['id', 'nombre', 'estado'] },
  { model: Cliente, as: 'cliente', attributes: ['id', 'nombre', 'numero_documento'] },
  {
    model: DetallePedido, as: 'detalles',
    include: [{ model: Producto, as: 'producto', attributes: ['id', 'nombre', 'precio'] }],
  },
];

async function listar({ estado, mesa_id, sucursal_id, acceso_todas } = {}) {
  const where = {};
  if (estado) {
    where.estado = estado.includes(',') ? { [Op.in]: estado.split(',') } : estado;
  }
  if (mesa_id) where.mesa_id = mesa_id;
  if (!acceso_todas) where.sucursal_id = sucursal_id;
  return Pedido.findAll({ where, include: INCLUDE_PEDIDO_COMPLETO, order: [['creado_en', 'DESC']] });
}

async function listarCocina({ sucursal_id, acceso_todas } = {}) {
  const where = { estado: { [Op.in]: ['pendiente', 'listo'] } };
  if (!acceso_todas) where.sucursal_id = sucursal_id;
  return Pedido.findAll({
    where,
    include: INCLUDE_PEDIDO_COMPLETO,
    order: [['creado_en', 'ASC']],
  });
}

function _verificarAlcance(pedido, alcance) {
  if (alcance && !alcance.acceso_todas && pedido.sucursal_id !== alcance.sucursal_id) {
    throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  }
}

async function obtener(id, alcance) {
  const p = await Pedido.findByPk(id, { include: INCLUDE_PEDIDO_COMPLETO });
  if (!p) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  _verificarAlcance(p, alcance);
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
  const sucursal_id = sesionActiva.sucursal_id;

  if (tipo === 'mesa') {
    const mesa = await Mesa.findByPk(mesa_id);
    if (!mesa) throw Object.assign(new Error('Mesa no encontrada'), { status: 404 });

    const pedido = await Pedido.create({
      mesa_id, tipo: 'mesa', usuario_id, cliente_id, sesion_caja_id, sucursal_id, notas,
      nombre_cliente: nombre_cliente || 'Público General',
      documento_cliente,
      tipo_documento: tipo_documento || 'Ticket',
    });
    await mesa.update({ estado: 'ocupada' });
    const resultado = await obtener(pedido.id);
    emitir('restaurante:actualizar', { tipo: 'pedido_nuevo' }, sucursal_id);
    return resultado;
  }

  // tipo === 'llevar'
  const numero_llevar = await _siguienteNumeroLlevar();
  const pedido = await Pedido.create({
    mesa_id: null, tipo: 'llevar', numero_llevar, usuario_id, cliente_id, sesion_caja_id, sucursal_id, notas,
    nombre_cliente: nombre_cliente || 'Cliente',
    documento_cliente,
    tipo_documento: tipo_documento || 'Ticket',
  });
  const resultado = await obtener(pedido.id);
  emitir('restaurante:actualizar', { tipo: 'pedido_nuevo' }, sucursal_id);
  return resultado;
}

/**
 * Completa una venta ya decidida (efectivo, o confirmación de un pago QR):
 * marca el pedido completado, descuenta stock, registra el ingreso en el
 * libro de caja y libera la mesa si corresponde. Debe correr dentro de una
 * transacción activa.
 */
async function _finalizarVenta({ pedido, detalles, metodo_pago, monto_recibido, descuento = 0, propina = 0, usuario_id }, transaction) {
  const monto_neto = parseFloat(pedido.total) - parseFloat(descuento) + parseFloat(propina);
  const cambio = metodo_pago === 'efectivo' ? parseFloat(monto_recibido) - monto_neto : 0;

  await pedido.update({
    estado: 'completado', metodo_pago, monto_recibido: monto_recibido || monto_neto, cambio, descuento, propina,
  }, { transaction });

  if (pedido.tipo !== 'llevar' && pedido.mesa_id) {
    const pendientes = await Pedido.count({ where: { mesa_id: pedido.mesa_id, estado: 'pendiente' }, transaction });
    if (pendientes === 0) {
      await Mesa.update({ estado: 'disponible' }, { where: { id: pedido.mesa_id }, transaction });
    }
  }

  await LibroCaja.create({
    sesion_caja_id: pedido.sesion_caja_id, usuario_id, tipo: 'ingreso', concepto: `Venta #${pedido.id}`, monto: monto_neto, metodo_pago, referencia_id: pedido.id,
  }, { transaction });

  await SesionCaja.increment('total_ventas', { by: monto_neto, where: { id: pedido.sesion_caja_id }, transaction });

  for (const detalle of detalles) {
    const producto = await Producto.findByPk(detalle.producto_id, { transaction });
    if (producto && producto.stock !== null) {
      await ajustarStockSucursal({
        producto_id: detalle.producto_id, sucursal_id: pedido.sucursal_id, tipo: 'venta', cantidad: detalle.cantidad,
        usuario_id, nota: `Venta #${pedido.id}`, transaction,
      });
    }
  }

  return monto_neto;
}

async function _emitirImpresion(pedido, metodo_pago, cambio, sucursal_id) {
  const cfgRows = await Configuracion.findAll({ where: { clave: ['nombre_negocio', 'simbolo_moneda', 'direccion', 'telefono', 'flujo_cocina'] } });
  const cfg = cfgRows.reduce((o, r) => { o[r.clave] = r.valor; return o; }, {});

  const inicioDia = new Date(); inicioDia.setHours(0, 0, 0, 0);
  const finDia    = new Date(); finDia.setHours(23, 59, 59, 999);
  const numero_orden_diario = await Pedido.count({
    where: { creado_en: { [Op.between]: [inicioDia, finDia] }, estado: { [Op.ne]: 'cancelado' } },
  });

  emitir('print:caja', { pedido: pedido.toJSON(), metodo_pago, cambio, config: cfg, numero_orden_diario }, sucursal_id);
  if (cfg.flujo_cocina === 'fisico') {
    emitir('print:cocina', { pedido: pedido.toJSON(), config: cfg, numero_orden_diario }, sucursal_id);
  }
}

/**
 * Genera un QR de cobro con CodePay para un pedido ya persistido (con su
 * total ya calculado) y deja el pedido en 'pendiente_pago' hasta que se
 * confirme (ver consultarEstadoPagoQr / procesarWebhookPagoQr).
 */
async function iniciarPagoQr(pedido, { descuento = 0, propina = 0 } = {}) {
  const estadoPrevio = pedido.estado;
  const monto_neto = parseFloat(pedido.total) - parseFloat(descuento) + parseFloat(propina);
  const intentosPrevios = await PagoQr.count({ where: { pedido_id: pedido.id } });
  const order_id = `pedido_${pedido.id}_${intentosPrevios + 1}`;
  const expires_at = new Date(Date.now() + 30 * 60 * 1000);

  const cfg = await Configuracion.findOne({ where: { clave: 'nombre_negocio' } });
  const description = ((cfg && cfg.valor) || 'Venta').replace(/[^a-zA-Z0-9]/g, '').slice(0, 20) || 'Venta';

  const respuesta = await codepayClient.generarQr({
    order_id, amount: monto_neto, description, expires_at: expires_at.toISOString(),
  });

  await sequelize.transaction(async (t) => {
    await PagoQr.create({
      pedido_id: pedido.id, sucursal_id: pedido.sucursal_id, order_id,
      tx_id: respuesta.tx_id, estado: 'pendiente', estado_previo: estadoPrevio,
      monto_neto, comision: respuesta.commission_amount, monto_total: respuesta.amount,
      qr_code: respuesta.qr_code, expires_at,
    }, { transaction: t });

    await pedido.update({ estado: 'pendiente_pago', metodo_pago: 'qr', descuento, propina }, { transaction: t });
  });

  return {
    qr_code: respuesta.qr_code, tx_id: respuesta.tx_id, expires_at,
    monto_neto, comision: respuesta.commission_amount, monto_total: respuesta.amount,
  };
}

async function _revertirPagoQr(pagoQr, nuevoEstado) {
  await sequelize.transaction(async (t) => {
    await pagoQr.update({ estado: nuevoEstado }, { transaction: t });
    await Pedido.update({ estado: pagoQr.estado_previo }, { where: { id: pagoQr.pedido_id }, transaction: t });
  });
}

async function _confirmarPagoQr(pagoQr) {
  const pedido = await Pedido.findByPk(pagoQr.pedido_id, { include: INCLUDE_PEDIDO_COMPLETO });
  const detalles = pedido.detalles.map((d) => ({ producto_id: d.producto_id, cantidad: d.cantidad }));

  await sequelize.transaction(async (t) => {
    await _finalizarVenta({
      pedido, detalles, metodo_pago: 'qr', monto_recibido: pagoQr.monto_neto,
      descuento: pedido.descuento, propina: pedido.propina, usuario_id: pedido.usuario_id,
    }, t);
    await pagoQr.update({ estado: 'completado' }, { transaction: t });
  });

  const completado = await obtener(pedido.id);
  emitir('restaurante:actualizar', { tipo: 'pedido_cobrado' }, pedido.sucursal_id);
  await _emitirImpresion(completado, 'qr', 0, pedido.sucursal_id);
  return completado;
}

async function consultarEstadoPagoQr(pedido_id, alcance) {
  const pedido = await Pedido.findByPk(pedido_id);
  if (!pedido) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  _verificarAlcance(pedido, alcance);

  const pagoQr = await PagoQr.findOne({ where: { pedido_id, estado: 'pendiente' }, order: [['id', 'DESC']] });
  if (!pagoQr) throw Object.assign(new Error('No hay un pago QR pendiente para este pedido'), { status: 404 });

  if (new Date() > pagoQr.expires_at) {
    await _revertirPagoQr(pagoQr, 'expirado');
    return { estado: 'expirado', pedido: await obtener(pedido_id) };
  }

  const estadoCodepay = await codepayClient.consultarEstado(pagoQr.tx_id);

  if (estadoCodepay.status === 'completed') {
    await _confirmarPagoQr(pagoQr);
    return { estado: 'completado', pedido: await obtener(pedido_id) };
  }
  if (estadoCodepay.status === 'failed') {
    await _revertirPagoQr(pagoQr, 'fallido');
    return { estado: 'fallido', pedido: await obtener(pedido_id) };
  }
  return { estado: 'pendiente', pedido: await obtener(pedido_id) };
}

async function cancelarPagoQr(pedido_id, alcance) {
  const pedido = await Pedido.findByPk(pedido_id);
  if (!pedido) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  _verificarAlcance(pedido, alcance);

  const pagoQr = await PagoQr.findOne({ where: { pedido_id, estado: 'pendiente' }, order: [['id', 'DESC']] });
  if (!pagoQr) throw Object.assign(new Error('No hay un pago QR pendiente para este pedido'), { status: 404 });

  await _revertirPagoQr(pagoQr, 'cancelado');
  return obtener(pedido_id);
}

/** Usado por el endpoint de webhook (Task 4). Idempotente. */
async function procesarWebhookPagoQr({ event, order_id }) {
  const pagoQr = await PagoQr.findOne({ where: { order_id } });
  if (!pagoQr || pagoQr.estado !== 'pendiente') return;

  if (event === 'payment.completed') {
    await _confirmarPagoQr(pagoQr);
  } else if (event === 'payment.failed') {
    await _revertirPagoQr(pagoQr, 'fallido');
  }
}

async function crearCompleta({ tipo, mesa_id, nombre_cliente, documento_cliente, tipo_documento, items, metodo_pago, monto_recibido, descuento = 0, propina = 0, sesion_caja_id, usuario_id }) {
  if (!sesion_caja_id) {
    throw Object.assign(new Error('No hay caja abierta. Abre la caja antes de crear una orden.'), { status: 409 });
  }
  const sesionActiva = await SesionCaja.findByPk(sesion_caja_id);
  if (!sesionActiva || sesionActiva.estado !== 'abierta') {
    throw Object.assign(new Error('La sesión de caja no está abierta.'), { status: 409 });
  }
  const sucursal_id = sesionActiva.sucursal_id;

  if (!items || items.length === 0) {
    throw Object.assign(new Error('El pedido no tiene productos'), { status: 409 });
  }

  const productos = [];
  for (const item of items) {
    const producto = await Producto.findByPk(item.producto_id);
    if (!producto) throw Object.assign(new Error('Producto no encontrado'), { status: 404 });
    if (!producto.activo || !producto.es_vendible) throw Object.assign(new Error('Producto no disponible'), { status: 409 });
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

  const numero_llevar = tipo === 'llevar' ? await _siguienteNumeroLlevar() : null;
  const estadoInicial = metodo_pago === 'qr' ? 'pendiente' : 'completado';

  const pedidoId = await sequelize.transaction(async (t) => {
    const pedido = await Pedido.create({
      mesa_id: tipo === 'mesa' ? mesa_id : null,
      tipo, numero_llevar, usuario_id, sesion_caja_id, sucursal_id,
      estado: estadoInicial, total, descuento, propina, metodo_pago: 'efectivo',
      nombre_cliente: nombre_cliente || (tipo === 'llevar' ? 'Cliente' : 'Público General'),
      documento_cliente,
      tipo_documento: tipo_documento || 'Ticket',
    }, { transaction: t });

    const detalles = [];
    for (const { item, producto } of productos) {
      await DetallePedido.create({
        pedido_id: pedido.id, producto_id: item.producto_id, cantidad: item.cantidad, precio: producto.precio, nota: item.nota,
      }, { transaction: t });
      detalles.push({ producto_id: item.producto_id, cantidad: item.cantidad });
    }

    if (metodo_pago !== 'qr') {
      await _finalizarVenta({ pedido, detalles, metodo_pago, monto_recibido, descuento, propina, usuario_id }, t);
    }

    return pedido.id;
  });

  if (metodo_pago === 'qr') {
    const pedidoPendiente = await Pedido.findByPk(pedidoId);
    const pago_qr = await iniciarPagoQr(pedidoPendiente, { descuento, propina });
    emitir('restaurante:actualizar', { tipo: 'pedido_nuevo' }, sucursal_id);
    return { pedido: await obtener(pedidoId), pago_qr };
  }

  const creado = await obtener(pedidoId);
  emitir('restaurante:actualizar', { tipo: 'pedido_cobrado' }, sucursal_id);
  await _emitirImpresion(creado, metodo_pago, parseFloat(monto_recibido || monto_neto) - monto_neto, sucursal_id);
  return creado;
}

async function agregarItem(pedido_id, { producto_id, cantidad = 1, nota }, alcance) {
  const pedido = await Pedido.findByPk(pedido_id);
  if (!pedido) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  _verificarAlcance(pedido, alcance);
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

async function actualizarItem(pedido_id, item_id, { cantidad, nota, estado }, alcance) {
  const pedido = await Pedido.findByPk(pedido_id);
  if (!pedido) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  _verificarAlcance(pedido, alcance);
  const item = await DetallePedido.findOne({ where: { id: item_id, pedido_id } });
  if (!item) throw Object.assign(new Error('Item no encontrado'), { status: 404 });
  await item.update({ cantidad, nota, estado });
  await _recalcularTotal(pedido_id);
  emitir('restaurante:actualizar', { tipo: 'pedido_items' });
  return item;
}

async function eliminarItem(pedido_id, item_id, alcance) {
  const pedido = await Pedido.findByPk(pedido_id);
  if (!pedido) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  _verificarAlcance(pedido, alcance);
  if (pedido.estado !== 'pendiente') throw Object.assign(new Error('Pedido no modificable'), { status: 409 });
  const item = await DetallePedido.findOne({ where: { id: item_id, pedido_id } });
  if (!item) throw Object.assign(new Error('Item no encontrado'), { status: 404 });
  await item.destroy();
  await _recalcularTotal(pedido_id);
  emitir('restaurante:actualizar', { tipo: 'pedido_items' });
}

async function cobrar(pedido_id, usuario_id, { metodo_pago, monto_recibido, descuento = 0, propina = 0 }, alcance) {
  const pedido = await Pedido.findByPk(pedido_id, { include: INCLUDE_PEDIDO_COMPLETO });
  if (!pedido) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  _verificarAlcance(pedido, alcance);
  if (!['pendiente', 'listo'].includes(pedido.estado)) throw Object.assign(new Error('El pedido no puede cobrarse'), { status: 409 });
  if (!pedido.sesion_caja_id) throw Object.assign(new Error('No hay sesión de caja activa en este pedido'), { status: 409 });

  const sesion = await SesionCaja.findByPk(pedido.sesion_caja_id);
  if (!sesion || sesion.estado !== 'abierta') throw Object.assign(new Error('La sesión de caja está cerrada'), { status: 409 });

  const monto_neto = parseFloat(pedido.total) - parseFloat(descuento) + parseFloat(propina);

  if (metodo_pago === 'efectivo' && (!monto_recibido || parseFloat(monto_recibido) < monto_neto)) {
    throw Object.assign(new Error('Monto recibido insuficiente'), { status: 400 });
  }

  if (metodo_pago === 'qr') {
    const pago_qr = await iniciarPagoQr(pedido, { descuento, propina });
    return { pedido: await obtener(pedido_id), pago_qr };
  }

  const detalles = pedido.detalles.map((d) => ({ producto_id: d.producto_id, cantidad: d.cantidad }));
  await sequelize.transaction((t) => _finalizarVenta({ pedido, detalles, metodo_pago, monto_recibido, descuento, propina, usuario_id }, t));

  const cobrado = await obtener(pedido_id);
  emitir('restaurante:actualizar', { tipo: 'pedido_cobrado' }, pedido.sucursal_id);
  await _emitirImpresion(cobrado, metodo_pago, parseFloat(monto_recibido) - monto_neto, pedido.sucursal_id);
  return cobrado;
}

async function cancelar(pedido_id, usuario_id, alcance) {
  const pedido = await Pedido.findByPk(pedido_id);
  if (!pedido) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  _verificarAlcance(pedido, alcance);
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

async function marcarListo(pedido_id, alcance) {
  const pedido = await Pedido.findByPk(pedido_id);
  if (!pedido) throw Object.assign(new Error('Pedido no encontrado'), { status: 404 });
  _verificarAlcance(pedido, alcance);
  if (pedido.estado !== 'pendiente') throw Object.assign(new Error('Solo pedidos pendientes pueden marcarse como listos'), { status: 409 });
  await pedido.update({ estado: 'listo' });
  const listo = await obtener(pedido_id);
  emitir('restaurante:actualizar', { tipo: 'pedido_listo' });
  return listo;
}

module.exports = {
  listar, listarCocina, obtener, crear, crearCompleta, agregarItem, actualizarItem, eliminarItem,
  cobrar, cancelar, marcarListo,
  consultarEstadoPagoQr, cancelarPagoQr, procesarWebhookPagoQr,
};
```

- [ ] **Step 2: Agregar los controladores nuevos**

En `backend/src/modules/ventas/ventas.controller.js`, agregar (junto a `cobrar`/`cancelar`):

```javascript
async function estadoPagoQr(req, res, next) {
  try { res.json({ ok: true, datos: await svc.consultarEstadoPagoQr(req.params.id, _alcance(req)) }); }
  catch (err) { next(err); }
}

async function cancelarPagoQr(req, res, next) {
  try { res.json({ ok: true, datos: await svc.cancelarPagoQr(req.params.id, _alcance(req)) }); }
  catch (err) { next(err); }
}
```

Y en el `module.exports` final, agregar `estadoPagoQr, cancelarPagoQr`:

```javascript
module.exports = { listar, obtener, crear, crearCompleta, agregarItem, actualizarItem, eliminarItem, cobrar, cancelar, listarCocina, marcarListo, estadoPagoQr, cancelarPagoQr };
```

- [ ] **Step 3: Agregar las rutas nuevas**

En `backend/src/modules/ventas/ventas.routes.js`, agregar después de la línea de `/:id/cobrar`:

```javascript
router.get('/:id/pago-qr/estado', verificarPermiso('ventas', 'cobrar'), ctrl.estadoPagoQr);
router.post('/:id/pago-qr/cancelar', verificarPermiso('ventas', 'cobrar'), ctrl.cancelarPagoQr);
```

- [ ] **Step 4: Agregar los tests de integración a `backend/tests/ventas.test.js`**

Agregar al final del archivo (después del último `describe` existente), reutilizando el import de modelos que ya está en la parte superior del archivo — agregar `PagoQr` a esa lista de imports existente (`const { Sucursal, Area, Mesa, Categoria, Producto, ProductoStockSucursal, Usuario, Rol, SesionCaja, Pedido, RegistroInventario, LibroCaja, Caja } = require('../src/models');` pasa a incluir también `PagoQr`), y agregar `jest.mock` del cliente de CodePay como las primeras líneas del archivo, **antes** de `const app = require('../src/app');`. Este proyecto no usa Babel/ESM (es CommonJS puro, sin hoisting automático de `jest.mock`), así que el orden físico en el archivo importa: si `jest.mock` quedara después del `require('../src/app')`, `ventas.service.js` ya habría cargado el cliente real de CodePay antes de que el mock exista:

```javascript
jest.mock('../src/integrations/codepay/codepay.client', () => ({
  generarQr: jest.fn(),
  consultarEstado: jest.fn(),
  verificarFirmaWebhook: jest.fn(),
}));
```

Y al final del archivo:

```javascript
const codepayClientMock = require('../src/integrations/codepay/codepay.client');

describe('Ventas — cobro con QR (CodePay)', () => {
  let sucursalId, areaId, mesaId, usuarioId, cajaId, sesionId, productoId, token;

  beforeAll(async () => {
    const sucursal = await Sucursal.create({ nombre: 'Sucursal PagoQr Ventas Test' });
    sucursalId = sucursal.id;
    const area = await Area.create({ nombre: 'Area PagoQr Ventas Test', sucursal_id: sucursalId });
    areaId = area.id;
    const mesa = await Mesa.create({ area_id: areaId, nombre: 'Mesa PagoQr Ventas Test' });
    mesaId = mesa.id;
    const categoria = await Categoria.create({ nombre: 'Categoria PagoQr Ventas Test' });
    const producto = await Producto.create({ categoria_id: categoria.id, nombre: 'Producto PagoQr Ventas Test', precio: 5, stock: 0 });
    productoId = producto.id;
    await ProductoStockSucursal.create({ producto_id: productoId, sucursal_id: sucursalId, stock: 10 });

    const rol = await Rol.findOne({ where: { nombre: 'Cajero' } });
    const hash = await bcrypt.hash('clave123', 10);
    const usuario = await Usuario.create({ rol_id: rol.id, nombre: 'PagoQr Ventas Test', email: 'pagoqr-ventas-test@restaurante.com', contrasena: hash });
    usuarioId = usuario.id;
    await usuario.addSucursal(sucursal);

    const login = await request(app).post('/api/v1/auth/login').send({ email: 'pagoqr-ventas-test@restaurante.com', contrasena: 'clave123' });
    token = login.body.datos.token;

    const caja = await Caja.create({ sucursal_id: sucursalId, nombre: 'Caja PagoQr Ventas Test' });
    cajaId = caja.id;
    const sesion = await SesionCaja.create({ usuario_id: usuarioId, sucursal_id: sucursalId, caja_id: cajaId, monto_apertura: 0 });
    sesionId = sesion.id;
  });

  afterEach(() => { jest.clearAllMocks(); });

  afterAll(async () => {
    await PagoQr.destroy({ where: { sucursal_id: sucursalId } });
    await Pedido.destroy({ where: { usuario_id: usuarioId } });
    await LibroCaja.destroy({ where: { usuario_id: usuarioId } });
    await SesionCaja.destroy({ where: { id: sesionId } });
    await Caja.destroy({ where: { id: cajaId } });
    await ProductoStockSucursal.destroy({ where: { producto_id: productoId } });
    await Producto.destroy({ where: { id: productoId } });
    await Usuario.destroy({ where: { id: usuarioId } });
    await Mesa.destroy({ where: { id: mesaId } });
    await Area.destroy({ where: { id: areaId } });
    await Sucursal.destroy({ where: { id: sucursalId } });
  });

  it('crearCompleta con metodo_pago=qr deja el pedido en pendiente_pago sin tocar stock ni libro de caja', async () => {
    codepayClientMock.generarQr.mockResolvedValue({
      qr_code: 'data:image/png;base64,abc', tx_id: 'tx_qr_1', amount: 10.35, net_amount: 10, commission_amount: 0.35,
    });

    const res = await request(app)
      .post('/api/v1/ventas/completa')
      .set('Authorization', `Bearer ${token}`)
      .send({
        tipo: 'llevar', metodo_pago: 'qr', sesion_caja_id: sesionId,
        items: [{ producto_id: productoId, cantidad: 2 }],
      });

    expect(res.status).toBe(201);
    expect(res.body.datos.pago_qr.tx_id).toBe('tx_qr_1');
    expect(res.body.datos.pedido.estado).toBe('pendiente_pago');

    const fila = await ProductoStockSucursal.findOne({ where: { producto_id: productoId, sucursal_id: sucursalId } });
    expect(fila.stock).toBe(10); // sin cambios todavía

    const entradasLibro = await LibroCaja.count({ where: { referencia_id: res.body.datos.pedido.id } });
    expect(entradasLibro).toBe(0);
  });

  it('confirmación exitosa por polling: completa la venta, descuenta stock y registra el ingreso', async () => {
    codepayClientMock.generarQr.mockResolvedValue({
      qr_code: 'data:image/png;base64,abc', tx_id: 'tx_qr_2', amount: 10.35, net_amount: 10, commission_amount: 0.35,
    });

    const creado = await request(app)
      .post('/api/v1/ventas/completa')
      .set('Authorization', `Bearer ${token}`)
      .send({
        tipo: 'llevar', metodo_pago: 'qr', sesion_caja_id: sesionId,
        items: [{ producto_id: productoId, cantidad: 1 }],
      });
    const pedidoId = creado.body.datos.pedido.id;

    codepayClientMock.consultarEstado.mockResolvedValue({ status: 'completed', tx_id: 'tx_qr_2', order_id: `pedido_${pedidoId}_1` });

    const res = await request(app)
      .get(`/api/v1/ventas/${pedidoId}/pago-qr/estado`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.datos.estado).toBe('completado');
    expect(res.body.datos.pedido.estado).toBe('completado');

    const entradasLibro = await LibroCaja.count({ where: { referencia_id: pedidoId } });
    expect(entradasLibro).toBe(1);
  });

  it('confirmación fallida por polling: el pedido vuelve a pendiente y puede reintentarse', async () => {
    codepayClientMock.generarQr.mockResolvedValue({
      qr_code: 'data:image/png;base64,abc', tx_id: 'tx_qr_3', amount: 10.35, net_amount: 10, commission_amount: 0.35,
    });

    const creado = await request(app)
      .post('/api/v1/ventas/completa')
      .set('Authorization', `Bearer ${token}`)
      .send({
        tipo: 'llevar', metodo_pago: 'qr', sesion_caja_id: sesionId,
        items: [{ producto_id: productoId, cantidad: 1 }],
      });
    const pedidoId = creado.body.datos.pedido.id;

    codepayClientMock.consultarEstado.mockResolvedValue({ status: 'failed', tx_id: 'tx_qr_3', order_id: `pedido_${pedidoId}_1` });

    const res = await request(app)
      .get(`/api/v1/ventas/${pedidoId}/pago-qr/estado`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.datos.estado).toBe('fallido');
    expect(res.body.datos.pedido.estado).toBe('pendiente');

    // Reintento: nuevo order_id (segundo intento), pedido vuelve a pendiente_pago
    codepayClientMock.generarQr.mockResolvedValue({
      qr_code: 'data:image/png;base64,def', tx_id: 'tx_qr_3b', amount: 10.35, net_amount: 10, commission_amount: 0.35,
    });
    const reintento = await request(app)
      .post(`/api/v1/ventas/${pedidoId}/cobrar`)
      .set('Authorization', `Bearer ${token}`)
      .send({ metodo_pago: 'qr' });

    expect(reintento.status).toBe(200);
    expect(reintento.body.datos.pago_qr.tx_id).toBe('tx_qr_3b');
    expect(codepayClientMock.generarQr).toHaveBeenCalledWith(expect.objectContaining({ order_id: `pedido_${pedidoId}_2` }));
  });

  it('cancelación manual: revierte el pedido a su estado previo', async () => {
    codepayClientMock.generarQr.mockResolvedValue({
      qr_code: 'data:image/png;base64,abc', tx_id: 'tx_qr_4', amount: 10.35, net_amount: 10, commission_amount: 0.35,
    });

    const creado = await request(app)
      .post('/api/v1/ventas/completa')
      .set('Authorization', `Bearer ${token}`)
      .send({
        tipo: 'llevar', metodo_pago: 'qr', sesion_caja_id: sesionId,
        items: [{ producto_id: productoId, cantidad: 1 }],
      });
    const pedidoId = creado.body.datos.pedido.id;

    const res = await request(app)
      .post(`/api/v1/ventas/${pedidoId}/pago-qr/cancelar`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.datos.estado).toBe('pendiente');
  });

  it('GET pago-qr/estado sin ningún pago pendiente → 404', async () => {
    const creado = await request(app)
      .post('/api/v1/ventas')
      .set('Authorization', `Bearer ${token}`)
      .send({ mesa_id: mesaId, tipo: 'mesa', sesion_caja_id: sesionId });

    const res = await request(app)
      .get(`/api/v1/ventas/${creado.body.datos.id}/pago-qr/estado`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(404);
  });
});
```

- [ ] **Step 5: Correr toda la suite de backend**

Run: `cd backend && npm test`
Expected: todas las suites PASS (incluidas las preexistentes — `cobrar`/`crearCompleta` con `metodo_pago='efectivo'` deben seguir pasando exactamente igual que antes).

- [ ] **Step 6: Commit**

```bash
git add backend/src/modules/ventas/ventas.service.js backend/src/modules/ventas/ventas.controller.js backend/src/modules/ventas/ventas.routes.js backend/tests/ventas.test.js
git commit -m "feat(pagos-qr): flujo de cobro con QR en ventas (iniciar, confirmar por polling, cancelar)"
```

---

