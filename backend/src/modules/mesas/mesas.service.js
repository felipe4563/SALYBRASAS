const { Area, Mesa } = require('../../models');

// --- Áreas ---

async function listarAreas() {
  return Area.findAll({ include: [{ model: Mesa, as: 'mesas' }], order: [['nombre', 'ASC']] });
}

async function crearArea({ nombre }) {
  return Area.create({ nombre });
}

async function actualizarArea(id, { nombre }) {
  const area = await Area.findByPk(id);
  if (!area) throw Object.assign(new Error('Área no encontrada'), { status: 404 });
  await area.update({ nombre });
  return area;
}

async function eliminarArea(id) {
  const area = await Area.findByPk(id);
  if (!area) throw Object.assign(new Error('Área no encontrada'), { status: 404 });
  const mesas = await Mesa.count({ where: { area_id: id } });
  if (mesas > 0) throw Object.assign(new Error('El área tiene mesas asignadas'), { status: 409 });
  await area.destroy();
}

// --- Mesas ---

async function listarMesas(area_id) {
  const where = area_id ? { area_id } : {};
  return Mesa.findAll({ where, include: [{ model: Area, as: 'area', attributes: ['id', 'nombre'] }], order: [['nombre', 'ASC']] });
}

async function obtenerMesa(id) {
  const mesa = await Mesa.findByPk(id, { include: [{ model: Area, as: 'area', attributes: ['id', 'nombre'] }] });
  if (!mesa) throw Object.assign(new Error('Mesa no encontrada'), { status: 404 });
  return mesa;
}

async function crearMesa({ area_id, nombre, asientos = 4, pos_x = 0, pos_y = 0 }) {
  const area = await Area.findByPk(area_id);
  if (!area) throw Object.assign(new Error('Área no encontrada'), { status: 404 });
  return Mesa.create({ area_id, nombre, asientos, pos_x, pos_y });
}

async function actualizarMesa(id, datos) {
  const mesa = await Mesa.findByPk(id);
  if (!mesa) throw Object.assign(new Error('Mesa no encontrada'), { status: 404 });
  await mesa.update(datos);
  return obtenerMesa(id);
}

async function actualizarPosicion(id, { pos_x, pos_y }) {
  const mesa = await Mesa.findByPk(id);
  if (!mesa) throw Object.assign(new Error('Mesa no encontrada'), { status: 404 });
  await mesa.update({ pos_x, pos_y });
  return mesa;
}

async function eliminarMesa(id) {
  const mesa = await Mesa.findByPk(id);
  if (!mesa) throw Object.assign(new Error('Mesa no encontrada'), { status: 404 });
  if (mesa.estado === 'ocupada') throw Object.assign(new Error('No se puede eliminar una mesa ocupada'), { status: 409 });
  await mesa.destroy();
}

module.exports = { listarAreas, crearArea, actualizarArea, eliminarArea, listarMesas, obtenerMesa, crearMesa, actualizarMesa, actualizarPosicion, eliminarMesa };
