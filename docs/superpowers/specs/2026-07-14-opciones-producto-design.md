# Opciones/variantes por producto — Diseño

## Contexto y problema

El restaurante vende platos y bebidas que requieren que el mozo elija una
variante al momento de tomar el pedido: término de cocción de una carne
(jugoso, término medio, bien cocido), sabor de un jugo preparado (copoazú,
limonada, maracuyá), etc. Hoy el sistema no tiene forma de capturar esto en
el momento de agregar el producto al pedido — solo existe una nota de texto
libre (`detalle_pedidos.nota`) que se edita *después*, desde la pantalla de
detalle del pedido (`PedidoPage.jsx`), no desde la pantalla de venta donde
se arma el pedido (`VentasPage.jsx`).

Se busca que, para los productos que lo requieran, aparezca un selector con
opciones predefinidas al agregarlos al carrito, y que esa elección quede
reflejada en el pedido y en el ticket de cocina — sin afectar a los demás
productos, que deben seguir agregándose con un solo toque como hoy.

## Decisiones (confirmadas con el usuario)

1. **Configuración reutilizable por grupo**: se definen "grupos de
   opciones" (ej: "Término de cocción", "Sabor") una sola vez, cada uno con
   su lista de valores, y se asignan a los productos que correspondan — no
   se repite la lista en cada producto.
2. **Un grupo como máximo por producto** (no múltiples grupos combinados).
3. **La elección es opcional**: el mozo puede agregar el producto al
   carrito sin elegir ninguna opción.
4. **Sin impacto en precio**: ninguna opción cambia el precio del producto.
5. **Se reutiliza el campo `nota` existente**: la opción elegida se guarda
   como el texto de `detalle_pedidos.nota` de esa línea (ej. `nota =
   "Término medio"`). No se agrega columna nueva a `detalle_pedidos`; el
   ticket de cocina, los reportes y la edición posterior de nota en
   `PedidoPage.jsx` siguen funcionando sin cambios. El mozo puede editar
   esa nota después como ya lo hace hoy.

## Modelo de datos

Dos tablas nuevas y una columna nueva en `productos`, siguiendo el estilo
de las migraciones existentes en `backend/database/migrations/`.

```sql
-- 017_opciones_producto.sql
CREATE TABLE IF NOT EXISTS grupos_opciones (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS opciones (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  grupo_opciones_id INT UNSIGNED NOT NULL,
  nombre VARCHAR(100) NOT NULL,
  orden INT NOT NULL DEFAULT 0,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (grupo_opciones_id) REFERENCES grupos_opciones(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE productos
  ADD COLUMN grupo_opciones_id INT UNSIGNED NULL AFTER categoria_id,
  ADD FOREIGN KEY (grupo_opciones_id) REFERENCES grupos_opciones(id) ON DELETE SET NULL;
```

`productos.grupo_opciones_id` es `NULL` por defecto: la inmensa mayoría de
productos (bebidas envasadas, cervezas, etc.) no tiene grupo asignado y su
comportamiento en Ventas no cambia en absoluto.

Modelos Sequelize nuevos (`GrupoOpciones`, `Opcion`) siguiendo el patrón de
`Categoria`/`Producto`. Asociaciones en `src/models/index.js`:

```js
GrupoOpciones.hasMany(Opcion, { foreignKey: 'grupo_opciones_id', as: 'opciones' });
Opcion.belongsTo(GrupoOpciones, { foreignKey: 'grupo_opciones_id', as: 'grupo' });
Producto.belongsTo(GrupoOpciones, { foreignKey: 'grupo_opciones_id', as: 'grupo_opciones' });
GrupoOpciones.hasMany(Producto, { foreignKey: 'grupo_opciones_id', as: 'productos' });
```

## Backend — API

Se agrega al módulo `productos` existente (mismo patrón que `categorias`,
que ya vive dentro de ese módulo): nuevo archivo de rutas
`grupos-opciones.routes.js`, montado en `app.js` bajo
`/api/v1/grupos-opciones`, reutilizando el permiso `productos` (no se
agrega un módulo de permisos nuevo, ya que administrar grupos de opciones
es parte de la configuración de productos):

```js
// backend/src/modules/productos/grupos-opciones.routes.js
router.get('/',    verificarPermiso('productos', 'ver'),    ctrl.listarGruposOpciones);
router.post('/',   verificarPermiso('productos', 'crear'),  ctrl.crearGrupoOpciones);
router.put('/:id', verificarPermiso('productos', 'editar'), ctrl.actualizarGrupoOpciones);
router.delete('/:id', verificarPermiso('productos', 'eliminar'), ctrl.eliminarGrupoOpciones);
```

- `GET /grupos-opciones` devuelve cada grupo con sus opciones anidadas
  (`{ id, nombre, opciones: [{ id, nombre, orden }] }`), ordenadas por
  `orden` y `nombre`.
