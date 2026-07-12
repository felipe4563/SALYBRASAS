# Task 3 Report: Backend — login en dos pasos y sesión con sucursal activa

## Summary

Implemented two-step login for users with multiple sucursales (or
`acceso_todas_sucursales`), and made the JWT/`req.usuario` sucursal-aware
for all authenticated routes.

## Files changed

- `backend/src/modules/auth/auth.service.js` — rewritten. `login()` now
  looks up the user with `Rol`/`Permiso`/`Sucursal` includes, computes the
  list of available sucursales (prepending `{id: null, nombre: 'Todas las
  sucursales'}` when `acceso_todas_sucursales` is set), and either logs in
  directly (exactly one sucursal available) or returns
  `{ requiere_sucursal: true, pre_token, sucursales }`. New
  `loginConSucursal(pre_token, sucursal_id)` verifies the short-lived
  (`5m`) pre-login token, validates the chosen `sucursal_id` belongs to
  the user (or is `null` and the user has `acceso_todas_sucursales`), and
  issues the real session via a shared `emitirSesion()` helper that
  includes `usuario.sucursal_activa = { id, nombre }`. `refresh()` now
  carries `sucursal_id` through into the reissued token.
- `backend/src/modules/auth/auth.controller.js` — added `loginSucursal`
  controller (validates `pre_token` presence, delegates to
  `authService.loginConSucursal`), exported alongside existing handlers.
- `backend/src/modules/auth/auth.routes.js` — added
  `router.post('/login/sucursal', loginSucursal)`.
- `backend/src/middlewares/auth.js` — `req.usuario` now also carries
  `sucursal_id` (number or `null`, read from the JWT payload) and
  `acceso_todas` (boolean, `true` when `sucursal_id` is `null`).
- `backend/tests/auth-sucursales.test.js` — new test file, exactly as
  specified in the brief (verbatim).

All code matches the brief's Step 3–6 snippets verbatim; no deviations.

## Test commands and output

### Baseline (before starting)

```
cd backend && npm test
Test Suites: 13 passed, 13 total
Tests:       23 passed, 23 total
```
Confirms Task 2's seed changes left the suite green (23 tests, not 24 —
noted as a minor discrepancy from the stated baseline but still fully
green, so proceeded).

### Step 2: failing run (before implementation)

```
cd backend && npm test -- auth-sucursales
```
Result: `1 failed, 1 total` / `5 failed, 5 total` — every new test failed
as expected:
- `requiere_sucursal` → `undefined` (old single-step shape still active)
- `POST /login/sucursal` → 404 (route didn't exist yet, causing the
  cascading `TypeError: Cannot read properties of undefined` in later
  assertions)
- admin's `usuario.sucursal_activa` → undefined

This confirms the tests were correctly exercising the not-yet-built
behavior.

### Step 7: passing run (new + pre-existing auth suite)

```
cd backend && npm test -- auth-sucursales auth.test.js
Test Suites: 2 passed, 2 total
Tests:       10 passed, 10 total
```
All 5 new tests plus the 5 pre-existing `auth.test.js` tests pass.

### Step 8: full suite regression check

```
cd backend && npm test
Test Suites: 14 passed, 14 total
Tests:       28 passed, 28 total
```
14 suites (13 pre-existing + the new `auth-sucursales` suite), 28 tests
(23 pre-existing + 5 new). Zero regressions — every other test file's
`beforeAll` login (via `admin@restaurante.com`, who has exactly one
sucursal) continues to hit the single-step path unchanged.

## Operational note

Encountered stray `node.exe` processes left over from earlier background
`npm test` invocations in this session that were holding the DB
connection pool open (jest's known "did not exit" issue on this repo,
pre-existing and unrelated to my changes). Killed them with `taskkill
//F //IM node.exe` between runs when a test invocation hung/timed out;
after that, all runs completed normally in ~2-6s. Not a code issue —
purely a background-process cleanup artifact of the session's tool
environment.

## Commit

`2689d5e` — "feat(auth): two-step login and sucursal-aware sessions"

Files committed:
- `backend/src/middlewares/auth.js`
- `backend/src/modules/auth/auth.controller.js`
- `backend/src/modules/auth/auth.routes.js`
- `backend/src/modules/auth/auth.service.js`
- `backend/tests/auth-sucursales.test.js` (new)

(Unrelated pre-existing unstaged changes in `.superpowers/sdd/*.md` were
left untouched, as they are outside this task's scope.)

## Fix report: code review findings (2026-07-12)

The task reviewer found a critical privilege-escalation hole plus a
missing test-coverage gap in the two-step login work above. Both are
fixed below.

### Critical fix: pre_token accepted as a real access token

**Root cause:** `pre_token` (`{ id, tipo: 'pre_login' }`) is signed with
the same `JWT_SECRET` as real access tokens, and `auth` middleware
verified any Bearer token against `JWT_SECRET` without checking `tipo`.
Since `pre_token` has no `sucursal_id`, the middleware computed
`sucursalId = null` → `acceso_todas: true`, so a multi-sucursal user
(without `acceso_todas_sucursales`) could replay their `pre_token` from
the `requiere_sucursal` response as `Authorization: Bearer <pre_token>`
on any protected route (e.g. `/auth/yo`) and get `acceso_todas: true`
for up to 5 minutes — a privilege escalation.

**Fix:** `backend/src/middlewares/auth.js` — after `jwt.verify`
succeeds, reject the request with the existing 401 shape
(`{ ok: false, mensaje: 'Token inválido o expirado' }`) if
`payload.tipo === 'pre_login'`:

```js
const payload = jwt.verify(token, process.env.JWT_SECRET);

if (payload.tipo === 'pre_login') {
  return res.status(401).json({ ok: false, mensaje: 'Token inválido o expirado' });
}
```

**New regression test** in `backend/tests/auth-sucursales.test.js`:
`'rechaza el pre_token como token de acceso en una ruta protegida'` —
logs in as the multi-sucursal test user, takes `pre_token` from the
`requiere_sucursal` response, calls `GET /api/v1/auth/yo` with it, and
asserts `res.status === 401`.

### Important fix: no coverage for sucursal_id surviving `/auth/refresh`

`refresh()` in `auth.service.js` already carried `payload.sucursal_id ??
null` into the reissued token — that logic was untouched, it just had no
test. Added `'el refresh conserva la sucursal_id elegida en el login de
dos pasos'` to `backend/tests/auth-sucursales.test.js`: completes a
two-step login for the multi-sucursal test user to get a real
`token`/`refresh_token` pair with a non-null `sucursal_id`, calls `POST
/api/v1/auth/refresh` with the `refresh_token`, then calls `GET
/api/v1/auth/yo` with the new `token` and asserts `sucursal_id` still
matches the sucursal chosen at login.

### Test commands and output

Targeted run:

```
cd backend && npm test -- auth-sucursales auth.test.js
Test Suites: 2 passed, 2 total
Tests:       12 passed, 12 total
Time:        2.998 s
```

Full suite:

```
cd backend && npm test
Test Suites: 14 passed, 14 total
Tests:       30 passed, 30 total
Time:        8.977 s
```

14 suites (unchanged), 30 tests (28 + 2 new regression tests). Zero
regressions — every other test file's `beforeAll` login continues to
issue full tokens (not `pre_login` tokens), so the middleware change is
transparent to them.

### Files changed in this fix

- `backend/src/middlewares/auth.js` — reject `tipo === 'pre_login'`
  tokens with 401.
- `backend/tests/auth-sucursales.test.js` — two new tests as described
  above.

### Commit

See commit following this report entry (new commit, not amended).
