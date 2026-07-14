# Task 5 Report: Frontend — modal de cobro QR en Ventas

## Estado: DONE

## Summary

Implemented the CodePay QR payment frontend per `.superpowers/sdd/task-5-brief.md`, verbatim as specified.

## Files created

- `frontend/src/api/pagosQr.js` — `consultarEstadoPagoQr(pedidoId)` (GET `/ventas/:id/pago-qr/estado`) and `cancelarPagoQr(pedidoId)` (POST `/ventas/:id/pago-qr/cancelar`).
- `frontend/src/pages/ventas/components/ModalPagoQr.jsx` — reusable modal. Shows QR image + countdown while `estado === 'pendiente'`, polls `consultarEstadoPagoQr` via TanStack Query v5 `refetchInterval: (query) => ...` (3s while pendiente, stops otherwise), calls `onCompletado(pedido)` when `estado === 'completado'`, and shows a "Cambiar método de pago" / "Reintentar" pair of buttons when `estado` is `'fallido'` or `'expirado'`. "Cancelar cobro QR" button calls `cancelarPagoQr` then `onClose()`.

## Files modified

- `frontend/src/pages/ventas/VentasPage.jsx`
  - Import: added `cobrarVenta` to the `../../api/ventas` import, and `ModalPagoQr` from `./components/ModalPagoQr`.
  - `ModalCobrar` now has two separate mutations:
    - `iniciar` — calls `crearVentaCompleta(...)` (creates the Pedido + items). Runs only once, on first "Confirmar cobro" click. On success, if `resultado.pago_qr` is present, stores `{ pedidoId: resultado.pedido.id, pagoQr: resultado.pago_qr }` in `pagoQrEstado` state and renders `ModalPagoQr`; otherwise calls `onExito()` directly (non-QR methods).
    - `reintentar` — calls `cobrarVenta(pagoQrEstado.pedidoId, { metodo_pago: 'qr', monto_recibido: total })` against the **already-existing** pedido. Never calls `crearVentaCompleta` again, so no duplicate pedido/items are created on retry. On success it replaces `pagoQrEstado` with the new `pago_qr` (new QR code + new expiry), re-rendering `ModalPagoQr`.
  - When `pagoQrEstado` is set, `ModalCobrar` renders `<ModalPagoQr onReintentar={() => reintentar.mutate()} onCompletado={() => onExito()} .../>` instead of the payment-method form.

- `frontend/src/pages/ventas/PedidoPage.jsx`
  - Import: added `ModalPagoQr` from `./components/ModalPagoQr` (the `cobrarVenta`/`cancelarVenta` imports from `api/ventas` were already present, unchanged).
  - `ModalCobrar` (used to cobrar an existing mesa/llevar pedido) has a single `cobrar` mutation calling `cobrarVenta(pedidoId, { metodo_pago: metodo, monto_recibido: total })`. On success, if `resultado.pago_qr` is present, stores it in `pagoQr` state and renders `ModalPagoQr`; otherwise calls `onExito()`.
  - Here "Reintentar" is wired to `() => cobrar.mutate()` — since `cobrar`'s `mutationFn` already targets the existing `pedidoId` via `cobrarVenta` (never creates a new pedido), this is safe to reuse for retries, unlike `VentasPage.jsx` where the first mutation calls `crearVentaCompleta` and therefore must not be reused on retry.
  - `ModalCancelar` and the rest of the file are unchanged.

## Design-constraint verification (the critical part)

Traced both flows explicitly to confirm no duplicate-pedido risk:

