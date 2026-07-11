import api from './cliente';

export const getCajaActiva = () =>
  api.get('/caja/activa').then(r => r.data.datos).catch(() => null);

export const getSesiones = () =>
  api.get('/caja').then(r => r.data.datos);

export const getSesion = (id) =>
  api.get(`/caja/${id}`).then(r => r.data.datos);

export const abrirCaja = (monto_apertura) =>
  api.post('/caja/abrir', { monto_apertura }).then(r => r.data.datos);

export const cerrarCaja = (id, denominaciones) =>
  api.post(`/caja/${id}/cerrar`, { denominaciones }).then(r => r.data.datos);

export const getReporte = (id) =>
  api.get(`/caja/${id}/reporte`).then(r => r.data.datos);

export const registrarGasto = (id, datos) =>
  api.post(`/caja/${id}/gastos`, datos).then(r => r.data.datos);

export const getGastos = (id) =>
  api.get(`/caja/${id}/gastos`).then(r => r.data.datos);
