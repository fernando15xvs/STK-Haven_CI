# Medidas y descanso configurable

## Medidas (Android / iOS)

En Progreso > Medidas se puede activar un aviso cada 1, 2 o 3 meses, elegir
la hora y guardarlo. Está desactivado por defecto. Usa meses de calendario
contados desde el registro más reciente; el día se limita al último del mes
destino (31 de enero + 1 mes = 28/29 de febrero).

Se programa un único aviso por ciclo, incluso con la app cerrada. Al guardar
nuevas medidas se reemplaza; editar registros antiguos no reinicia el plazo.
Al eliminar el último registro se cancela. Al activar un plazo ya vencido se
programa un aviso aproximadamente un minuto después, sin repetirlo en cada
arranque. Las restricciones de batería de Android pueden retrasar la entrega.
No requiere cambios en Supabase ni procesos periódicos. Preferencia local.

El ID 1601 está reservado para esta familia; no cancela versículos, entrenamientos
ni mensajes personales. Comprueba permisos, capacidad de iOS y programación.
Un fallo de recordatorio nunca elimina las medidas guardadas: la pantalla avisa
y permite reintentar. Guardar el recordatorio confirma la preferencia.

La evolución muestra una gráfica temporal por medida, primer/último valor,
cambio absoluto y relativo. Omite ausencias y valores inválidos; requiere dos
fechas distintas. Peso respeta kg/lb. Grasa expresa diferencia en puntos
porcentuales. No etiqueta un aumento de perímetro como ganancia muscular.

## Descanso (preferencias de entrenamiento)

- **La serie completada**: comportamiento anterior y predeterminado de migración.
- **La siguiente serie**: usa el tiempo de la próxima serie pendiente en el
  orden actual de la sesión; salta completadas y ejercicios vacíos, y vuelve a
  series anteriores pendientes si el usuario las omitió. Sin pendientes no
  inicia descanso. Cambiar el orden de ejercicios modifica la secuencia.
- Desactivar descanso automático permite conservar el control manual.

Ejemplo: dos ejercicios con C15/A30/A30/E120/E120. En modo siguiente serie,
los descansos al completar cada serie son 30/30/120/120/**15** para el primero,
y 30/30/120/120/0 para el último. Los valores son descansos, no duración del
esfuerzo. Los tiempos siguen configurándose por ejercicio/tipo de serie.

Las superseries explícitas conservan su coordinación por ronda (sin descanso
entre sus mitades y máximo configurado al cerrar la ronda). El descanso entre
lados unilaterales sigue siendo independiente; la nueva política actúa después
de completar ambos lados. La preferencia se serializa en SettingsState y backups.

## Verificación

Pruebas de calendario, ausencias/porcentajes, ciclo de notificaciones nativo
simulado (permisos, capacidad, cancelación, actualización, fallos), secuencia
curl/extensiones y compatibilidad de superseries. Prueba de interfaz a 320 px.
Pendiente la recepción real en teléfono tras instalar el build actualizado.
