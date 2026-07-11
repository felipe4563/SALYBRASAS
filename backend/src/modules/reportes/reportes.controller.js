const svc = require('./reportes.service');

async function getVentas(req, res, next) {
  try { res.json({ ok: true, datos: await svc.ventas(req.query) }); } catch (e) { next(e); }
}

async function getInventario(req, res, next) {
  try { res.json({ ok: true, datos: await svc.inventario(req.query) }); } catch (e) { next(e); }
}

async function getCompras(req, res, next) {
  try { res.json({ ok: true, datos: await svc.compras(req.query) }); } catch (e) { next(e); }
}

async function getCaja(req, res, next) {
  try { res.json({ ok: true, datos: await svc.caja(req.query) }); } catch (e) { next(e); }
}

module.exports = { getVentas, getInventario, getCompras, getCaja };
