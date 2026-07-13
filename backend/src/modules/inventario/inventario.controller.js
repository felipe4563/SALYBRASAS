const svc = require('./inventario.service');

function _alcance(req) {
  return { sucursal_id: req.usuario.sucursal_id, acceso_todas: req.usuario.acceso_todas };
}

async function listar(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listar({ ...req.query, ..._alcance(req) }) }); }
  catch (err) { next(err); }
}

async function listarPorProducto(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listarPorProducto(req.params.id, _alcance(req)) }); }
  catch (err) { next(err); }
}

async function entrada(req, res, next) {
  try {
    const { producto_id, cantidad } = req.body;
    if (!producto_id || !cantidad) return res.status(400).json({ ok: false, mensaje: 'producto_id y cantidad son requeridos' });
    res.status(201).json({ ok: true, datos: await svc.entrada(req.usuario.id, req.usuario.sucursal_id, req.body) });
  } catch (err) { next(err); }
}

async function salida(req, res, next) {
  try {
    const { producto_id, cantidad } = req.body;
    if (!producto_id || !cantidad) return res.status(400).json({ ok: false, mensaje: 'producto_id y cantidad son requeridos' });
    res.status(201).json({ ok: true, datos: await svc.salida(req.usuario.id, req.usuario.sucursal_id, req.body) });
  } catch (err) { next(err); }
}

async function ajuste(req, res, next) {
  try {
    const { producto_id, cantidad } = req.body;
    if (!producto_id || cantidad === undefined) return res.status(400).json({ ok: false, mensaje: 'producto_id y cantidad son requeridos' });
    res.status(201).json({ ok: true, datos: await svc.ajuste(req.usuario.id, req.usuario.sucursal_id, req.body) });
  } catch (err) { next(err); }
}

module.exports = { listar, listarPorProducto, entrada, salida, ajuste };
