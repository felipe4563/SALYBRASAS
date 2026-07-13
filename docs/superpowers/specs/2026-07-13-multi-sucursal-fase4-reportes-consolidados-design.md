# Multi-sucursal — Fase 4: Reportes consolidados de la cadena

## Contexto

Las Fases 1-2 dejaron cada sucursal operando de forma independiente
(mesas, caja, ventas, compras, inventario), y ya garantizaron que un
usuario de una sola sucursal no vea datos de otra. Un usuario con
`acceso_todas_sucursales` que eligió "Todas las sucursales" al iniciar
sesión sí ve todo sin filtrar — pero hoy lo ve todo **mezclado**: los
cuatro reportes (`Ventas`, `Inventario`, `Compras`, `Caja`) son listas
planas con filtro de fechas, sin ninguna columna ni forma de saber a
qué sucursal pertenece cada fila, ni de comparar una sucursal contra
otra.

Esta fase cierra ese vacío: en modo "Todas las sucursales", cada
reporte muestra de qué sucursal es cada fila, permite filtrar por una
sucursal específica, y agrega una tabla de resumen comparativo
(sucursal → totales). También corrige un pendiente que quedó de la
Fase 2: el reporte de Caja no filtraba por sucursal (a diferencia de
Ventas, Inventario y Compras), porque `libro_caja` no tiene
`sucursal_id` directo.

Para un usuario de una sola sucursal, nada cambia — ve exactamente lo
mismo que hoy, sin columnas ni filtros nuevos.

## Decisiones de alcance

- **Todo se calcula en el cliente.** Los 4 reportes ya cargan de una
  sola vez todas las filas del rango de fechas elegido (no paginan), y
  ya calculan sus `StatCard`/totales client-side con `useMemo` (ver
  `TabVentas.jsx`). El filtro de sucursal y el resumen comparativo
  siguen exactamente ese mismo patrón — no hace falta ningún endpoint
  nuevo, solo que el backend incluya el dato de sucursal en cada fila.
- **El resumen comparativo aplica a los 4 reportes**, con las columnas
  relevantes de cada uno (no las mismas columnas en los 4 — cada
  reporte resume lo que ya muestra en sus `StatCard` actuales, pero
  desglosado por sucursal en vez de un solo total).
- **El filtro y la columna de sucursal solo aparecen en modo "Todas las
  sucursales"** (`usuario.sucursal_activa.id == null`) — igual que el
  patrón ya usado en `ProductosPage.jsx` para el desglose de stock.
- **Se corrige el reporte de Caja** para que también filtre por
  sucursal cuando corresponda, cerrando el pendiente documentado en la
  Fase 2.

## Backend

### `ventas`, `inventario`, `compras` (ya filtran, se les agrega el include)

Cada una ya recibe `{ desde, hasta, sucursal_id, acceso_todas }` y
aplica `if (!acceso_todas) where.sucursal_id = sucursal_id;`. Se les
agrega, en el `include` existente, la sucursal de cada fila:

```javascript
{ model: Sucursal, as: 'sucursal', attributes: ['id', 'nombre'] }
```

(`Pedido`, `RegistroInventario` y `Compra` ya tienen la asociación
`belongsTo(Sucursal, { as: 'sucursal' })` desde la Fase 2 — este
`include` solo se agrega a las tres consultas de `reportes.service.js`,
no requiere cambios de modelo.)

### `caja` (nueva: se agrega filtro + sucursal)

`LibroCaja` no tiene `sucursal_id` directo, pero sí `sesion_caja_id`, y
`SesionCaja` ya tiene `sucursal_id` (Fase 2) y la asociación
`LibroCaja.belongsTo(SesionCaja, { as: 'sesion_caja' })` ya existe.
Se filtra vía ese join:

```javascript
async function caja({ desde, hasta, sucursal_id, acceso_todas } = {}) {
  const includeSesion = {
    model: SesionCaja,
    as: 'sesion_caja',
    attributes: [],
    include: [{ model: Sucursal, as: 'sucursal', attributes: ['id', 'nombre'] }],
  };
  if (!acceso_todas) includeSesion.where = { sucursal_id };

  return LibroCaja.findAll({
    where: filtroFecha(desde, hasta),
    include: [
      { model: Usuario, as: 'usuario', attributes: ['id', 'nombre'] },
      includeSesion,
    ],
    order: [['creado_en', 'DESC']],
  });
}
```

Cuando `includeSesion.where` está presente, Sequelize hace el join
`required` automáticamente (filtra), igual que el resto de los
reportes. El controller (`reportes.controller.js`) ya tiene un
`_alcance(req)` — se aplica también a `getCaja`, igual que ya se hace
para `getVentas`/`getInventario`/`getCompras`.

## Frontend

Mismo patrón se replica en las 4 pestañas
(`TabVentas.jsx`/`TabInventario.jsx`/`TabCompras.jsx`/`TabCaja.jsx`):

- **`accesoTodas`**: se deriva con
  `useAuthStore((s) => s.usuario?.sucursal_activa?.id == null)` dentro
  de cada componente de pestaña (mismo patrón ya usado en
  `TabProductos` de `ProductosPage.jsx`).
- **Filtro "Sucursal"**: un `<select>` igual al de "Cajero" que ya
  existe en `TabVentas.jsx` — solo se renderiza cuando `accesoTodas` es
  `true`, con opciones derivadas de las filas ya cargadas
  (`data.map(v => v.sucursal)` deduplicado por `id`, mismo `useMemo`
  que ya arma la lista de cajeros).
- **Columna "Sucursal"**: nueva columna en la tabla, agregada
  condicionalmente (`accesoTodas && <th>Sucursal</th>` /
  `accesoTodas && <td>{v.sucursal?.nombre}</td>`).
- **Resumen comparativo**: una tabla nueva, debajo de los `StatCard`
  existentes y encima de la tabla detallada, visible solo cuando
  `accesoTodas` es `true`. Se arma agrupando `filtrado` (los datos ya
  filtrados por fecha/cajero/sucursal) por `sucursal_id` con
  `useMemo`, con las columnas:
  - **Ventas**: Sucursal · N° Ventas · Total · Efectivo · QR
  - **Inventario**: Sucursal · N° Movimientos · Entradas · Salidas ·
    Ajustes (una columna por `tipo`, agrupando `venta`+`compra` dentro
    de "Entradas"/"Salidas" según corresponda, igual que ya se
    interpretan esos tipos en el resto de la UI de inventario)
  - **Compras**: Sucursal · N° Compras · Total
  - **Caja**: Sucursal · Ingresos · Egresos · Neto

  Estas son exactamente las mismas métricas que cada pestaña ya
  calcula como total único en sus `StatCard` — el resumen es ese mismo
  cálculo, repetido por sucursal en vez de una sola vez para todo.
- El export a PDF existente (`exportarPDF`) no cambia — sigue
  exportando la lista detallada tal como está filtrada en pantalla
  (que ya incluye el filtro de sucursal aplicado, si el usuario eligió
  uno).

## Fuera de alcance

- Comparativas entre rangos de fechas (ej. "este mes vs. el anterior
  por sucursal") — no pedido, se puede agregar después si hace falta.
- Gráficos/visualizaciones — el resumen es tabular, como el resto de
  la sección Reportes hoy.
- Cualquier cambio a mesas, caja, ventas, compras o inventario en sí
  (esta fase es solo de reportes/lectura).
