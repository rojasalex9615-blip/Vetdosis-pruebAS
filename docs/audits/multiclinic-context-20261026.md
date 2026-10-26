# Auditoría multiclínica — frente A (#32)

Base: PR #36, commit 37392447dd263cd012c78f41513d1b648703dae6.

## Hechos comprobados en código
- SupabaseAuthRepository.memberships() devuelve una lista de membresías; la instalación existente utiliza workspace_memberships().
- AuthViewModel.selectClinic() permite activar una membresía presente; refresh() conserva la clínica si sigue autorizada.
- MaterialApp tiene ValueKey de usuario, clínica, rol y sesión; esto reconstruye la interfaz al cambiar de contexto.
- SyncScope incluye userId y clinicId para partición de operaciones offline.

## Riesgos que requieren pruebas (no vulnerabilidades confirmadas)
1. Solicitud iniciada en clínica A y completada después de cambiar a B: impedir que actualice estado visible o guarde bajo contexto equivocado.
2. Formulario con cambios sin guardar: solicitar guardar, descartar o cancelar el cambio, sin arrastrar datos.
3. Revocación de membresía mientras se opera: revalidar autorización en servidor antes de escritura; no confiar solo en el selector o caché de acceso offline.
4. Diferencias de rol entre clínicas: volver a obtener permisos y preferencias, no reutilizar autorizaciones de A.
5. Cambio de clínica con alarmas de hospitalización activas: mantener las alarmas correspondientes, pero aislar sus datos y revalidar destinatarios.
6. Respuestas tardías de RPC, Storage, notificaciones o búsquedas: etiquetar con userId, clinicId y revisión de contexto, descartar si cambia.

## Contrato propuesto
- Una cuenta puede tener N membresías; cada operación debe tener exactamente un clinicId explícito.
- La clínica activa no otorga privilegios; las RPC/RLS comprueban membresía y permisos actuales.
- Preferencias C/U/D no cruzan ámbitos. Nunca migrar preferencias locales de otra cuenta.
- Al cambiar de clínica, invalidar caches/pantallas y proteger formularios pendientes. No purgar operaciones offline legítimas de otra clínica.
- Los trabajos asíncronos solo aplican resultados si usuario, clínica y revisión siguen coincidiendo.

## Próximas verificaciones
- Pruebas Flutter: dos clínicas con roles distintos; respuesta tardía; cambio con formulario; membresía revocada; cambio offline; retorno a clínica original.
- Pruebas Supabase Pruebas: RLS con dos cuentas y dos clínicas, sin datos reales, previa coordinación.
- Revisión de todos los puntos de entrada: navegación, búsquedas, dashboard, archivos, cálculos, hospital y preferencias.

No modifica Auth, Hospital, Operations, Storage, respaldos, SQL ni servicios activos. Documento de revisión, no certificación de seguridad.
