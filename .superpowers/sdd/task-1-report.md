# Task 1 Report: Migración, modelo PagoQr, estado pendiente_pago, credenciales CodePay

## Status: DONE

## Commit
`f1d464d` — feat(pagos-qr): tabla pagos_qr, modelo PagoQr y estado pendiente_pago en Pedido

## What was done

1. **Migration** (`backend/database/migrations/015_pagos_qr.sql`): created `pagos_qr` table
   (FKs to `pedidos` and `sucursales`, `estado` ENUM, `datos_webhook` JSON, timestamps) and
   altered `pedidos.estado` ENUM to add `'pendiente_pago'`. Applied directly against the local
   dev DB (`mysql -u root bd_restaurante < database/migrations/015_pagos_qr.sql`) with no errors —
   the `sql_mode` workaround mentioned in the brief was not needed this time.
   Verified via `SHOW CREATE TABLE pagos_qr` and `SHOW COLUMNS FROM pedidos LIKE 'estado'`.

2. **Model** (`backend/src/models/PagoQr.js`): created verbatim per brief, following the
   `Caja.js` pattern (tableName `pagos_qr`, `creado_en`/`actualizado_en` timestamps).

3. **Pedido model** (`backend/src/models/Pedido.js`): updated `estado` ENUM to include
   `'pendiente_pago'`.

4. **Model registry** (`backend/src/models/index.js`): added `require('./PagoQr')`, the three
   associations (`Pedido.hasMany(PagoQr, { as: 'pagosQr' })`, `PagoQr.belongsTo(Pedido, { as:
   'pedido' })`, `PagoQr.belongsTo(Sucursal, { as: 'sucursal' })`) placed after the "Cajas
   físicas" block, and added `PagoQr` to `module.exports`.

5. **Environment variables**:
   - `backend/.env.example` (committed): appended the 7 `CODEPAY_*` keys with empty/placeholder
     values (`CODEPAY_SANDBOX=true`, `CODEPAY_API_URL=...`, rest blank).
   - `backend/.env` (gitignored, NOT committed): appended the same 7 keys with the real values
     provided directly by the controller in chat. Confirmed via `git diff --cached | grep` that
     none of the real secret strings appear anywhere in the staged/committed diff.

6. **Test** (`backend/tests/pagos_qr.model.test.js`): created verbatim per brief.

## Test results

- `cd backend && npm test -- pagos_qr.model.test.js` → **3/3 PASS**.
- Full suite sanity check: `cd backend && npm test` → **19 suites / 91 tests, all PASS**
  (nothing else broke from the ENUM change or new model/associations).

## Commit contents (verified before commit)

Only the files listed in the brief were staged and committed:
`backend/database/migrations/015_pagos_qr.sql`, `backend/src/models/PagoQr.js`,
`backend/src/models/Pedido.js`, `backend/src/models/index.js`, `backend/.env.example`,
`backend/tests/pagos_qr.model.test.js`. `backend/.env` was left untouched by git (gitignored,
holds the real CodePay credentials the controller shared in chat).
Pre-existing unrelated modifications/deletions to `.superpowers/sdd/*.md` files already present
in the working tree at the start of this task were left unstaged/untouched — out of scope.

## Concerns

None. All steps completed as specified, migration applied cleanly, tests green, no secrets in
any committed file.

Note: this file previously held a report for an unrelated earlier "Task 1" (Caja model /
migration 014). That content has been superseded here since it belonged to a different phase's
task numbering and this conversation's task-1-brief.md is the PagoQr/CodePay one.
