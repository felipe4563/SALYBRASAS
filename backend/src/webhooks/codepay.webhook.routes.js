const { Router } = require('express');
const codepayClient = require('../integrations/codepay/codepay.client');
const ventasService = require('../modules/ventas/ventas.service');

const router = Router();

router.post('/codepay', async (req, res) => {
  const firmaHeader = req.headers['x-codepay-signature'];
  const firmaValida = codepayClient.verificarFirmaWebhook(req.rawBody, firmaHeader);
  if (!firmaValida) {
    // Diagnóstico temporal (no expone el secreto ni la firma completa) —
    // quitar una vez identificada la causa del 401 en producción.
    console.error('[codepay webhook] firma inválida', {
      headers: Object.keys(req.headers),
      firmaHeaderPresente: !!firmaHeader,
      firmaHeaderLongitud: firmaHeader ? firmaHeader.length : 0,
      firmaHeaderMuestra: firmaHeader ? `${firmaHeader.slice(0, 6)}...${firmaHeader.slice(-6)}` : null,
      esHexValido: firmaHeader ? /^[0-9a-fA-F]+$/.test(firmaHeader) : false,
      rawBodyPresente: !!req.rawBody,
      rawBodyLongitud: req.rawBody ? req.rawBody.length : 0,
      contentType: req.headers['content-type'],
    });
    return res.status(401).json({ ok: false, mensaje: 'Firma inválida' });
  }

  try {
    await ventasService.procesarWebhookPagoQr(req.body);
  } catch (err) {
    console.error('Error procesando webhook de CodePay:', err);
  }

  res.status(200).json({ ok: true });
});

module.exports = router;