1. **VentasPage.jsx (quick sale, `crearVentaCompleta`)**: first click → `iniciar.mutate()` → `crearVentaCompleta` → pedido created once. If method is QR and it fails/expires, "Reintentar" calls `reintentar.mutate()` → `cobrarVenta(pagoQrEstado.pedidoId, ...)`, which only re-attempts payment on the pedido that already exists (confirmed backend `cobrarVenta`/`crearCompleta` return `{ pedido: await obtener(pedidoId), pago_qr }` — same pedido id, no new insert). `iniciar` (the `crearVentaCompleta` mutation) is never invoked again after the first success.
2. **PedidoPage.jsx (cobrar existing mesa/llevar pedido, `cobrarVenta`)**: the pedido already exists before the modal ever opens (it's `pedidoId` from the route). Both the initial "Confirmar cobro" and every "Reintentar" click call the same `cobrar` mutation, i.e. `cobrarVenta(pedidoId, ...)` — never a create-pedido call. So repeated retries are safe by construction.

Backend response shapes (checked in `backend/src/modules/ventas/ventas.service.js`):
- `iniciarPagoQr` returns `{ qr_code, tx_id, expires_at, monto_neto, comision, monto_total }` — matches `ModalPagoQr`'s use of `pagoQr.qr_code`, `pagoQr.expires_at`, `pagoQr.monto_total ?? pagoQr.monto_neto`, and the `pago-qr-estado` query key's use of `pagoQr.tx_id`.
- `cobrar`/`crearCompleta` (QR branch) return `{ pedido: await obtener(pedido_id), pago_qr }` — matches `resultado.pedido.id` / `resultado.pago_qr` usage in both pages.
- `consultarEstadoPagoQr` returns `{ estado, pedido }` with `estado` one of `'pendiente' | 'completado' | 'fallido' | 'expirado'` — matches `ModalPagoQr`'s `estadoQuery.data?.estado` branches and the `onCompletado(estadoQuery.data.pedido)` call.

## Verification

- `cd frontend && npx vite build` — succeeded (`✓ built in 8.55s`), no import or JSX errors. Only pre-existing warning about a >500kB chunk (unrelated to this change).
- No frontend test runner exists in this repo; verification was via build + manual trace of both QR success and failure/retry code paths in both pages, and cross-checking the response shapes against the actual (already-committed) backend service code.

## Commit

```
git add frontend/src/api/pagosQr.js frontend/src/pages/ventas/components/ModalPagoQr.jsx frontend/src/pages/ventas/VentasPage.jsx frontend/src/pages/ventas/PedidoPage.jsx
git commit -m "feat(pagos-qr): modal de cobro por QR (CodePay) en Ventas, con polling y reintento"
```

Only these 4 files were staged/committed; unrelated pending changes under `.superpowers/sdd/*.md` (pre-existing in the working tree from earlier tasks) were left untouched.

## Dudas / inquietudes

- Not verified in a real browser against a live CodePay sandbox (no dev server run); verification was static build + manual code trace, per the constraints given for this task.

## Fix: stranded pendiente_pago order on modal dismiss

**Bug (found in final whole-branch review):** `ModalPagoQr.jsx` passed `onClose={onClose}` directly to the shared `Modal` component. `Modal`'s backdrop-click and "X" button call `onClose` unconditionally, bypassing the "Cancelar cobro QR" button's `cancelar.mutate()` call. If a cashier dismissed the QR modal that way while `estado === 'pendiente'`, the modal unmounted (stopping the `consultarEstadoPagoQr` poll) with the backend `Pedido` left stuck in `'pendiente_pago'`. Neither `cobrar()` (needs `'pendiente'`/`'listo'`) nor `cancelar()` (needs `'pendiente'`) could recover it from the UI afterward — both would 409 — and for a `mesa` order the table stayed permanently unusable until a manual DB fix.

**Fix:** Added a single `handleClose` function in `ModalPagoQr.jsx`:

```jsx
const handleClose = () => {
  if (estado === 'pendiente') {
    if (!cancelar.isPending) cancelar.mutate();
    return;
  }
  onClose();
};
```

- `<Modal titulo="Cobro por QR" onClose={handleClose} ancho="max-w-sm">` — backdrop click and the "X" button (both go through `Modal`'s `onClose` prop) now route through `handleClose`.
- The "Cancelar cobro QR" button's `onClick` now calls `handleClose` instead of `cancelar.mutate()` directly, so there is exactly one dismissal path while pending.
- The `cancelar` mutation itself is unchanged — `onSuccess: () => onClose()` still closes the modal only after the server confirms the pendiente_pago pedido was reverted.
- The `(estado === 'fallido' || estado === 'expirado')` branch's "Cambiar método de pago" button still calls `onClose` directly (untouched), since by that point the backend has already reverted the pedido via `_revertirPagoQr` — there is nothing left to cancel.

**Manual trace:**
1. `estado === 'pendiente'`, dismiss via backdrop or "X" -> `Modal` invokes `onClose` prop, which is now `handleClose` -> `estado === 'pendiente'` branch taken -> `cancelar.mutate()` fires `cancelarPagoQr(pedidoId)` -> only on that request's success does `cancelar`'s `onSuccess` call the real `onClose()`, closing the modal. No stranded `pendiente_pago` pedido.
2. `estado === 'fallido'` or `'expirado'`, dismiss via backdrop or "X" -> `handleClose` runs, `estado !== 'pendiente'` -> falls through directly to `onClose()`, closing immediately with no `cancelarPagoQr` call — avoids a spurious cancel against a pedido that was already reverted server-side (which would 404/409 since there's no longer a live `PagoQr` row in `'pendiente'`).
3. `estado === 'pendiente'`, click "Cancelar cobro QR" -> `onClick={handleClose}` -> same `estado === 'pendiente'` branch as case 1 -> `cancelar.mutate()` -> identical behavior to before the fix, now just routed through `handleClose`. The button is also `disabled={cancelar.isPending}` as before, preventing double-submission.

Verified with `cd frontend && npx vite build` — build succeeded (no errors, only the pre-existing large-chunk warning).
