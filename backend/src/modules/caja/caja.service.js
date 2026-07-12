const { SesionCaja, DetalleArqueo, Gasto, LibroCaja, Usuario, Pedido, Mesa, sequelize } = require('../../models');

async function obtenerActiva(usuario_id, sucursal_id) {
  const sesion = await SesionCaja.findOne({
    where: { usuario_id, sucursal_id, estado: 'abierta' },
    include: [{ model: Usuario, as: 'usuario', attributes: ['id', 'nombre'] }],
  });
  if (!sesion) return null;

  const [ventasEfectivo, ventasQR] = await Promise.all([
    LibroCaja.sum('monto', { where: { sesion_caja_id: sesion.id, tipo: 'ingreso', metodo_pago: 'efectivo' } }),
    LibroCaja.sum('monto', { where: { sesion_caja_id: sesion.id, tipo: 'ingreso', metodo_pago: 'qr' } }),
  ]);

  const datos = sesion.toJSON();
  datos.ventas_efectivo = ventasEfectivo || 0;
  datos.ventas_qr       = ventasQR       || 0;
  return datos;
}

async function listar(alcance = {}) {
  const where = alcance.acceso_todas ? {} : { sucursal_id: alcance.sucursal_id };
  return SesionCaja.findAll({
    where,
    include: [{ model: Usuario, as: 'usuario', attributes: ['id', 'nombre'] }],
    order: [['abierto_en', 'DESC']],
    limit: 50,
  });
}

async function obtener(id) {
  const s = await SesionCaja.findByPk(id, {
    include: [
      { model: Usuario, as: 'usuario', attributes: ['id', 'nombre'] },
      { model: DetalleArqueo, as: 'detalle_arqueo' },
      { model: Gasto, as: 'gastos' },
    ],
  });
  if (!s) throw Object.assign(new Error('Sesión no encontrada'), { status: 404 });
  return s;
}

async function abrir(usuario_id, sucursal_id, monto_apertura = 0) {
  const activa = await obtenerActiva(usuario_id, sucursal_id);
  if (activa) throw Object.assign(new Error('Ya tienes una sesión de caja abierta en esta sucursal'), { status: 409 });
  return SesionCaja.create({ usuario_id, sucursal_id, monto_apertura });
}

async function registrarGasto(sesion_id, usuario_id, { descripcion, monto }) {
  const sesion = await SesionCaja.findByPk(sesion_id);
  if (!sesion) throw Object.assign(new Error('Sesión no encontrada'), { status: 404 });
  if (sesion.estado !== 'abierta') throw Object.assign(new Error('La sesión ya está cerrada'), { status: 409 });

  const gasto = await Gasto.create({ sesion_caja_id: sesion_id, usuario_id, descripcion, monto });

  await LibroCaja.create({
    sesion_caja_id: sesion_id,
    usuario_id,
    tipo: 'egreso',
    concepto: descripcion,
    monto,
    metodo_pago: 'efectivo',
    referencia_id: gasto.id,
  });

  await SesionCaja.increment('total_gastos', { by: parseFloat(monto), where: { id: sesion_id } });

  return gasto;
}

async function listarGastos(sesion_id) {
  return Gasto.findAll({
    where: { sesion_caja_id: sesion_id },
    include: [{ model: Usuario, as: 'usuario', attributes: ['id', 'nombre'] }],
    order: [['creado_en', 'DESC']],
  });
}

async function cerrar(sesion_id, usuario_id, denominaciones = []) {
  const sesion = await SesionCaja.findByPk(sesion_id);
  if (!sesion) throw Object.assign(new Error('Sesión no encontrada'), { status: 404 });
  if (sesion.estado !== 'abierta') throw Object.assign(new Error('La sesión ya está cerrada'), { status: 409 });
  if (sesion.usuario_id !== usuario_id) throw Object.assign(new Error('Solo el cajero que abrió puede cerrar la sesión'), { status: 403 });

  // Calcular total físico de denominaciones
  const total_fisico = denominaciones.reduce((sum, d) => sum + (parseFloat(d.denominacion) * parseInt(d.cantidad)), 0);

  // Guardar detalle de arqueo
  if (denominaciones.length > 0) {
    await DetalleArqueo.destroy({ where: { sesion_caja_id: sesion_id } });
    await DetalleArqueo.bulkCreate(
      denominaciones.map(d => ({
        sesion_caja_id: sesion_id,
        denominacion: d.denominacion,
        cantidad: d.cantidad,
        subtotal: parseFloat(d.denominacion) * parseInt(d.cantidad),
      }))
    );
  }

  // Calcular ventas en efectivo para el arqueo
  const ventasEfectivo = await LibroCaja.sum('monto', {
    where: { sesion_caja_id: sesion_id, tipo: 'ingreso', metodo_pago: 'efectivo' },
  }) || 0;

  const efectivo_esperado = parseFloat(sesion.monto_apertura) + ventasEfectivo - parseFloat(sesion.total_gastos);
  const diferencia = total_fisico - efectivo_esperado;

  await sesion.update({
    monto_cierre: total_fisico,
    diferencia,
    estado: 'cerrada',
    cerrado_en: new Date(),
  });

  return obtener(sesion_id);
}

async function reporte(sesion_id) {
  const sesion = await obtener(sesion_id);

  // Ventas por método de pago (todas las filas del GROUP BY)
  const ventasPorMetodoArr = await sequelize.query(
    `SELECT metodo_pago, COUNT(*) as cantidad, SUM(monto) as total
     FROM libro_caja
     WHERE sesion_caja_id = ? AND tipo = 'ingreso'
     GROUP BY metodo_pago`,
    { replacements: [sesion_id], type: sequelize.QueryTypes.SELECT }
  );

  // Pedidos completados en la sesión
  const pedidos = await Pedido.findAll({
    where: { sesion_caja_id: sesion_id, estado: 'completado' },
    include: [{ model: Mesa, as: 'mesa', attributes: ['id', 'nombre'] }],
    order: [['creado_en', 'DESC']],
  });

  // Productos vendidos en el turno (agrupado por producto)
  const productosVendidos = await sequelize.query(
    `SELECT pr.nombre, SUM(dp.cantidad) AS total_cantidad, SUM(dp.cantidad * dp.precio) AS total
     FROM detalle_pedidos dp
     JOIN pedidos pe ON pe.id = dp.pedido_id
     JOIN productos pr ON pr.id = dp.producto_id
     WHERE pe.sesion_caja_id = ? AND pe.estado = 'completado'
     GROUP BY dp.producto_id, pr.nombre
     ORDER BY total_cantidad DESC`,
    { replacements: [sesion_id], type: sequelize.QueryTypes.SELECT }
  );

  const efectivoEsperado =
    parseFloat(sesion.monto_apertura) +
    parseFloat(ventasPorMetodoArr.find(v => v.metodo_pago === 'efectivo')?.total ?? 0) -
    parseFloat(sesion.total_gastos);

  return {
    sesion,
    ventas_por_metodo: ventasPorMetodoArr,
    pedidos,
    efectivo_esperado: efectivoEsperado,
    productos_vendidos: productosVendidos,
  };
}

module.exports = { obtenerActiva, listar, obtener, abrir, registrarGasto, listarGastos, cerrar, reporte };
