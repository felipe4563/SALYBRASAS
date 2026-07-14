### Task 1: Migración, modelo `PagoQr`, estado `pendiente_pago` en Pedido, credenciales

**Files:**
- Create: `backend/database/migrations/015_pagos_qr.sql`
- Create: `backend/src/models/PagoQr.js`
- Modify: `backend/src/models/Pedido.js`
- Modify: `backend/src/models/index.js`
- Modify: `backend/.env.example`
- Modify: `backend/.env` (no se commitea — está en `.gitignore`)
- Test: `backend/tests/pagos_qr.model.test.js`

**Interfaces:**
- Produces: modelo `PagoQr` exportado desde `backend/src/models/index.js` junto al resto (`{ ..., PagoQr }`), con asociaciones `Pedido.hasMany(PagoQr, { as: 'pagosQr' })` / `PagoQr.belongsTo(Pedido, { as: 'pedido' })` / `PagoQr.belongsTo(Sucursal, { as: 'sucursal' })`. `Pedido.estado` acepta `'pendiente_pago'`.

- [ ] **Step 1: Escribir la migración**

`backend/database/migrations/015_pagos_qr.sql`:

```sql
CREATE TABLE IF NOT EXISTS pagos_qr (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  pedido_id INT UNSIGNED NOT NULL,
  sucursal_id INT UNSIGNED NOT NULL,
  order_id VARCHAR(25) NOT NULL UNIQUE,
  tx_id VARCHAR(100) NULL,
  estado ENUM('pendiente','completado','fallido','expirado','cancelado') NOT NULL DEFAULT 'pendiente',
  estado_previo VARCHAR(20) NOT NULL,
  moneda VARCHAR(3) NOT NULL DEFAULT 'BOB',
  monto_neto DECIMAL(10,2) NOT NULL,
  comision DECIMAL(10,2) NULL,
  monto_total DECIMAL(10,2) NULL,
  qr_code MEDIUMTEXT NULL,
  expires_at DATETIME NOT NULL,
  datos_webhook JSON NULL,
  creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (pedido_id) REFERENCES pedidos(id),
  FOREIGN KEY (sucursal_id) REFERENCES sucursales(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE pedidos
  MODIFY COLUMN estado ENUM('pendiente','listo','pendiente_pago','completado','cancelado') NOT NULL DEFAULT 'pendiente';
```

- [ ] **Step 2: Aplicar la migración a la base de datos local**

`backend/.env` tiene `DB_NAME=bd_restaurante`, `DB_USER=root`, `DB_PASS=` (vacío). Aplicar con:

```bash
cd backend
mysql -u root bd_restaurante < database/migrations/015_pagos_qr.sql
```

Verificar que no haya errores. Si `ALTER TABLE pedidos` falla por un `sql_mode` incompatible (ya ocurrió en una fase anterior con `NO_ZERO_DATE` sobre `sesiones_caja.cerrado_en`), bajar el `sql_mode` solo para esa sesión de `mysql`, sin tocar nada versionado, tal como se hizo entonces.

- [ ] **Step 3: Crear el modelo `PagoQr`**

`backend/src/models/PagoQr.js`:

```javascript
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const PagoQr = sequelize.define('PagoQr', {
  id: { type: DataTypes.INTEGER.UNSIGNED, primaryKey: true, autoIncrement: true },
  pedido_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
  sucursal_id: { type: DataTypes.INTEGER.UNSIGNED, allowNull: false },
  order_id: { type: DataTypes.STRING(25), allowNull: false, unique: true },
  tx_id: { type: DataTypes.STRING(100) },
  estado: { type: DataTypes.ENUM('pendiente', 'completado', 'fallido', 'expirado', 'cancelado'), defaultValue: 'pendiente' },
  estado_previo: { type: DataTypes.STRING(20), allowNull: false },
  moneda: { type: DataTypes.STRING(3), defaultValue: 'BOB' },
  monto_neto: { type: DataTypes.DECIMAL(10, 2), allowNull: false },
  comision: { type: DataTypes.DECIMAL(10, 2) },
  monto_total: { type: DataTypes.DECIMAL(10, 2) },
  qr_code: { type: DataTypes.TEXT('medium') },
  expires_at: { type: DataTypes.DATE, allowNull: false },
  datos_webhook: { type: DataTypes.JSON },
}, {
  tableName: 'pagos_qr',
  createdAt: 'creado_en',
  updatedAt: 'actualizado_en',
});

module.exports = PagoQr;
```

- [ ] **Step 4: Agregar `'pendiente_pago'` al enum de `Pedido.estado`**

En `backend/src/models/Pedido.js`, cambiar la línea:

```javascript
  estado: { type: DataTypes.ENUM('pendiente','listo','completado','cancelado'), defaultValue: 'pendiente' },
```

por:

```javascript
  estado: { type: DataTypes.ENUM('pendiente','listo','pendiente_pago','completado','cancelado'), defaultValue: 'pendiente' },
```

- [ ] **Step 5: Registrar el modelo y sus asociaciones en `models/index.js`**

Agregar el require junto a los demás, después de `const Caja = require('./Caja');`:

```javascript
const PagoQr = require('./PagoQr');
```

Agregar las asociaciones al final del bloque `// Cajas físicas (Fase 6)` (antes de `module.exports`):

```javascript
// Pagos QR (CodePay)
Pedido.hasMany(PagoQr, { foreignKey: 'pedido_id', as: 'pagosQr' });
PagoQr.belongsTo(Pedido, { foreignKey: 'pedido_id', as: 'pedido' });
PagoQr.belongsTo(Sucursal, { foreignKey: 'sucursal_id', as: 'sucursal' });
```

Agregar `PagoQr` al `module.exports`:

