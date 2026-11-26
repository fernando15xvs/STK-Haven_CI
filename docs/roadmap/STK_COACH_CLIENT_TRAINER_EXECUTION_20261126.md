# Coach cliente + entrenador — entrega integrada A–H
Base CI 45889992134 verde. PR privada #57 draft; espejo únicamente Actions. Web pausada.
## A — Activación privada
- [x] Funciones administrativas privadas de trial y revocación, máximo 30 días, 5 clientes; cuenta confirmada y capability coach, sin sobreescribir entitlement comercial. No grant automático. El CI prueba dos entrenadores ficticios y un cliente.
- [ ] Después del CI: identificar entrenador y cliente permanentes y autorizar cuenta de desarrollo. Nunca insertar datos ficticios en remoto ni simular una compra.
## B — Privacidad
- [x] Cachés de relaciones, progreso, programas, tareas, guías y check-ins ligados a identidad; respuestas tardías descartadas; cargas fallidas limpian datos protegidos. Revalidación al volver a las vistas protegidas y cambios de consentimiento invalidan proveedores.
- [x] Corregir SQL histórico: listado de check-ins y adherencia de coach excluyen datos de otro coach del mismo cliente; comentarios comprueban sesión permanente y permisos.
- [x] No borrar programas instalados, historial personal ni datos Hive al revocar; preservar historial del cliente.
- [ ] QA de cambio de cuenta durante escritura local, revocación en dos dispositivos y reconexión. No afirmar revocación en tiempo real de una vista ya abierta sin revalidación.
## C — Progreso y medidas
- [x] Fecha de generación, publicación coalescida, indicador de sincronización pendiente y reintento explícito; no bucles automáticos tras fallos.
- [x] Medidas: registro elegido, campos inicialmente desmarcados, publicación explícita por relación, solo snapshot seleccionado, lectura del entrenador exige entitlement y permiso. Revocación purga copia, no historial Hive; regrant no recupera datos antiguos. No notas/fotos.
- [ ] Deploy y QA con dos cuentas, sin importar datos reales al espejo.
## D/E — Cliente y entrenador
- [x] Ficha compacta del cliente con programas, tareas, check-ins, guía, progreso y medidas; permisos y revocar en expansión. Cartera profesional como entrada cuando el entitlement está activo; invitar/conexiones desde cabecera. Ficha Pro integra acciones existentes.
- [x] Roles separados, sin pestañas principales adicionales, sin UI en Core.
## F — Integración
- [x] Reutilizar contratos de programas/versiones/instalación local, tareas recurrentes, comentarios y guías existentes. Filtrar listas por relación cuando se entra desde Mi Coach, adherencia de cada relación separada para ambos roles; RPC legado limita al coach a sus propias tareas. Cliente no puede asignarse programa por lista vacía.
- [ ] Smoke físico cliente/coach (invitación, consentimiento parcial, asignar, revisar, instalar, completar, compartir, retirar, revocar, expiración).
## G — Coach Inteligente
- [x] Motor Dart determinista, evidencia textual, ventanas de 7/30 días, datos recientes, mínimo de observaciones, frecuencia, volumen, e1RM estimado, estabilidad y recuperación percibida. UI claramente STK, solo sugerencias, nunca autoedita prescripciones. No datos externos ni diagnósticos.
- [ ] En producto futuro, feedback persistente y ajustes de plan auditables si se aprueba; no se afirma copiloto generativo ni autoaplicación.
## H — Validación
- [x] Pruebas Dart, widgets específicos existentes, 27 pgTAP nuevas en instancia desechable; CI conserva siete jobs y web congelada. Fuente SQL nueva en supabase/pending/stk_coach_secure_completion.sql. El entorno de edición no tiene Supabase CLI: el job usa la CLI fijada para generar el archivo real, valida upgrade y rebuild, publica el archivo como artefacto stk-coach-secure-migration. Cuando se autorice despliegue, reconciliar el nombre canónico con ledger y conservar la fuente sin reaplicar SQL.
- [ ] Resultado del CI, QA física, publicación remota de la migración (solo tras autorización), activación trial y firma iOS. Sin merge, sin pagos ni cambios remotos realizados en esta entrega.

## Corrección del CI 45892803830
- Analyze Mobile: quitar la segunda aserción `!` redundante en la apertura de una versión histórica de orientación alimentaria (Dart ya promueve el campo final a no nulo).
- pgTAP incremental: corregir dos delimitadores de cadenas SQL de las pruebas de aislamiento de adherencia y revocación de trial; mantener las 27 comprobaciones. El CI anterior alcanzó 17 sin fallos antes del error de sintaxis.
- Mobile tests, iOS, Anatomical QA y Edge Functions pasaron en el CI anterior. Se vuelve a ejecutar el gate completo sin cambios de configuración; no se ha modificado Supabase remoto.
