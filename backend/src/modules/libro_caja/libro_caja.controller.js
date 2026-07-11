const svc = require('./libro_caja.service');

async function listar(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listar(req.query) }); }
  catch (err) { next(err); }
}

async function crear(req, res, next) {
  try {
    const { tipo, concepto, monto } = req.body;
    if (!tipo || !concepto || monto === undefined) {
      return res.status(400).json({ ok: false, mensaje: 'tipo, concepto y monto son requeridos' });
    }
    res.status(201).json({ ok: true, datos: await svc.crear(req.usuario.id, req.body) });
  } catch (err) { next(err); }
}

module.exports = { listar, crear };
