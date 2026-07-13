### Task 3: Backend — Productos: sucursal explícita para stock inicial

**Estado:** DONE

**Commit:** `c5accdd` — fix(productos): exige sucursal_id para stock inicial de usuarios acceso-todas en vez de descartarlo

**Archivos modificados:**
- `backend/src/modules/productos/productos.service.js` — `crearProducto` ahora acepta `sucursal_id` en el payload; si `alcance.acceso_todas` es true y viene `stock`, usa `sucursal_id` como destino y lanza 400 (`sucursal_id es requerido para asignar stock inicial`) si no viene. Si `stock` no viene, no exige nada.
- `backend/tests/productos.test.js` — agregado import de `bcryptjs` (no `bcrypt`; el proyecto usa el paquete `bcryptjs` en `auth.service.js`, `usuarios.service.js`, `perfil.controller.js`) y de `Categoria`, `Usuario`, `Rol`, `Producto` (no estaban importados en el archivo, solo `Sucursal` y `ProductoStockSucursal` lo estaban). Se agregó el describe `Productos — stock inicial con acceso a todas las sucursales` tal como especifica el brief.

**Nota sobre el brief:** el ejemplo de código del brief usa `require('bcrypt')`; el paquete real instalado en `backend/package.json` es `bcryptjs`. Usé `bcryptjs` para que el test corra (confirmado con `Cannot find module 'bcrypt'` al correr con el import original).

**TDD:**
1. Tests agregados → corridos → 2 tests fallaron como se esperaba (400 esperado, recibido 201; y `stock` era null porque no se creó fila en `producto_stock_sucursal`), 6 pasaron (tests preexistentes no afectados).
2. Implementado el cambio en `crearProducto` según el brief.
3. Corridos de nuevo → los 8 tests de `productos.test.js` pasan.

**Resumen de tests:** `npx jest productos.test.js --verbose` → 8/8 passed (incluye los 3 nuevos: 400 sin sucursal_id, 201 con sucursal_id asignando stock en `producto_stock_sucursal`, y 201 sin stock sin exigir sucursal_id).

**Dudas/inquietudes:** ninguna relevante al alcance de esta tarea. El único desvío del brief fue el nombre del paquete bcrypt/bcryptjs, documentado arriba.

---

## Fix post-revisión final (hallazgo Important)

**Problema reportado:** `crearProducto` creaba el producto (`Producto.create`) antes de validar la existencia del `sucursal_id` cuando el creador tiene `acceso_todas`, a diferencia de `caja.controller.js` e `inventario.controller.js`, que validan con `Sucursal.findByPk` antes de escribir. Consecuencias: un `sucursal_id` inexistente producía un `ForeignKeyConstraintError` mapeado a 500 (no el 404 esperado por la spec), y en cualquier camino de fallo (400 o 500) quedaba un producto huérfano persistido con `stock=0`.

**Cambio aplicado en `backend/src/modules/productos/productos.service.js`:**
- Se importó `Sucursal` desde `../../models`.
- `crearProducto` ahora resuelve y valida `sucursalDestino` **antes** de `Producto.create`: si `alcance.acceso_todas` y no hay `sucursal_id` → 400 (mensaje sin cambios); si `alcance.acceso_todas` y `Sucursal.findByPk(sucursal_id)` no encuentra la fila → 404 `'Sucursal no encontrada'` (mismo mensaje que `caja.controller.js` / `inventario.controller.js`). Solo después de pasar esas validaciones se crea el producto y se llama a `ajustarStockSucursal`. No cambió la firma de `crearProducto` ni de `ajustarStockSucursal`.

**Test agregado en `backend/tests/productos.test.js`** (dentro del describe `'Productos — stock inicial con acceso a todas las sucursales'`): `'acceso-todas creando producto con stock y sucursal_id inexistente → 404 y no crea el producto'` — verifica `res.status === 404` y que `Producto.count` con `categoria_id` no cambie (no queda huérfano).

**TDD:**
1. Antes del fix: `npx jest productos.test.js --verbose` → 8 passed, 1 failed (el nuevo test: esperaba 404, recibía 500 por `ForeignKeyConstraintError`).
2. Aplicado el fix (reordenar validación de sucursal antes de `Producto.create`).
3. Después del fix: `npx jest productos.test.js --verbose` → **9/9 passed**.

**Commit:** `fix(productos): valida existencia de sucursal antes de crear el producto, evita huérfanos`
