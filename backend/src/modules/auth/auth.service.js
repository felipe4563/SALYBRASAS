const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { Usuario, Rol, Permiso } = require('../../models');

async function login(email, contrasena) {
  const usuario = await Usuario.findOne({
    where: { email, activo: 1 },
    include: [{ model: Rol, as: 'rol', include: [{ model: Permiso, as: 'permisos' }] }],
  });

  if (!usuario) throw Object.assign(new Error('Credenciales inválidas'), { status: 401 });

  const valida = await bcrypt.compare(contrasena, usuario.contrasena);
  if (!valida) throw Object.assign(new Error('Credenciales inválidas'), { status: 401 });

  const payload = { id: usuario.id };
  const token = jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN });
  const refresh_token = jwt.sign(payload, process.env.JWT_REFRESH_SECRET, { expiresIn: process.env.JWT_REFRESH_EXPIRES_IN });

  return {
    token,
    refresh_token,
    usuario: {
      id: usuario.id,
      nombre: usuario.nombre,
      email: usuario.email,
      rol: usuario.rol.nombre,
      permisos: usuario.rol.permisos.map(p => `${p.modulo}.${p.accion}`),
    },
  };
}

async function refresh(refresh_token) {
  let payload;
  try {
    payload = jwt.verify(refresh_token, process.env.JWT_REFRESH_SECRET);
  } catch {
    throw Object.assign(new Error('Refresh token inválido'), { status: 401 });
  }
  const usuario = await Usuario.findOne({ where: { id: payload.id, activo: 1 } });
  if (!usuario) throw Object.assign(new Error('Usuario inactivo o no existe'), { status: 401 });
  const token = jwt.sign({ id: payload.id }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN });
  return { token };
}

module.exports = { login, refresh };
