const svc = require('./productos.service');

function _alcance(req) {
  return { sucursal_id: req.usuario.sucursal_id, acceso_todas: req.usuario.acceso_todas, usuario_id: req.usuario.id };
}

async function listarCategorias(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listarCategorias() }); }
  catch (err) { next(err); }
}

async function crearCategoria(req, res, next) {
  try {
    if (!req.body.nombre) return res.status(400).json({ ok: false, mensaje: 'nombre es requerido' });
    res.status(201).json({ ok: true, datos: await svc.crearCategoria(req.body) });
  } catch (err) { next(err); }
}

async function actualizarCategoria(req, res, next) {
  try { res.json({ ok: true, datos: await svc.actualizarCategoria(req.params.id, req.body) }); }
  catch (err) { next(err); }
}

async function eliminarCategoria(req, res, next) {
  try { await svc.eliminarCategoria(req.params.id); res.json({ ok: true, datos: null }); }
  catch (err) { next(err); }
}

async function listarProductos(req, res, next) {
  try { res.json({ ok: true, datos: await svc.listarProductos(req.query, _alcance(req)) }); }
  catch (err) { next(err); }
}

async function obtenerProducto(req, res, next) {
  try { res.json({ ok: true, datos: await svc.obtenerProducto(req.params.id, _alcance(req)) }); }
  catch (err) { next(err); }
}

async function crearProducto(req, res, next) {
  try {
    const { categoria_id, nombre, precio } = req.body;
    if (!categoria_id || !nombre || precio === undefined) {
      return res.status(400).json({ ok: false, mensaje: 'categoria_id, nombre y precio son requeridos' });
    }
    res.status(201).json({ ok: true, datos: await svc.crearProducto(req.body, _alcance(req)) });
  } catch (err) { next(err); }
}

async function actualizarProducto(req, res, next) {
  try { res.json({ ok: true, datos: await svc.actualizarProducto(req.params.id, req.body) }); }
  catch (err) { next(err); }
}

async function eliminarProducto(req, res, next) {
  try { await svc.eliminarProducto(req.params.id); res.json({ ok: true, datos: null }); }
  catch (err) { next(err); }
}

module.exports = { listarCategorias, crearCategoria, actualizarCategoria, eliminarCategoria, listarProductos, obtenerProducto, crearProducto, actualizarProducto, eliminarProducto };