- `POST`/`PUT` reciben `{ nombre, opciones: [{ id?, nombre, orden }] }` y
  reemplazan por completo la lista de opciones del grupo en una
  transacción (borra las que ya no están, actualiza las existentes, crea
  las nuevas) — igual de simple que editar una categoría, sin tener que
  exponer endpoints CRUD separados para `opciones`.
- `DELETE /grupos-opciones/:id`: si el grupo está asignado a algún
  producto, se pone `grupo_opciones_id = NULL` en esos productos antes de
  borrar el grupo (igual que ya hace `eliminarCategoria`/`eliminarProducto`
  con relaciones dependientes), para no dejar productos huérfanos con una
  referencia rota.

`GET /productos` (y `GET /productos/:id`) se extiende para incluir el
grupo de opciones asignado:

```js
include: [
  { model: Categoria, as: 'categoria', attributes: ['id', 'nombre'] },
  { model: GrupoOpciones, as: 'grupo_opciones', attributes: ['id', 'nombre'],
    include: [{ model: Opcion, as: 'opciones', attributes: ['id', 'nombre', 'orden'] }] },
]
```

`crearProducto`/`actualizarProducto` aceptan `grupo_opciones_id` (nullable)
igual que aceptan `categoria_id` hoy.

## Frontend — Administración (`ProductosPage.jsx`)

Se agrega una tercera pestaña "Opciones" junto a "Categorías" y
"Productos", con el mismo patrón de tabla + `Modal` que ya usa
`TabCategorias`: listado de grupos, botón "Nuevo grupo", y un formulario
modal donde se edita el nombre del grupo y su lista de opciones (agregar/
quitar/reordenar filas de texto simple, sin drag-and-drop — solo botones
subir/bajar o inputs numéricos de orden).

En `FormProductoModal`, junto al selector de "Categoría", se agrega un
selector "Grupo de opciones" con las opciones `Ninguno` + los grupos
existentes (cargados con `useQuery(['grupos-opciones'], ...)`).

## Frontend — Venta (`VentasPage.jsx`)

`handleProducto(prod)` cambia de comportamiento según si `prod.grupo_opciones`
existe:

- **Sin grupo** (caso de hoy, mayoría de productos): comportamiento
  idéntico al actual — se agrega/incrementa directamente en el carrito.
- **Con grupo**: en vez de agregar directo, se abre un modal ligero
  (`SelectorOpcionModal`) con las opciones del grupo como chips
  seleccionables (mismo estilo visual que los chips de `CategoriasBar`) más
  un botón secundario "Agregar sin especificar". Tocar una opción o ese
  botón agrega el producto al carrito y cierra el modal; no hay paso de
  confirmación adicional. Cancelar/cerrar el modal no agrega nada.

El carrito guarda la elección en el mismo campo `nota` que ya usa el envío
del pedido (`carrito.map(it => ({ producto_id, cantidad, nota: it.nota }))`
ya existe en `VentasPage.jsx:431`, no cambia).

**Cambio necesario en el agrupado del carrito**: hoy `handleProducto` busca
un item existente solo por `producto_id` y le suma cantidad
(`VentasPage.jsx:99-104`); esto haría que dos Picañas con distinto término
se fusionen en una sola línea. Se cambia la búsqueda para que considere
también la nota:

```js
const existente = prev.find((it) => it.producto_id === prod.id && it.nota === nota);
```

Donde `nota` es `null` para productos sin grupo (comportamiento actual sin
cambios) o el texto elegido para productos con grupo. Dos líneas del mismo
producto con notas distintas (o una con nota y otra sin ella) quedan como
entradas separadas del carrito, cada una con su propio contador +/-.

## Fuera de alcance (YAGNI, se puede agregar después si hace falta)

- Múltiples grupos de opciones combinados en un mismo producto.
- Opciones que modifican el precio.
- Selección obligatoria / bloqueo de agregar sin elegir.
- Reportes o filtros que separen ventas por opción elegida (al vivir en
  `nota` como texto libre, un reporte futuro tendría que hacer *match* de
  texto; no se resuelve en este diseño).

## Pruebas

- Backend: tests de `grupos-opciones` (CRUD, reemplazo de lista de
  opciones, borrado deja `grupo_opciones_id = NULL` en productos
  asignados) y de `productos` (crear/editar con `grupo_opciones_id`,
  `GET` incluye `grupo_opciones` anidado).
- Frontend: no hay suite de tests automatizados en este proyecto para
  páginas de React (se verifica manualmente); se probará a mano el flujo
  completo: producto sin grupo (toque directo), producto con grupo
  (selector, elegir opción, "agregar sin especificar"), y que dos líneas
  del mismo producto con distinta opción no se fusionen.
