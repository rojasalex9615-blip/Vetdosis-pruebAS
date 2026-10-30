# Correcciones de los tres hallazgos de #64

PR de seguimiento #66, rama `fix/p64-calculation-lifecycle-20261028`.
Base #65 `d6152af653d87ff1c1bf68bae7822a1b39aca1e7`, que conserva la entrega y
la evidencia de contratos ya instalados en Pruebas. No se reescriben las ramas
anteriores de la cadena ni se fusiona main.

Código funcional: `ea602a7bbb4dc5722da23431ab651c30fd728b5e`.
Corrección de arranque de pruebas: `a574d543b8cb93e84e9d6d46a45b77238b7c50a0`.

## Resultado

1. La CI P1 ejecuta ambos jobs en cualquier PR. El filtro anterior omitía cambios
   exclusivos a migraciones y dominio. Conserva permisos de solo lectura,
   acciones fijadas por SHA y añade cancelación de ejecuciones anteriores de la
   misma referencia.
2. `HospitalCalculationAccessScope` posee el acceso en el State de la ruta:
   crea en initState y libera en dispose. El acceso permanece vivo durante la
   animación de salida y se cancela al desmontar el Navigator por cambio de sesión.
   El cálculo usa un contexto de esa ruta y conserva las comprobaciones de peso,
   clínica, usuario, rol y permisos. Se elimina el finally ligado al push Future.
3. Las revalidaciones concurrentes comparten un resultado pendiente, que completa
   la solicitud vigente. No esperan el RPC antiguo para continuar si una nueva
   comprobación ya terminó. Resultados y errores anteriores no cambian el acceso;
   la última revocación/error deniega y dispose resuelve las esperas como false.

No cambian fórmulas, validaciones de peso, datos clínicos, contratos ni permisos
personales. No se ejecutó SQL remoto, no se activaron proveedores ni se generó APK.
Los tres hilos originales de #64 tienen respuestas con el PR y las pruebas; no se
marcan como integrados en su punta, que todavía conserva el código anterior.

## Pruebas

`flutter test --no-pub test/hospital_calculation_refresh_test.dart`: **15 aprobadas**,
incluidas seis nuevas: permitido/revocado/error durante refresh concurrente,
dispose con RPC pendiente y dos rutas reales (pop/logout-login).

Se restauraron temporalmente los dos archivos funcionales de la base y se
repitieron exactamente tres regresiones. Las tres fallaron como corresponde:
pop invalida antes del desmontaje, logout/login revive el acceso anterior y la
comprobación permitida queda esperando la respuesta supersedida. Luego se
restauró la corrección. Resultado íntegro en `baseline-regressions.txt`.

Los widgets usan el catálogo real empaquetado, leído en setUpAll y cargado en las
preferencias simuladas. Evita que la decodificación/I/O del asset bajo FakeAsync
oculte el resultado del ciclo de vida cuando se ejecutan varios widgets juntos.
No se usan dosis inventadas ni cambia la carga de catálogos de la aplicación.

`flutter test --no-pub`: **691 aprobadas, 1 omitida, cero fallos**.
`flutter analyze --no-pub`: limpio.
`bash supabase/tests/run_financial_return_freshness.sh`: aprobado; incluye carreras
de reintegros, devoluciones/reversos y abonos/devoluciones en PostgreSQL aislado.

La primera CI de contratos en ea602a7 falló antes de cargar los fixtures:
run 40684825024, job 122804368962, socket PostgreSQL inexistente. El chequeo con
pg_isready por socket aceptaba el servidor temporal de initdb; al reiniciarlo,
psql perdía el socket. Se espera ahora TCP localhost, habilitado solo por el
servidor final. Reproducción en contenedor frío con init SQL pausado: socket
responde mientras TCP todavía no, y el servidor final acepta SELECT 1 al estar TCP
listo. Evidencia en `postgres-readiness.txt`. La suite completa del upgrade aislado
pasó después del cambio y su CI 40685168731 terminó success en a574d54; no se modificó el generador ni el SQL desplegado.

CI sobre a574d54: P1, contratos, hospitalización y modo revisión success. El workflow
de historia/carnet sigue en curso (SQL aprobado; batería Flutter y compilación
Android debug en ejecución). Esa compilación no entrega una APK beta configurada
ni equivale a QA de teléfono.

Resultados completos, CI y estado real de revisión se consignan en `validation.json`
y en el issue #31. La evidencia local no equivale a resultado de GitHub Actions ni
a aprobación de CodeRabbit. La revisión se solicitó en #66, comentario 6468496044.

## Pendientes

Revisión de CodeRabbit, incorporación de la corrección a la cadena y validación
integral con sesiones reales de dos clínicas. Después, APK y QA Android. Esta
entrega no declara lista la beta ni certifica aislamiento REST remoto, alarmas
reales o recuperación integral del servicio.
