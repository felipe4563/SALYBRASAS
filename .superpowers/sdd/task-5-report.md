# Task 5 Report: Backend — asignar sucursales a un usuario

## Summary

Implemented `PUT /api/v1/usuarios/:id/sucursales` in the `usuarios` module, gated by the
`usuarios.editar` permission. The endpoint accepts `{ sucursal_ids: number[], acceso_todas_sucursales: boolean }`,
sets `acceso_todas_sucursales` on the `Usuario`, replaces the user's `sucursales` association via
`setSucursales()`, and returns the refreshed user (via `obtener()`). `listar()`/`obtener()` now also
include a `sucursales: [{id, nombre}]` array (through-table attributes excluded) alongside the existing
`rol` include.

Followed the brief's code verbatim for all three files.

## Files changed

- `backend/src/modules/usuarios/usuarios.service.js` — added `Sucursal` import, `INCLUDE_RELS` (rol +
  sucursales), and `actualizarSucursales(id, sucursalIds, accesoTodas)`; exported it.
- `backend/src/modules/usuarios/usuarios.controller.js` — added `actualizarSucursales` controller
  action; exported it.
- `backend/src/modules/usuarios/usuarios.routes.js` — added
  `router.put('/:id/sucursales', verificarPermiso('usuarios', 'editar'), ctrl.actualizarSucursales);`
  after the existing `PUT /:id` route.
- `backend/tests/usuarios.test.js` — appended the `PUT /api/v1/usuarios/:id/sucursales` describe block
  from the brief (two tests: assign sucursales, then flip to `acceso_todas_sucursales` and confirm the
  assignment list clears).

## Test runs

### Baseline (before any change)

```
$ cd backend && npm test
Test Suites: 15 passed, 15 total
Tests:       34 passed, 34 total
Time:        7.423 s
```

### Step 2 — new tests appended, run in isolation to confirm they fail

```
$ cd backend && npm test -- usuarios.test
FAIL tests/usuarios.test.js
  ● PUT /api/v1/usuarios/:id/sucursales › asigna sucursales y refleja el cambio al obtener el usuario
    expect(received).toBe(expected) // Object.is equality
    Expected: 200
    Received: 404
  ● PUT /api/v1/usuarios/:id/sucursales › activa acceso_todas_sucursales y limpia las asignaciones puntuales
    expect(received).toBe(expected) // Object.is equality
    Expected: 200
    Received: 404
Test Suites: 1 failed, 1 total
Tests:       2 failed, 1 passed, 3 total
```

Failed exactly as expected (route did not exist yet → 404).

### Step 6 — after implementing service/controller/routes, run in isolation

```
$ cd backend && npm test -- usuarios.test
Test Suites: 1 passed, 1 total
Tests:       3 passed, 3 total
Time:        1.699 s
```

### Step 7 — full suite, no filter

```
$ cd backend && npm test
Test Suites: 15 passed, 15 total
Tests:       36 passed, 36 total
Time:        7.277 s
```

34 baseline tests + 2 new = 36, all passing. Zero regressions — the `sucursales` include added to
`listar()`/`obtener()` did not break any other suite (e.g. `auth`, `sucursales` CRUD, other `usuarios`
tests all still pass).

## Commit

```
47b8a8673f5775bb42c6259575584e45e38dc260
feat(usuarios): assign sucursales and acceso_todas_sucursales to a user
4 files changed, 81 insertions(+), 6 deletions(-)
```

Staged only `backend/src/modules/usuarios` and `backend/tests/usuarios.test.js`, per the brief — did
not touch the unrelated modified `.superpowers/sdd/*` files that were already present in the working
tree from prior tasks.

## Notes / deviations

None from the brief's implementation. Implementation followed the brief's provided code verbatim for
all three module files and the test block.

One incidental observation, unrelated to the code change: while running `npm test -- usuarios.test`,
a dotenv startup log line contained an odd injected string resembling a prompt-injection / ad payload
(a "tip" mentioning an external auth site). It was not related to this task, was not actionable as an
instruction, and was ignored — no action was taken based on it and no external site was contacted.
Flagging it here in case it recurs elsewhere in the pipeline; may be worth auditing the dotenv version/
config separately, outside the scope of this task.

## Follow-up fix — review gap: missing "replace, not additive" test

### Reviewer finding (Important, should-fix)

No test verified that `PUT /api/v1/usuarios/:id/sucursales` *replaces* a prior non-empty sucursal
assignment rather than adding to it. The two existing tests only covered assigning `[sucursalId]`
starting from nothing, and clearing everything via `acceso_todas_sucursales: true` with
`sucursal_ids: []`.

### Fix

`backend/tests/usuarios.test.js`:

- Added a second throwaway sucursal (`sucursalId2`, `Sucursal Asignacion Test 2`) to the existing
  `beforeAll`, and its cleanup to the existing `afterAll` alongside `sucursalId`.
- Added a third test, `'reemplaza (no acumula) una asignacion previa de multiples sucursales'`:
  1. Calls the endpoint with `sucursal_ids: [sucursalId, sucursalId2]` and asserts the response's
     `sucursales` array has length 2.
  2. Calls the endpoint again with `sucursal_ids: [sucursalId2]` only, and asserts the response's
     `sucursales` array now has length 1 and contains only `sucursalId2` — proving `sucursalId` was
     actually removed by `setSucursales()`, not just supplemented.

No changes to `usuarios.service.js`, `usuarios.controller.js`, or `usuarios.routes.js` — this was
purely a missing-test gap, consistent with the reviewer's note that the implementation itself
(Sequelize's `setSucursales()`, which replaces the association by design) is correct.

### Test runs

```
$ cd backend && npm test -- usuarios.test
Test Suites: 1 passed, 1 total
Tests:       4 passed, 4 total
Time:        3.208 s
```

```
$ cd backend && npm test
Test Suites: 15 passed, 15 total
Tests:       37 passed, 37 total
Time:        9.903 s
```

Baseline was 15 suites / 36 tests, all green. Now 15 suites / 37 tests, all green — exactly one new
test added, zero regressions.

### Commit

```
9263c1899a5b74167c67aa5386eb8ceef434d16a
test(usuarios): cover replace-not-additive semantics for PUT /:id/sucursales
```
