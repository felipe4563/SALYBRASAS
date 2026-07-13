import api from './cliente';

export const getCajaActiva = (sucursal_id) =>
  api.get('/caja/activa', { params: sucursal_id ? { sucursal_id } : {} }).then(r => r.data.datos).catch(() => null);

export const getSesiones = () =>
  api.get('/caja').then(r => r.data.datos);

export const getSesion = (id) =>
  api.get(`/caja/${id}`).then(r => r.data.datos);

export const abrirCaja = (monto_apertura, sucursal_id) =>
  api.post('/caja/abrir', { monto_apertura, ...(sucursal_id ? { sucursal_id } : {}) }).then(r => r.data.datos);

export const cerrarCaja = (id, denominaciones) =>
  api.post(`/caja/${id}/cerrar`, { denominaciones }).then(r => r.data.datos);

export const getReporte = (id) =>
  api.get(`/caja/${id}/reporte`).then(r => r.data.datos);

export const registrarGasto = (id, datos) =>
  api.post(`/caja/${id}/gastos`, datos).then(r => r.data.datos);

export const getGastos = (id) =>
  api.get(`/caja/${id}/gastos`).then(r => r.data.datos);
