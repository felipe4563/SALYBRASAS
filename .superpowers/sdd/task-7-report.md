STATUS: DONE_WITH_CONCERNS

Commits: 225bf7b
Tests: 2/5 pasando | 3 fallaron por falta de conexión MySQL
Concerns: La base de datos MySQL no está disponible en tiempo de prueba (ER_ACCESS_DENIED_ERROR: Access denied for user ''@'localhost' using password: NO). Las variables de entorno DB_USER/DB_PASS/DB_NAME no están cargadas en el entorno de test. Los 2 tests que no requieren DB pasan correctamente (rechaza sin body → 400, rechaza sin token → 401). Los 3 restantes requieren MySQL activa con seed ejecutado.
