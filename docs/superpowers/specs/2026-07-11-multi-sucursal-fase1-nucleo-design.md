# Multi-sucursal — Fase 1: Núcleo (sucursales, usuarios y sesión)

## Contexto

SALYBRASAS es hoy un sistema de restaurante de una sola ubicación. El objetivo a
mediano plazo es que funcione como cadena: cada sucursal maneja su propio
inventario, mesas, caja y ventas, pero se puede consultar todo desde una sola
cuenta con acceso total (dueño / admin general).

Este cambio es transversal a casi todos los módulos existentes (mesas,
inventario, ventas, caja, compras, reportes), así que se divide en fases:

1. **Fase 1 (este documento)** — Núcleo: qué es una sucursal, cómo se
   relacionan los usuarios con las sucursales, y cómo cada sesión sabe en qué
   sucursal está operando.
2. Fase 2 — Datos operativos por sucursal (mesas/áreas, inventario, caja,
   pedidos/ventas).
3. Fase 3 — Catálogo y compras (si productos/categorías son compartidos o
   independientes por sucursal).
4. Fase 4 — Reportes consolidados de la cadena.

Este spec cubre **solo la Fase 1**.

## Decisiones de alcance

- Un usuario puede pertenecer a **varias sucursales** (relación N:M), no a una
  sola.
- Al iniciar sesión, si el usuario tiene más de una sucursal disponible, elige
  con cuál va a trabajar. La sucursal activa queda fija durante toda la
  sesión: para cambiarla hay que cerrar sesión y volver a entrar (no hay
  switcher en caliente en esta fase).
- Roles y permisos siguen siendo un catálogo **único y compartido** entre
  todas las sucursales (como hoy). No hay roles por sucursal.
- Existe un flag de **acceso total** (`acceso_todas_sucursales`) para el perfil
  de dueño/admin general: ese usuario puede elegir, al iniciar sesión,
  cualquier sucursal individual o la opción "Todas las sucursales" (vista
  consolidada).
- Los datos existentes en producción se migran a una sucursal por defecto
  llamada **"Sucursal Principal"**, a la que quedan asociados todos los
  usuarios actuales. Nadie pierde acceso al desplegar este cambio.
- **Fuera de alcance de la Fase 1**: ningún módulo operativo existente (mesas,
  inventario, ventas, caja, compras, reportes) se modifica para filtrar sus
  datos por sucursal. Esta fase solo deja listo el modelo de datos, la sesión
  con `sucursal_id`, y el CRUD de sucursales, de forma aislada y funcional por
  sí sola.

## Modelo de datos

Nueva migración `backend/database/migrations/012_sucursales.sql`:

```sql
CREATE TABLE IF NOT EXISTS sucursales (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(255) NOT NULL,
  direccion VARCHAR(255),
  telefono VARCHAR(50),
  activo TINYINT(1) NOT NULL DEFAULT 1,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE usuarios
  ADD COLUMN acceso_todas_sucursales TINYINT(1) NOT NULL DEFAULT 0 AFTER rol_id;

CREATE TABLE IF NOT EXISTS usuarios_sucursales (
  usuario_id INT UNSIGNED NOT NULL,
  sucursal_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (usuario_id, sucursal_id),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
  FOREIGN KEY (sucursal_id) REFERENCES sucursales(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Datos existentes: crear sucursal por defecto y asignar todos los usuarios actuales
INSERT INTO sucursales (nombre) VALUES ('Sucursal Principal');

INSERT INTO usuarios_sucursales (usuario_id, sucursal_id)
SELECT id, (SELECT id FROM sucursales WHERE nombre = 'Sucursal Principal' LIMIT 1)
FROM usuarios;

-- Nuevo módulo de permisos
INSERT INTO permisos (modulo, accion, descripcion) VALUES
  ('sucursales', 'ver', 'Ver sucursales'),
  ('sucursales', 'crear', 'Crear sucursales'),
  ('sucursales', 'editar', 'Editar sucursales'),
  ('sucursales', 'eliminar', 'Eliminar sucursales');

-- Otorgar el nuevo permiso al rol Administrador
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r, permisos p
WHERE r.nombre = 'Administrador' AND p.modulo = 'sucursales';
```

