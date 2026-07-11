const { Router } = require('express');
const { login, refresh, yo } = require('./auth.controller');
const auth = require('../../middlewares/auth');

const router = Router();

router.post('/login', login);
router.post('/refresh', refresh);
router.get('/yo', auth, yo);

module.exports = router;
