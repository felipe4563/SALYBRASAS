# Progress Ledger — Integración de pagos QR con CodePay

Plan: docs/superpowers/plans/2026-07-14-pagos-qr-codepay.md
Started: 2026-07-14

## Revisión final de rama

Revisor final (opus): "Ready with fixes" — 1 Important real (I1: un pedido podía quedar varado
en pendiente_pago si el cajero cerraba el modal QR con el fondo/la X en vez del botón "Cancelar
cobro QR" — sin ruta de recuperación en la UI, y para una mesa la dejaba ocupada indefinidamente)
+ 3 Minor sin bloquear (QR en venta rápida de mesa no marca la mesa ocupada durante la espera;
el webhook responde 200 incluso ante una excepción inesperada, silenciando el reintento de
CodePay; la columna datos_webhook nunca se persiste). Los Minor heredados de las revisiones por
tarea se confirmaron aptos para enviar tal cual.

Fix aplicado (commit 31b8092): ModalPagoQr.jsx ahora centraliza el cierre en un solo
`handleClose` — si el pago sigue pendiente, cancela primero (cancelarPagoQr) y solo cierra el
modal cuando la cancelación se confirma; el fondo, la X y el botón "Cancelar cobro QR" convergen
en esa misma ruta. El estado fallido/expirado sigue cerrando directo (ya no hay nada que
cancelar). Re-revisado y aprobado: los tres caminos de cierre verificados, guard contra doble
clic durante la cancelación en curso, sin tocar VentasPage.jsx/PedidoPage.jsx (ambos heredan el
fix por compartir el componente). Build limpio.

**Veredicto final: Ready to merge.** 111/111 tests backend, build frontend limpio.

## TODAS LAS TAREAS COMPLETAS
Rama: main (sin worktree separado)
Commits: ae1e41d..31b8092 (5 tareas del plan + 1 fix de revisión de Task 3 + 1 fix de la
revisión final)

## Completadas

- [x] Task 5: Frontend — Modal de cobro QR en Ventas (commit b1d9ff0, review clean — build limpio,
  el revisor re-corrió `npx vite build` él mismo y trazó línea por línea la restricción crítica
  de no duplicar el pedido en el reintento contra el código real del backend. Solo Minor sin
  bloquear, heredados del propio snippet del brief: sin manejo de isError en el polling, y
  "Cambiar método de pago" cierra el modal entero en vez de volver al selector.)

- [x] Task 4: Backend — Webhook /webhooks/codepay (commit ae1b652, review clean — 111/111 tests,
  incluido el revisor re-ejecutando la suite completa él mismo. Solo Minor sin bloquear:
  console.error sin logging estructurado, sin validar shape de req.body antes de delegar
  (aceptable, el service ya es defensivo).)

- [x] Task 3: Backend — ventas.service.js: flujo de cobro con QR (commit 10d0aba, 106/106 tests;
  fix de revisión af... commit 4a6b1eb: condición de carrera real entre webhook y polling
  confirmando el mismo pago simultáneamente — podía duplicar descuento de stock + asiento de
  libro_caja + total_ventas. Cerrado con row lock (SELECT...FOR UPDATE) + re-chequeo de estado
  dentro de la transacción en _confirmarPagoQr/_revertirPagoQr. Test de regresión con dos
  requests HTTP concurrentes reales via Promise.all contra la DB real, verificado que sin el fix
  el test falla (2 asientos) y con el fix pasa (1 asiento). Re-revisado y aprobado. 107/107 tests.)

- [x] Task 1: Backend — Migración, modelo PagoQr, estado pendiente_pago, credenciales (commit
  f1d464d, review clean — 91/91 tests. Solo Minor sin bloquear: estado_previo no tiene un
  assert directo de valor en el test, pero su NOT NULL ya queda ejercitado por la creación.
  Sin secretos reales en ningún archivo commiteado, verificado por el implementador y el revisor.)
- [x] Task 2: Backend — Cliente CodePay (commit 62991f8, review clean — 10/10 tests, fetch
  mockeado en todos los casos, sin llamadas de red reales. Solo Minor sin bloquear (heredados
  del propio texto del brief, no del implementador): un catch muerto en verificarFirmaWebhook
  que nunca se dispara (Buffer.from hex trunca en vez de tirar), y un test de firma inválida
  que en la práctica cae por longitud distinta en vez de contenido distinto de igual longitud.)

## Notas
