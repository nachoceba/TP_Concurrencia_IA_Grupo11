# TP6 Parte A — Requirements (Kiro spec: roles)

Formato EARS: WHEN <evento> / WHILE <estado> / WHERE <ubicación>.
Cada rol lleva 1 oración con qué operación habilita y por qué esa y no otra.

## REQ-01 — rol_app_lectura
- WHEN la app web necesita mostrar catálogo, pedidos o usuarios seguros, el sistema SHALL otorgar SELECT sobre v_categorias_vigentes, v_productos_vigentes, v_pedidos_resumen, v_pedido_detalle, v_catalogo_productos, v_usuarios_segura y mv_top_productos_categoria a rol_app_lectura.
- Oración: habilita solo SELECT sobre vistas/MV vigentes porque la app de lectura nunca debe tocar tablas base ni escribir.
- EARS: WHEN se renderiza catálogo o resumen WHERE esquema public WHILE el pedido está vigente, THEN solo lectura vía vistas.

## REQ-02 — rol_app_escritura
- WHEN la app necesita crear un pedido, el sistema SHALL otorgar únicamente EXECUTE sobre PROCEDURE sp_crear_pedido(BIGINT, forma_pago, JSONB) a rol_app_escritura (hereda SELECT de rol_app_lectura).
- Oración: habilita EXECUTE del procedimiento y no INSERT directo porque centraliza validación, subtotal/total por trigger y precio congelado en una sola vía auditada.
- EARS: WHEN se confirma una compra WHERE esquema public WHILE el carrito es válido, THEN crear vía CALL y nunca con INSERT directo.

## REQ-03 — rol_soporte
- WHEN soporte atiende un reclamo, el sistema SHALL otorgar SELECT sobre v_pedidos_resumen, v_usuarios_segura, v_pedido_detalle + SELECT por columnas (id_usuario, nombre, apellido, mail, celular, rol) sobre tabla usuario + EXECUTE sobre FUNCTION calcular_total_pedido(BIGINT).
- Oración: habilita ver pedidos/usuarios sin contrasena y recalcular totales porque soporte diagnostica sin modificar datos ni ver credenciales.
- EARS: WHILE hay un ticket abierto WHERE vistas seguras, THEN soporte lee detalle y recalcula, sin escribir.

## REQ-04 — rol_reportes
- WHEN el área de negocio pide tableros, el sistema SHALL otorgar SELECT sobre mv_top_productos_categoria y v_pedidos_resumen a rol_reportes.
- Oración: habilita solo esas dos fuentes agregadas porque reportes consume datos precalculados y no necesita detalle por usuario ni tablas base.
- EARS: WHEN se genera un reporte mensual WHERE MV y resumen WHILE la MV está refrescada, THEN leer sin tocar tablas transaccionales.

## REQ-05 — rol_auditor
- WHEN auditoría revisa integridad, el sistema SHALL otorgar SELECT sobre v_pedidos_resumen, v_usuarios_segura, mv_top_productos_categoria + EXECUTE sobre FUNCTION calcular_total_pedido(BIGINT) a rol_auditor.
- Oración: habilita lectura de control y recálculo porque el auditor verifica totales sin alterar pedidos ni ver contrasenas.
- EARS: WHILE hay una auditoría WHERE vistas seguras y función de cálculo, THEN verificar sin privilegios de escritura.

## REQ-06 — logins app_web / admin_datos
- WHEN se despliega la app o se conecta el admin, el sistema SHALL mapear app_web → rol_app_escritura (hereda lectura) con CONNECTION LIMIT 20 y admin_datos → rol_auditor con CONNECTION LIMIT 5, ambos con search_path=public,pg_temp.
- Oración: habilita logins con límite de conexiones y herencia porque separa carga operativa (web) de control (admin) sin dar superusuario.
- EARS: WHEN hay conexión entrante WHERE base food_store_parcial WHILE hay slots libres, THEN aceptar según límite y search_path fijo.

## Seguridad transversal
- REQ-SEC-01 (sin password en claro): WHERE repo TP6/sql/roles.sql, el sistema SHALL NOT contener literales PASSWORD; las claves se setean fuera con `\password` o variable de entorno.
- REQ-SEC-02 (REVOKE PUBLIC): WHEN se aplica el script WHERE esquema public y base, THEN revocar ALL/CREATE de PUBLIC antes de otorgar (Bloque 0).
- REQ-SEC-03 (DEFAULT PRIVILEGES): WHILE se creen tablas/funciones futuras WHERE esquema public FOR ROLE postgres, el sistema SHALL aplicar ALTER DEFAULT PRIVILEGES (SELECT a lectura/soporte/reportes/auditor; EXECUTE a escritura).
- REQ-SEC-04 (NOLOGIN): WHERE los 5 roles de grupo, el sistema SHALL crearlos WITH NOLOGIN para que nadie conecte directo con ellos.
- REQ-SEC-05 (mínimo privilegio): WHEN se crea un pedido WHERE tablas pedido/detalle_pedido, el sistema SHALL negar INSERT/UPDATE directo y exigir sp_crear_pedido.
- REQ-SEC-06 (search_path): WHEN cualquier login aplica WHERE base, el sistema SHALL fijar search_path=public,pg_temp para evitar hijack vía pg_temp o esquemas trampa.
