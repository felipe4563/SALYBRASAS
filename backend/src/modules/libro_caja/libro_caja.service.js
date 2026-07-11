const { LibroCaja, SesionCaja, Usuario } = require('../../models');

const INCLUDE_LB = [
  { model: SesionCaja, as: 'sesion_caja', attributes: ['id', 'estado', 'abierto_en'] },
  { model: Usuario, as: 'usuario', attributes: ['id', 'nombre'] },
];

async function listar({ sesion_caja_id } = {}) {
  const where = {};
  if (sesion_caja_id) where.sesion_caja_id = sesion_caja_id;
  return LibroCaja.findAll({ where, include: INCLUDE_LB, order: [['creado_en', 'DESC']] });
}

async function crear(usuario_id, { sesion_caja_id, tipo, concepto, monto, metodo_pago = 'efectivo' }) {
  if (!['ingreso', 'egreso'].includes(tipo)) throw Object.assign(new Error('tipo debe ser ingreso o egreso'), { status: 400 });
  return LibroCaja.create({ sesion_caja_id, usuario_id, tipo, concepto, monto, metodo_pago });
}

module.exports = { listar, crear };
