const svc = require('./caja.service');
const { Sucursal } = require('../../models');

function _alcance(req) {
  return { sucursal_id: req.usuario.sucursal_id, acceso_todas: req.usuario.acceso_todas };
}

async function _resolverSucursal(req) {
  if (!req.usuario.acceso_todas) return req.usuario.sucursal_id;
  const sucursal_id = req.body.sucursal_id || req.query.sucursal_id;
  if (!sucursal_id) {
    throw Object.assign(new Error('sucursal_id es requerido'), { status: 400 });
  }
  const existe = await Sucursal.findByPk(sucursal_id);
  if (!existe) throw Object.assign(new Error('Sucursal no encontrada'), { status: 404 });
  return sucursal_id;
}

async function obtenerActiva(req, res, next) {
  try {
    const sucursal_id = await _resolverSucursal(req);
    const sesion = await svc.obtenerActiva(req.usuario.id, sucursal_id);
    res.json({ ok: true, datos: sesion });
  } catch (err) { next(err); }
}

async function listar(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listar(_alcance(req)) }); }
  catch (err) { next(err); }
}

async function obtener(req, res, next) {
  try { res.json({ ok: true, datos: await svc.obtener(req.params.id, _alcance(req)) }); }
  catch (err) { next(err); }
}

async function abrir(req, res, next) {
  try {
    const { monto_apertura } = req.body;
    const sucursal_id = await _resolverSucursal(req);
    res.status(201).json({ ok: true, datos: await svc.abrir(req.usuario.id, sucursal_id, monto_apertura) });
  } catch (err) { next(err); }
}

async function registrarGasto(req, res, next) {
  try {
    const { descripcion, monto } = req.body;
    if (!descripcion || monto === undefined) return res.status(400).json({ ok: false, mensaje: 'descripcion y monto son requeridos' });
    res.status(201).json({ ok: true, datos: await svc.registrarGasto(req.params.id, req.usuario.id, { descripcion, monto }, _alcance(req)) });
  } catch (err) { next(err); }
}

async function listarGastos(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listarGastos(req.params.id, _alcance(req)) }); }
  catch (err) { next(err); }
}

async function cerrar(req, res, next) {
  try {
    const { denominaciones = [] } = req.body;
    res.json({ ok: true, datos: await svc.cerrar(req.params.id, req.usuario.id, denominaciones, _alcance(req)) });
  } catch (err) { next(err); }
}

async function reporte(req, res, next) {
  try { res.json({ ok: true, datos: await svc.reporte(req.params.id, _alcance(req)) }); }
  catch (err) { next(err); }
}

module.exports = { obtenerActiva, listar, obtener, abrir, registrarGasto, listarGastos, cerrar, reporte };
