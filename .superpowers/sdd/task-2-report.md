STATUS: DONE

Commits:
- [PENDIENTE] feat: configurar conexión Sequelize con MySQL y timezone Bolivia

Tests: N/A

Archivos creados:
- src/config/database.js

## Notas
- Archivo `src/config/database.js` creado con la configuración exacta del brief
- Sequelize configurado con dialect MySQL, timezone America/La_Paz
- Timestamps en español: creado_en, actualizado_en
- Propiedades underscored activadas
- Logging condicional según NODE_ENV
- .env verificado: contiene DB_HOST, DB_NAME, DB_USER, DB_PASS
- Prueba de conexión ejecutada (error de DB esperado sin base de datos activa)
- server.js restaurado a estado original (sin bloque temporal)