```javascript
module.exports = {
  sequelize,
  Rol, Permiso, Usuario,
  Area, Mesa,
  Categoria, Producto,
  Cliente,
  SesionCaja, Pedido, DetallePedido,
  DetalleArqueo, Gasto, LibroCaja,
  Proveedor, Compra, DetalleCompra,
  RegistroInventario,
  Configuracion,
  Reservacion,
  Sucursal,
  ProductoStockSucursal,
  Caja,
  PagoQr,
};
```

- [ ] **Step 6: Agregar las variables de entorno**

En `backend/.env.example`, agregar al final:

```bash
CODEPAY_SANDBOX=true
CODEPAY_API_URL=https://payapi.codewave.com.bo/api
CODEPAY_PUBLIC_KEY=
CODEPAY_SECRET_KEY=
CODEPAY_NOTIFICATION_SECRET=
CODEPAY_SANDBOX_PUBLIC_KEY=
CODEPAY_SANDBOX_SECRET_KEY=
```

En `backend/.env` (real, no versionado — **no pegar las llaves reales en ningún archivo que se vaya a commitear**; el usuario ya las compartió por chat en la conversación de diseño de esta fase, tomarlas de ahí y pegarlas directo en `.env` local), agregar al final las mismas 7 variables con los valores reales (`CODEPAY_SANDBOX`, `CODEPAY_API_URL`, `CODEPAY_PUBLIC_KEY`, `CODEPAY_SECRET_KEY`, `CODEPAY_NOTIFICATION_SECRET`, `CODEPAY_SANDBOX_PUBLIC_KEY`, `CODEPAY_SANDBOX_SECRET_KEY`).

- [ ] **Step 7: Escribir el test del modelo**

`backend/tests/pagos_qr.model.test.js`:

```javascript
const request = require('supertest');
const app = require('../src/app');
const bcrypt = require('bcryptjs');
const {
  Sucursal, Area, Mesa, Rol, Usuario, Caja, SesionCaja, Pedido, PagoQr,
} = require('../src/models');

describe('Modelo PagoQr', () => {
  let sucursalId, areaId, mesaId, usuarioId, cajaId, sesionId, pedidoId;

  beforeAll(async () => {
    const sucursal = await Sucursal.create({ nombre: 'Sucursal PagoQr Test' });
    sucursalId = sucursal.id;
    const area = await Area.create({ nombre: 'Area PagoQr Test', sucursal_id: sucursalId });
    areaId = area.id;
    const mesa = await Mesa.create({ area_id: areaId, nombre: 'Mesa PagoQr Test' });
    mesaId = mesa.id;
    const rol = await Rol.findOne({ where: { nombre: 'Cajero' } });
    const hash = await bcrypt.hash('clave123', 10);
    const usuario = await Usuario.create({ rol_id: rol.id, nombre: 'PagoQr Test', email: 'pagoqr-model-test@restaurante.com', contrasena: hash });
    usuarioId = usuario.id;
    const caja = await Caja.create({ sucursal_id: sucursalId, nombre: 'Caja PagoQr Test' });
    cajaId = caja.id;
    const sesion = await SesionCaja.create({ usuario_id: usuarioId, sucursal_id: sucursalId, caja_id: cajaId, monto_apertura: 0 });
    sesionId = sesion.id;
    const pedido = await Pedido.create({
      sucursal_id: sucursalId, mesa_id: mesaId, usuario_id: usuarioId, sesion_caja_id: sesionId,
      tipo: 'mesa', estado: 'pendiente_pago', total: 10,
    });
    pedidoId = pedido.id;
  });

  afterAll(async () => {
    await PagoQr.destroy({ where: { pedido_id: pedidoId } });
    await Pedido.destroy({ where: { id: pedidoId } });
    await SesionCaja.destroy({ where: { id: sesionId } });
    await Caja.destroy({ where: { id: cajaId } });
    await Usuario.destroy({ where: { id: usuarioId } });
    await Mesa.destroy({ where: { id: mesaId } });
    await Area.destroy({ where: { id: areaId } });
    await Sucursal.destroy({ where: { id: sucursalId } });
  });

  it('el pedido acepta el estado pendiente_pago', async () => {
    const pedido = await Pedido.findByPk(pedidoId);
    expect(pedido.estado).toBe('pendiente_pago');
  });

  it('crea un pago_qr asociado al pedido y lo recupera vía la asociación', async () => {
    await PagoQr.create({
      pedido_id: pedidoId,
      sucursal_id: sucursalId,
      order_id: `pedido_${pedidoId}_1`,
      estado: 'pendiente',
      estado_previo: 'pendiente',
      monto_neto: 10,
      expires_at: new Date(Date.now() + 30 * 60000),
    });

    const pedido = await Pedido.findByPk(pedidoId, { include: [{ model: PagoQr, as: 'pagosQr' }] });
    expect(pedido.pagosQr).toHaveLength(1);
    expect(pedido.pagosQr[0].order_id).toBe(`pedido_${pedidoId}_1`);
  });

  it('sanidad: la app sigue arrancando con el modelo nuevo cargado', async () => {
    const res = await request(app).get('/api/v1/salud');
    expect(res.status).toBe(200);
  });
});
```

- [ ] **Step 8: Correr los tests**

Run: `cd backend && npm test -- pagos_qr.model.test.js`
Expected: 3/3 tests PASS.

- [ ] **Step 9: Commit**

```bash
git add backend/database/migrations/015_pagos_qr.sql backend/src/models/PagoQr.js backend/src/models/Pedido.js backend/src/models/index.js backend/.env.example backend/tests/pagos_qr.model.test.js
git commit -m "feat(pagos-qr): tabla pagos_qr, modelo PagoQr y estado pendiente_pago en Pedido"
```

(`backend/.env` no se commitea — está en `.gitignore`.)

---

