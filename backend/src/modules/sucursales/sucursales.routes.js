const { Router } = require('express');
const ctrl = require('./sucursales.controller');
const auth = require('../../middlewares/auth');
const { verificarPermiso } = require('../../middlewares/permisos');

const router = Router();
router.use(auth);

router.get('/', verificarPermiso('sucursales', 'ver'), ctrl.listar);
router.post('/', verificarPermiso('sucursales', 'crear'), ctrl.crear);
router.put('/:id', verificarPermiso('sucursales', 'editar'), ctrl.actualizar);
router.delete('/:id', verificarPermiso('sucursales', 'eliminar'), ctrl.eliminar);

module.exports = router;
