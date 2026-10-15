# Informe de Laboratorio: Concurrencia y Anomalías en PostgreSQL

---

## Escenario 1: Espera por Bloqueo (Locking)

| *Escenario* | Espera por bloqueo (Locking / Exclusive Lock) sobre la tabla producto. |
| *Cómo se reprodujo* | *Sesión A (Terminal 1):<br>BEGIN;<br>SELECT * FROM producto WHERE id_producto = 1 FOR UPDATE;<br><br>Sesión B (Terminal 2):<br>BEGIN;<br>UPDATE producto SET precio = 2000.00 WHERE id_producto = 1;<br>(B queda esperando)<br><br>Sesión A:<br>COMMIT;<br><br>Sesión B:*<br>COMMIT; |
| *Qué se observó* | Al ejecutar el UPDATE en la Sesión B, la terminal se pausó (quedó congelada) esperando la liberación del recurso. Al ejecutar COMMIT; en la Sesión A, la Sesión B se destrabó automáticamente, ejecutó la actualización y devolvió UPDATE 1. |
| *Explicación de la IA* | (Se adjunta la respuesta de OpenCode) |
| *Verificación en el motor* | Se confirmó en el motor real. Al liberar la transacción en A con COMMIT;, PostgreSQL asignó el bloqueo a B de forma ordenada sin perder la integridad de los datos. |
| *Conclusión* | Dado el caso de la espera por bloqueo, se confirma la explicación de la inteligencia artificial. Para evitar este tipo de bloqueos
debemos mantener las transacciones lo más cortas posible y acceder a las filas en un orden consistente entre sesiones (evita deadlocks). |

---

## Escenario 2: Lectura No Repetible (Unrepeatable Read)

| Campo | Contenido |
| :--- | :--- |
| *Escenario* | Lectura No Repetible (Unrepeatable Read) sobre la tabla producto. |
| *Cómo se reprodujo* | *Sesión A (Terminal 1):<br>BEGIN;<br>SELECT precio FROM producto WHERE id_producto = 1;<br><br>Sesión B (Terminal 2):<br>BEGIN;<br>UPDATE producto SET precio = 9999.00 WHERE id_producto = 1;<br>COMMIT;<br><br>Sesión A:*<br>SELECT precio FROM producto WHERE id_producto = 1;<br>COMMIT; |
| *Qué se observó* | En la primera lectura dentro de la transacción, la Sesión A leyó $1500.00. Luego de que la Sesión B actualizara y confirmara el precio, la Sesión A reejecutó la consulta y leyó $9999.00 dentro de la misma transacción. |
| *Explicación de la IA* | (Se adjunta la respuesta de OpenCode) |
| *Verificación en el motor* | Se configuró SET TRANSACTION ISOLATION LEVEL REPEATABLE READ; al inicio de la Sesión A. Al reejecutar la prueba, la segunda lectura de A mantuvo el valor original ($1500.00), aislando la transacción de las modificaciones confirmadas por B. |
| *Conclusión* | *La explicación de la IA se confirmó.* El problema se resuelve elevando el nivel de aislamiento a *REPEATABLE READ*, el cual utiliza snapshots estáticos mediante MVCC. |

---

## Escenario 3: Lectura Fantasma (Phantom Read)

| Campo | Contenido |
| :--- | :--- |
| *Escenario* | Lectura Fantasma (Phantom Read) sobre la tabla pedido. |
| *Cómo se reprodujo* | *Sesión A (Terminal 1):*<br>BEGIN;<br>SELECT COUNT(*), SUM(total) FROM pedido WHERE estado = 'PENDIENTE';<br><br>*Sesión B (Terminal 2):<br>BEGIN;<br>INSERT INTO pedido (fecha, estado, total, forma_pago, usuario_id) VALUES (CURRENT_DATE, 'PENDIENTE', 1000.00, 'EFECTIVO', 1);<br>COMMIT;<br><br>Sesión A:*<br>SELECT COUNT(*), SUM(total) FROM pedido WHERE estado = 'PENDIENTE';<br>COMMIT; |
| *Qué se observó* | La primera lectura en A devolvió COUNT = 1 y SUM = 3000.00. Tras el INSERT y COMMIT de la Sesión B, la segunda consulta en A devolvió COUNT = 2 y SUM = 4000.00, incluyendo el registro "fantasma". |
| *Explicación de la IA* | (Se adjunta la respuesta de OpenCode) |
| *Verificación en el motor* | Se reejecutó el experimento en la Sesión A con SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;. En la segunda consulta, los agregados se mantuvieron en COUNT = 1 y SUM = 3000.00, ignorando el nuevo registro de B. |
| *Conclusión* | *La explicación de la IA se confirmó.* En PostgreSQL, el nivel de aislamiento *REPEATABLE READ* resuelve también las lecturas fantasmas gracias a la arquitectura MVCC del motor. |