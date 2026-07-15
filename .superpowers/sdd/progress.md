# Progress Ledger — Opciones/variantes por producto

Plan: docs/superpowers/plans/2026-07-14-opciones-producto-plan.md
Started: 2026-07-14
Rama: main (sin worktree separado, mismo patrón que el plan anterior de CodePay)

## Completadas

- [x] Task 1: Migración y modelos GrupoOpciones/Opcion/Producto.grupo_opciones_id (commits
  a2059d1..411b5e6, review clean con 1 Minor sin bloquear: agregó `setupFilesAfterEnv` +
  `tests/setup.js` para cargar dotenv globalmente en Jest, algo no pedido por el brief. Verificado
  por el revisor como necesario — el test nuevo importa `../src/models` directamente sin pasar
  por `app.js`, que es el único lugar que hoy llama `dotenv.config()` — y como inofensivo: mismas
  4 suites preexistentes (auth-sucursales, inventario, productos, sucursales) fallan igual antes y
  después por falta del seed "Sucursal Principal", sin relación. El patrón local ya establecido en
  el repo era más angosto (`require('dotenv').config()` inline en el propio archivo de test, como
  hace `stock.service.test.js`) pero el cambio elegido no rompe nada. No se re-despacha fix por ser
  Minor y verificado inofensivo. 2/2 tests.)

- [x] Task 2: CRUD backend de grupos de opciones (commit 94b8fb2, review clean — 5/5 tests.
  Transcripción literal del brief: permiso `productos` reutilizado, eliminar desasigna en vez de
  fallar, actualizar reemplaza por completo la lista de opciones. Sin residuos en BD tras los
  tests. Solo Minor sin bloquear: falta validar shape de `opciones` en el body (mismo nivel de
  laxitud que el resto del módulo, no es regresión).)

- [x] Task 3: Extender productos para incluir/aceptar grupo_opciones_id (commit 760c082, review
  clean — 3/3 tests nuevos, y el revisor confirmó contra el commit anterior que los 3 fallos
  preexistentes de "Stock de productos por sucursal" (falta seed "Sucursal Principal" en la DB de
  test) ya existían antes de este cambio, sin relación con el nuevo `include`. `actualizarProducto`
  no se tocó, tal como pedía el brief.)

- [x] Task 4: Admin frontend — pestaña "Opciones" y selector en formulario de producto (commit
  29f932b, review clean. Verificación manual con Playwright real contra dev servers + MySQL:
  crear grupo con 3 opciones, editar reordenando/quitando una, asignar a un producto, eliminar el
  grupo y confirmar que el producto queda en "Ninguno". El proceso implementador se cortó a mitad
  de camino por reinicio de sesión pero se resumió desde su transcript sin perder el trabajo ya
  hecho en el working tree; limpió los duplicados de prueba que había dejado el intento
  interrumpido antes de la corrida final. Solo Minor sin bloquear: sin feedback visual si falla
  eliminar un grupo (mismo patrón preexistente de TabCategorias).)

- [x] Task 5: Ventas frontend — selector de opciones y carrito multi-línea por nota (commit
  1fd0494, review clean. El revisor verificó explícitamente que no hay call-sites obsoletos
  (stale closures) en incrementar/decrementar/quitar tras cambiar su firma a (producto_id, nota),
  que el precio nunca viene de la opción elegida, y que productos sin grupo siguen agregándose
  directo sin modal. Verificación manual con Playwright real: dos líneas separadas del mismo
  producto con distinta opción, tercera línea "sin especificar", insignia sumando correctamente,
  y persistencia confirmada en PedidoPage.jsx tras cobrar.)

## Revisión final de rama

Revisor final (opus, diff 424de18..1fd0494): **Ready to merge.** Verificó coherencia end-to-end
(shapes de `grupo_opciones` entre backend/frontend, alias de Sequelize consistentes entre las 5
tareas), las 5 restricciones globales sobre el resultado combinado, y corrió la suite completa
en HEAD vs. el commit base: 17 fallas preexistentes en ambos (mismas 4 suites, seed "Sucursal
Principal" faltante) — cero regresión, +10 tests nuevos pasando. Sin hallazgos Critical/Important.
2 Minor nuevos (no vistos por las revisiones por tarea): (1) editar un grupo de opciones no
invalida `['productos']` en cache — solo lo hace eliminar, dejando `grupo_opciones` embebido
stale en productos ya cacheados hasta el próximo refetch (staleness visual recuperable, no rompe
nada porque la opción ya se guardó como texto en `nota` al elegirla); (2) `eliminarGrupoOpciones`
no usa transacción para el `Producto.update` + `grupo.destroy()`, aunque el `ON DELETE SET NULL`
ya lo hace seguro igual. Ambos opcionales, no bloquean merge.

Fix aplicado (commit f566d68): `TabOpciones` en `ProductosPage.jsx` ahora invalida también
`['productos']` al guardar (crear/editar) un grupo de opciones, no solo al eliminarlo — corrige
el Minor #1 de la revisión final. El Minor #2 (falta de transacción en `eliminarGrupoOpciones`)
se dejó tal cual por decisión del usuario, ya que el `ON DELETE SET NULL` lo hace seguro igual.

**Veredicto final: Ready to merge.**

## TODAS LAS TAREAS COMPLETAS
Commits: a2059d1..f566d68 (5 tareas del plan + 1 fix de la revisión final)

## Notas
