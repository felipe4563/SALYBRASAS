const svc = require('./caja.service');

function _alcance(req) {
  return { sucursal_id: req.usuario.sucursal_id, acceso_todas: req.usuario.acceso_todas };
}

async function obtenerActiva(req, res, next) {
  try {
    const sesion = await svc.obtenerActiva(req.usuario.id, req.usuario.sucursal_id);
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
    res.status(201).json({ ok: true, datos: await svc.abrir(req.usuario.id, req.usuario.sucursal_id, monto_apertura) });
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