Modelos Sequelize nuevos: `Sucursal` y la tabla puente `UsuarioSucursal`, con
asociación `belongsToMany` entre `Usuario` y `Sucursal` (mismo patrón que
`Rol` ↔ `Permiso`).

## Login y sesión (JWT)

- `POST /api/v1/auth/login` (email + contraseña):
  - Si el usuario tiene **una sola** sucursal asignada y no tiene
    `acceso_todas_sucursales`, se comporta igual que hoy: responde
    `{ token, refresh_token, usuario }` directamente.
  - Si tiene **varias sucursales** o `acceso_todas_sucursales = 1`, responde
    `{ requiere_sucursal: true, pre_token, sucursales: [...] }` (incluyendo la
    opción `{ id: null, nombre: 'Todas las sucursales' }` cuando aplica) y
    **no** emite el JWT normal todavía. `pre_token` es un JWT de corta
    duración (ej. 5 min) firmado con `JWT_SECRET`, payload `{ id, tipo:
    'pre_login' }`, que certifica que las credenciales ya fueron validadas.
- `POST /api/v1/auth/login/sucursal` (nuevo endpoint): recibe
  `{ pre_token, sucursal_id }`, valida que `pre_token` sea del tipo
  `pre_login` y no haya expirado, verifica que `sucursal_id` esté entre las
  sucursales permitidas para ese usuario (o que tenga
  `acceso_todas_sucursales` si `sucursal_id` es `null`), y emite el JWT normal
  con la sucursal elegida.
- Payload del JWT pasa de `{ id }` a `{ id, sucursal_id }`, donde
  `sucursal_id` es `null` si el usuario eligió "Todas las sucursales".
- `middlewares/auth.js` decodifica el payload y expone:
  - `req.usuario.sucursal_id` (puede ser `null`)
  - `req.usuario.acceso_todas` (booleano, `true` cuando `sucursal_id` es
    `null` por elección del usuario)
- `POST /api/v1/auth/refresh` conserva el mismo `sucursal_id` del token
  original al reemitir el `token`.
- El frontend guarda la sucursal activa en `authStore.js` junto con el
  usuario, y la muestra de solo lectura en el header/sidebar (sin selector en
  caliente).

## Backend — módulo `sucursales`

Nuevo módulo `backend/src/modules/sucursales/` (mismo patrón que
`roles/`: `controller` + `routes` + `service`):

- `GET /api/v1/sucursales` — listar (`verificarPermiso('sucursales','ver')`)
- `POST /api/v1/sucursales` — crear (`'crear'`)
- `PUT /api/v1/sucursales/:id` — editar (`'editar'`)
- `DELETE /api/v1/sucursales/:id` — eliminar (`'eliminar'`)

En `modules/usuarios/`, nuevo endpoint:

- `PUT /api/v1/usuarios/:id/sucursales` — reemplaza el set de sucursales
  asignadas: `{ sucursal_ids: number[], acceso_todas_sucursales: boolean }`
  (`verificarPermiso('usuarios','editar')`)

## Frontend

- `frontend/src/api/sucursales.js` — cliente API nuevo (mismo patrón que
  `api/roles.js`).
- `pages/auth/LoginPage.jsx` — si la respuesta del login trae
  `requiere_sucursal: true`, se muestra un paso adicional con el listado de
  sucursales (+ "Todas las sucursales" si aplica) antes de completar el
  ingreso.
- `store/authStore.js` — guarda `sucursal_activa` (`{ id, nombre }` o
  `{ id: null, nombre: 'Todas las sucursales' }`) junto con usuario/token.
- Header o Sidebar — muestra el nombre de la sucursal activa (solo lectura).
- Nueva página `pages/sucursales/` — listado + formulario crear/editar,
  protegida por el permiso `sucursales.ver`, mismo patrón visual que
  `pages/roles/`.
- `pages/usuarios/` — en el formulario de edición de usuario, se agrega un
  multi-select de sucursales + checkbox "Acceso a todas las sucursales".

## Fuera de alcance (fases futuras)

- Filtrar mesas, inventario, caja, pedidos/ventas y compras por
  `sucursal_id` (Fase 2).
- Decidir si productos/categorías son compartidos o independientes por
  sucursal (Fase 3).
- Reportes consolidados de toda la cadena vs. por sucursal individual
  (Fase 4).
- Switcher de sucursal activa sin cerrar sesión (no solicitado; se puede
  reconsiderar más adelante).
