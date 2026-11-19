import '../modules/hospital/presentation/hospital_calculation_access.dart';
import 'widgets/accent_glow.dart';
import 'widgets/brand_gradient.dart';
import 'widgets/contrast.dart';
import 'widgets/screen_title.dart';
import '../modules/hospital/presentation/hospital_dose_patient_screen.dart';
import '../modules/clinic_experience/domain/clinic_experience.dart';
import '../modules/clinic_experience/domain/clinic_experience_repository.dart';
import '../modules/clinic_experience/presentation/clinic_experience_boundary.dart';
import '../modules/clinic_experience/presentation/clinic_experience_screen.dart';
import '../modules/auth/presentation/team_duty_screen.dart';
import '../modules/notifications/data/inbox_source.dart';
import '../modules/notifications/presentation/notification_bell_menu.dart';
import '../modules/review/domain/review_catalog_repository.dart';
import '../modules/review/presentation/review_catalog_screen.dart';
import '../modules/auth/domain/auth_repository.dart';

import 'dart:math' as math;

import 'widgets/app_version_label.dart';
import '../modules/finance/presentation/financial_planning_panel.dart';
import '../modules/operations/presentation/productivity_screen.dart';
import '../modules/core/presentation/section_menu.dart';
import '../modules/exotics/presentation/exotics_menu.dart';
import '../modules/production/presentation/production_menu.dart';
import '../modules/production/domain/porcino_repository.dart';
import '../modules/production/domain/production_unit_repository.dart';
import '../modules/dashboard/presentation/home_pilot.dart';
import '../vet_ui/vet_theme.dart';
import 'widgets/neu_identity.dart';
import '../modules/beta/domain/beta_repository.dart';
import '../modules/beta/presentation/beta_boundary.dart';
import '../modules/identity/domain/identity_repository.dart';
import '../modules/identity/presentation/identity_panel.dart';
import '../modules/dashboard/presentation/alert_preferences_panel.dart';
import 'widgets/workspace_panel.dart';
import '../modules/dashboard/presentation/dashboard_screen.dart';
import '../modules/dashboard/presentation/dashboard_view_model.dart';
import '../modules/core/domain/navigation_access.dart';
import '../modules/core/domain/module_access.dart';
import '../modules/core/presentation/module_access_boundary.dart';
import '../modules/inventory/presentation/quick_scan_screen.dart';
import '../modules/support/domain/support_repository.dart';
import '../modules/support/presentation/support_screen.dart';
import '../modules/welcome/presentation/product_screen.dart';
import '../modules/laboratory/domain/lab_repository.dart';
import '../modules/laboratory/presentation/lab_screen.dart';
import '../modules/welcome/presentation/public_welcome_screen.dart';
import '../modules/welcome/presentation/guided_start_screen.dart';
import '../modules/ai/domain/ai_repository.dart';
import '../modules/ai/presentation/ai_screen.dart';
import '../modules/ai/presentation/starter_help_panel.dart';
import '../modules/subscriptions/domain/subscription_repository.dart';
import '../modules/subscriptions/presentation/subscription_screen.dart';
import '../modules/operations/domain/operations_repository.dart';
import '../modules/personal_space/domain/personal_space.dart';
import '../modules/personal_space/presentation/personal_space_screen.dart';
import '../modules/operations/presentation/operations_screen.dart';
import '../modules/operations/presentation/contact_directory_screen.dart';
import '../modules/operations/presentation/promotions_screen.dart';
import '../modules/operations/presentation/commission_panel.dart';
import '../modules/attendance/domain/attendance_repository.dart';
import '../modules/attendance/presentation/attendance_screen.dart';
import '../modules/backup/domain/backup_repository.dart';
import '../modules/backup/domain/drive_backup_client.dart' as drive_auth;
import '../modules/backup/presentation/backup_screen.dart';
import '../modules/inventory/domain/inventory_repository.dart';
import '../modules/inventory/presentation/inventory_screen.dart';
import '../modules/calculations/presentation/calculation_screen.dart';
import '../modules/calculations/data/reference_library_repository.dart';
import '../modules/prescribing/domain/prescribing_repository.dart';
import '../modules/prescribing/presentation/prescribing_screen.dart';
import '../modules/forms/clinical/clinical_repository.dart';
import '../modules/forms/clinical/clinical_screen.dart';
import '../modules/forms/domain/form_repository.dart';
import '../modules/forms/presentation/forms_screen.dart';
import '../modules/hospital/domain/hospital_repository.dart';
import '../modules/hospital/domain/hospital_history.dart';
import '../modules/hospital/application/hospital_alerts.dart';
import '../modules/hospital/application/hospital_push_service.dart';
import '../modules/hospital/presentation/hospital_screen.dart';
import '../modules/aviculture/domain/aviculture_records_repository.dart';
import '../modules/patients/domain/patient_repository.dart';
import '../modules/patients/domain/recorded_weight.dart';
import '../modules/patients/presentation/patients_screen.dart';

import 'package:flutter/material.dart';

import '../modules/doses/presentation/dose_screen.dart';
import '../modules/doses/presentation/dose_label_scanner_screen.dart';
import '../modules/doses/presentation/vademecum_screen.dart';
import '../modules/doses/data/catalog_repository.dart';
import '../modules/doses/presentation/dose_math_tools.dart';
import '../modules/doses/data/personal_dose_repository.dart';
import '../modules/auth/domain/clinic_membership.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

import '../modules/core/presentation/core_view_model.dart';
import '../modules/auth/presentation/auth_view_model.dart';
import '../modules/auth/presentation/auth_screen.dart';
import '../vet_ui/vet_icons.dart';

/// Linea de un control de seleccion en estilo neumorfico.
///
/// Solo hay linea cuando el control esta elegido —o mientras se pulsa o
/// tiene el foco, que es cuando conviene senalarlo—, y es la del primario.
/// En reposo no lleva ninguna: lo que lo separa del fondo es el relieve.
BorderSide? Function(Set<WidgetState>) _neuSide(Color primary) =>
    (states) =>
        states.contains(WidgetState.disabled)
        ? BorderSide.none
        : states.contains(WidgetState.selected) ||
              states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.focused)
        ? BorderSide(color: primary, width: 1.5)
        : BorderSide.none;

/// Relieve del control: levantado en reposo, hundido al pulsar, plano si
/// esta deshabilitado, que es como se comporta una tecla de verdad.
double _neuElevation(Set<WidgetState> states) =>
    states.contains(WidgetState.disabled)
    ? 0
    : states.contains(WidgetState.pressed)
    ? 1
    : 2;

/// Sombra del relieve, en el mismo tono que usan las tarjetas.
Color _neuShadow(bool dark) =>
    dark ? const Color(0x59000000) : const Color(0x47B8BDCE);

/// Los cinco temas del selector de Ajustes, con nombre y semilla.
///
/// El indice 0 es el verdeazulado, que es el tema por omision: Ale lo pidio
/// asi el 11 de noviembre, viendo el morado ya aplicado.
///
/// Conviene saber que esto revierte lo VISIBLE de 54bddae, que habia pasado
/// el primario de verde a morado y esta fusionado en main. No se revierte el
/// commit: el morado no se pierde, baja a ser el segundo tono y se puede
/// elegir en Ajustes. Lo que cambia es cual sale sin tocar nada.
///
/// Los otros cuatro eran colores de catalogo (oceano, indigo, ambar,
/// obsidiana) ajenos a la familia, asi que al elegir uno la app dejaba de
/// parecerse a si misma; pasan a [VetColors].
///
/// Son SEMILLAS, no colores finales. Material 3 deriva de cada una un
/// `primary` y un `onPrimary` que contrastan entre si, que es lo que exige
/// `platform_review_test` a las cinco paletas en los dos brillos. Por eso ya
/// no hace falta elegir a mano un morado claro para oscuro y otro para claro.
const paletteNames = ['Turquesa', 'Amatista', 'Cielo', 'Lila', 'Menta'];
const paletteColors = [
  Color(0xFF087F83),
  VetColors.purple,
  VetColors.brandSky,
  VetColors.brandLilac,
  VetColors.mint,
];

/// Mantiene el Navigator estable, pero elimina las rutas privadas cuando
/// cambia la identidad o el contexto de seguridad de la sesión.
class SessionRouteGuard extends StatefulWidget {
  const SessionRouteGuard({
    super.key,
    required this.auth,
    required this.builder,
  });

  final AuthViewModel? auth;
  final Widget Function(
    BuildContext context,
    GlobalKey<NavigatorState> navigatorKey,
  ) builder;

  @override
  State<SessionRouteGuard> createState() => _SessionRouteGuardState();
}

class _SessionRouteGuardState extends State<SessionRouteGuard> {
  final GlobalKey<NavigatorState> _navigatorKey =
      GlobalKey<NavigatorState>();
  String? _sessionFingerprint;

  String _fingerprint(AuthViewModel? auth) {
    if (auth == null) return 'no-auth';
    final member = auth.active;
    // `offline` no entra: un parpadeo de red lo cambia y no es un cambio de
    // sesion. Incluirlo hacia que `popUntil` devolviera al inicio a media
    // consulta cada vez que se perdia la conexion un momento.
    return [
      auth.repository.userId ?? 'signed-out',
      auth.signedIn,
      auth.recoveringPassword,
      member?.userId ?? '',
      member?.clinicId ?? '',
      member?.role.name ?? '',
    ].join('|');
  }

  @override
  void initState() {
    super.initState();
    _sessionFingerprint = _fingerprint(widget.auth);
    widget.auth?.addListener(_handleSessionChange);
  }

  @override
  void didUpdateWidget(covariant SessionRouteGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.auth != widget.auth) {
      oldWidget.auth?.removeListener(_handleSessionChange);
      _sessionFingerprint = _fingerprint(widget.auth);
      widget.auth?.addListener(_handleSessionChange);
    }
  }

  void _handleSessionChange() {
    final next = _fingerprint(widget.auth);
    if (next == _sessionFingerprint) return;
    _sessionFingerprint = next;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    });
  }

  @override
  void dispose() {
    widget.auth?.removeListener(_handleSessionChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _navigatorKey);
}

/// Raiz de la aplicacion: arma el tema, decide si hay que autenticar y
/// entrega los repositorios que cada modulo necesita.
class VetDosisApp extends StatelessWidget {
  const VetDosisApp({
    super.key,
    required this.model,
    this.auth,
    this.requireAuth = false,
    this.beta,
    this.personalDoses,
    this.patients,
    this.hospital,
    this.hospitalAlerts,
    this.hospitalPushService,
    this.forms,
    this.identity,
    this.clinical,
    this.prescribing,
    this.referenceLibrary,
    this.inventory,
    this.operations,
    this.personalSpace,
    this.attendance,
    this.backup,
    this.googleDriveBackup,
    this.ai,
    this.subscriptions,
    this.support,
    this.moduleAccess,
    this.experienceRepository,
    this.reviewCatalog,
    this.porcino,
    this.units,
    this.aviculture,
    this.inboxSeenStore,
    this.laboratory,
  });
  final CoreViewModel model;
  final AuthViewModel? auth;
  final bool requireAuth;
  final BetaRepository? beta;
  final PersonalDoseRepository? personalDoses;
  final PatientRepository? patients;
  final HospitalRepository? hospital;
  final HospitalAlerts? hospitalAlerts;
  final HospitalPushService? hospitalPushService;
  final FormRepository? forms;
  final IdentityRepository? identity;
  final ClinicalRepository? clinical;
  final PrescribingRepository? prescribing;
  final ReferenceLibraryRepository? referenceLibrary;
  final InventoryRepository? inventory;
  final OperationsRepository? operations;
  final PersonalSpaceRepository? personalSpace;
  final AttendanceRepository? attendance;
  final BackupRepository? backup;
  final drive_auth.DriveBackupClient? googleDriveBackup;
  final AiRepository? ai;
  final SubscriptionRepository? subscriptions;
  final SupportRepository? support;
  final ModuleAccessRepository? moduleAccess;
  final ClinicExperienceRepository? experienceRepository;
  final ReviewCatalogRepository? reviewCatalog;
  final PorcinoRepository? porcino;

  /// Registros de produccion (M15). Null sin sesion de Supabase: entonces
  /// Estadisticas no ofrece la seccion de produccion en vez de fallar.
  final AvicultureRecordsRepository? aviculture;

  /// Donde se guardan las unidades de produccion, si las hay.
  final ProductionUnitRepository? units;

  /// Donde se guarda hasta donde vio la persona la campana. Null usa el
  /// almacen del telefono; las pruebas pasan uno en memoria.
  final InboxSeenStore? inboxSeenStore;
  /// Nulo cuando no hay sesion de Supabase: sin el, el expediente no
  /// ofrece las analiticas en vez de ofrecerlas y fallar al abrirlas.
  final LabRepository? laboratory;
  ThemeData theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final neumorphic = model.settings.visualStyle == 'neu';
    // Tonos tomados de las maquetas de modo oscuro que entrego Ale: grafito
    // neutro con matiz violeta. Si se agrega un color oscuro nuevo, debe salir
    // de esta familia (#201F25, #25242A, #2A2932, #2E2D35, #34333B, #39383F) y
    // no del azul marino anterior, o la pantalla se vera de dos tonos.
    // Medidos sobre las capturas: fondo #201F25 y tarjetas #25242A.
    final background = dark
        ? VetColors.darkCanvas
        : (neumorphic ? neuBackground : VetColors.canvas);
    final surface = dark
        ? VetColors.darkSurface
        : (neumorphic ? neuBackground : VetColors.surface);
    // El tono elegido en Ajustes es la semilla del esquema, TAMBIEN en neu.
    //
    // Antes el neu ignoraba por completo model.settings.palette: sembraba con
    // un color fijo y encima machacaba primary, onPrimary, secondary y
    // tertiary con constantes. El selector de «Elige tu tema» guardaba el
    // indice, pintaba su chip como elegido y no cambiaba ni un pixel. Y como
    // visualStyle viene en 'neu' de fabrica, no cambiaba para nadie.
    //
    // 54bddae cambio CUAL era ese color fijo (de verde a morado), que es lo
    // que se ve hoy, pero el selector seguia muerto. Aqui se arregla lo otro:
    // el tono elegido manda. El morado sigue siendo lo que se ve por omision
    // porque es la semilla del indice 0.
    //
    // Fijar primary a mano era ademas lo que impedia que platform_review_test
    // comprobara algo: recorre las cinco paletas exigiendo 4.5:1 entre primary
    // y onPrimary, y las cinco le devolvian el mismo color. Al sembrar de
    // verdad, esa prueba pasa a medir las cinco, y por eso ya no hace falta
    // escoger a mano el #B69BFF de oscuro ni el #2A1055 de la tinta: M3 los
    // deriva y la prueba los verifica.
    //
    // Lo que el neu si conserva son las SUPERFICIES. El fondo, la placa y la
    // tinta son el ESTILO y salen de las maquetas de Ale; el acento es otra
    // decision, y es la que el selector debe mandar.
    final scheme =
        ColorScheme.fromSeed(
          seedColor: paletteColors[model.settings.palette],
          brightness: brightness,
        ).copyWith(
          surface: neumorphic ? surface : null,
          onSurface: neumorphic && !dark ? neuInk : null,
        );
    final primary = scheme.primary;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // Hasta aqui el tema vivo no pasaba escala tipografica, asi que toda la
      // app corria con la de Material 3, donde un titulo pesa lo mismo que su
      // parrafo. Es la causa de que Caja y Formatos se lean como un muro de
      // texto. La escala es la misma que usa VetTheme, en un solo sitio.
      textTheme: VetTheme.textTheme(brightness, scheme),
      fontFamily: VetTheme.fontFamily,
      scaffoldBackgroundColor: neumorphic ? background : null,
      appBarTheme: neumorphic
          ? AppBarTheme(
              backgroundColor: background,
              surfaceTintColor: Colors.transparent,
              foregroundColor: dark ? null : neuInk,
            )
          : null,
      cardTheme: neumorphic
          // Las tarjetas de Material quedaban del color exacto del lienzo
          // y sin sombra, o sea invisibles: en Hospitalizacion, Vademecum
          // y otras setenta llamadas el contenido flotaba sin caja. Pasan a
          // placa levantada: un punto mas clara que el fondo y con sombra
          // suave. De CardTheme solo sale la sombra de abajo; el par
          // completo sigue siendo cosa de VetCard y WorkspacePanel.
          ? CardThemeData(
              color: neuRaised(dark, background),
              surfaceTintColor: Colors.transparent,
              elevation: 3,
              shadowColor: dark
                  ? const Color(0x99000000)
                  : const Color(0x73A9B0C4),
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            )
          : null,
      inputDecorationTheme: neumorphic
          ? InputDecorationTheme(
              filled: true,
              fillColor: surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              border: NeuInputBorder(dark: dark),
              enabledBorder: NeuInputBorder(dark: dark),
              focusedBorder: NeuInputBorder(
                dark: dark,
                borderSide: BorderSide(color: primary, width: 1.5),
              ),
              errorBorder: NeuInputBorder(
                dark: dark,
                borderSide: BorderSide(color: scheme.error),
              ),
              focusedErrorBorder: NeuInputBorder(
                dark: dark,
                borderSide: BorderSide(color: scheme.error, width: 1.5),
              ),
            )
          : null,
      // Relieve neu en los botones, desde el tema.
      //
      // Antes solo cuatro accesos de Inicio lo llevaban, puestos a mano con un
      // DecoratedBox alrededor en 486b526. El resto de la app seguia con la
      // elevacion de Material: una sombra sola hacia abajo, que no es relieve
      // neu y encima competia con las placas que si lo son. Ahora el degradado
      // entra por el tema y lo reciben los 155 FilledButton y los 123
      // OutlinedButton sin tocar una sola llamada.
      //
      // Lo que NO puede dar el tema es la sombra exterior: ver neuButtonStyle.
      //
      // El OutlinedButton pierde el trazo y gana la placa, que es lo que Ale
      // pidio para los cuatro accesos; el degradado sale de la superficie y no
      // del primary porque un boton secundario no debe pesar como el primario.
      //
      // El TextButton se queda plano a proposito: es la accion de menor
      // jerarquia y levantarlo lo igualaria con los otros dos.
      filledButtonTheme: neumorphic
          ? FilledButtonThemeData(
              // El principal lleva el recorrido aqua → violeta de las
              // referencias; el tono elegido en Ajustes sigue mandando en
              // seleccion, foco, enlaces e iconos.
              style: neuButtonStyle(
                dark,
                base: scheme.primary,
                gradient: neuActionGradient(dark),
                ink: neuActionInk(dark),
                glow: neuGlow(dark),
              ),
            )
          : null,
      // Dos ramas llegaron aqui con una idea cada una y se quedan las dos
      // mitades buenas.
      //
      // El relieve es el degradado (ver neuButtonStyle): la otra rama uso la
      // elevacion de Material y su propio comentario lo admitia, «un
      // neumorfismo a media voz», porque de ButtonStyle solo sale la sombra
      // de abajo, no el brillo de arriba.
      //
      // La LINEA es de ella y se conserva: en reposo no hay ninguna, pero
      // aparece al elegir, pulsar o enfocar. Sin eso, un boton sin borde y
      // sin sombra exterior no acusa el foco, que es como se navega con
      // teclado o con mando.
      outlinedButtonTheme: neumorphic
          ? OutlinedButtonThemeData(
              style: neuButtonStyle(dark, base: neuRaised(dark, surface))
                  .copyWith(
                    side: WidgetStateProperty.resolveWith(_neuSide(primary)),
                    backgroundColor: WidgetStatePropertyAll(
                      neuRaised(dark, surface),
                    ),
                  ),
            )
          : null,
      // Los botones de linea y los chips llevaban un borde gris fijo que los
      // dejaba planos y con el contorno mas oscuro que su propio contenido:
      // la linea pesaba mas que la palabra. La regla pasa a ser la misma
      // para los tres controles de seleccion —linea solo cuando esta
      // elegido, y del primario— y en reposo se levantan en relieve en vez
      // de dibujarse con borde.
      //
      // El relieve que se puede pedir desde ButtonStyle es la sombra de
      // abajo, no el brillo de arriba: un neumorfismo a media voz. El
      // completo necesita pintar las dos sombras, que es lo que hace
      // NeuInputBorder en los campos y queda pendiente para estos.
      segmentedButtonTheme: neumorphic
          ? SegmentedButtonThemeData(
              style: ButtonStyle(
                side: WidgetStateProperty.resolveWith(_neuSide(primary)),
                shadowColor: WidgetStatePropertyAll(_neuShadow(dark)),
                elevation: WidgetStateProperty.resolveWith(_neuElevation),
              ),
            )
          : null,
      chipTheme: neumorphic
          ? ChipThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              side: WidgetStateBorderSide.resolveWith(_neuSide(primary)),
              backgroundColor: surface,
              selectedColor: primary.withValues(alpha: dark ? .22 : .15),
              shadowColor: _neuShadow(dark),
              elevation: 2,
              pressElevation: 1,
            )
          : null,
      navigationBarTheme: neumorphic
          // La pestana activa se rellena con el color de resalte en
          // translucido y lleva un halo leve del mismo tono, segun la
          // referencia de Ale. Antes era una placa clara casi del color de
          // la barra: en el telefono costaba ver cual estaba elegida.
          ? NavigationBarThemeData(
              backgroundColor: surface,
              indicatorColor: primary.withValues(alpha: dark ? .26 : .18),
              indicatorShape: GlowRoundedBorder(
                glow: primary.withValues(alpha: dark ? .42 : .34),
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 0,
            )
          : null,
      // Calendario: el dia elegido es una pastilla con el color primario
      // y el de hoy lleva solo el trazo, como en la maqueta de Agenda.
      datePickerTheme: neumorphic
          ? DatePickerThemeData(
              backgroundColor: surface,
              surfaceTintColor: Colors.transparent,
              dayShape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              dayBackgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? neuActionGradient(dark).first
                    : null,
              ),
              dayForegroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? neuActionInk(dark)
                    : states.contains(WidgetState.disabled)
                    ? scheme.onSurface.withValues(alpha: .38)
                    : scheme.onSurface,
              ),
              todayBackgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? neuActionGradient(dark).first
                    : Colors.transparent,
              ),
              todayForegroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? neuActionInk(dark)
                    : primary,
              ),
              todayBorder: BorderSide(color: primary),
            )
          : null,
      extensions: [
        WorkspaceStyle(neumorphic: neumorphic),
        AccentGlowStyle(enabled: neumorphic),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => SessionRouteGuard(
    auth: auth,
    builder: (context, navigatorKey) => ListenableBuilder(
    listenable: Listenable.merge([model, ?auth]),
    // Keep MaterialApp (and its Navigator/Element tree) stable across
    // auth and clinic updates. Re-keying it here disposed and recreated the
    // whole app subtree during ListenableBuilder notifications, which could
    // invalidate inherited dependencies while Flutter was rebuilding.
    builder: (context, _) => MaterialApp(
      navigatorKey: navigatorKey,
      title: 'VetDosis Pro',
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: model.themeMode,
      home:
          beta != null &&
              auth?.signedIn == true &&
              auth?.recoveringPassword != true
          ? BetaBoundary(
              key: ValueKey('beta:${auth!.repository.userId}'),
              repository: beta!,
              clinicId: auth!.active?.clinicId,
              canSponsor: auth!.active?.role == ClinicRole.admin,
              onSignOut: auth!.repository.signOut,
              onRefresh: () => auth!.refresh(),
              child: shell(context),
            )
          : shell(context),
    ),
  ),
  );

  Widget shell(BuildContext context) =>
      requireAuth &&
          (auth == null ||
              auth!.loadingMemberships ||
              !auth!.signedIn ||
              auth!.recoveringPassword ||
              auth!.active == null)
      ? auth?.signedIn == true || auth?.recoveringPassword == true
            ? AuthScreen(model: auth, configured: auth != null)
            : PublicWelcomeScreen(auth: auth)
      : ModuleAccessBoundary(
          member: auth?.active,
          repository: moduleAccess,
          revision: auth?.accessRevision ?? 0,
          builder: (access) => ClinicExperienceBoundary(
            member: auth?.active,
            repository: experienceRepository,
            revision: auth?.accessRevision ?? 0,
            builder: (experience, ready, reload) => CoreShell(
              model: model,
              auth: auth,
              moduleAccess: access,
              moduleAccessRepository: moduleAccess,
              reviewCatalog: reviewCatalog,
              porcino: porcino,
              aviculture: aviculture,
              units: units,
              inboxSeenStore: inboxSeenStore,
              personalDoses: personalDoses,
              patients: patients,
              hospital: hospital,
              hospitalAlerts: hospitalAlerts,
              hospitalPushService: hospitalPushService,
              forms: forms,
              identity: identity,
              clinical: clinical,
              laboratory: laboratory,
              prescribing: prescribing,
              referenceLibrary: referenceLibrary,
              inventory: inventory,
              operations: operations,
              personalSpace: personalSpace,
              attendance: attendance,
              backup: backup,
              googleDriveBackup: googleDriveBackup,
              ai: ai,
              subscriptions: subscriptions,
              support: support,
              experience: experience,
              experienceRepository: experienceRepository,
              experienceReady: ready,
              onExperienceSaved: reload,
            ),
          ),
        );
}

/// Armazon de la sesion iniciada: cabecera, navegacion, menu lateral y el
/// despacho de pantallas por nombre.
class CoreShell extends StatelessWidget {
  const CoreShell({
    super.key,
    required this.model,
    this.auth,
    this.personalDoses,
    this.patients,
    this.hospital,
    this.hospitalAlerts,
    this.hospitalPushService,
    this.forms,
    this.identity,
    this.clinical,
    this.laboratory,
    this.prescribing,
    this.referenceLibrary,
    this.inventory,
    this.operations,
    this.personalSpace,
    this.attendance,
    this.backup,
    this.googleDriveBackup,
    this.ai,
    this.subscriptions,
    this.support,
    this.moduleAccess,
    this.moduleAccessRepository,
    this.experience,
    this.experienceRepository,
    this.experienceReady = false,
    this.onExperienceSaved,
    this.reviewCatalog,
    this.porcino,
    this.units,
    this.aviculture,
    this.inboxSeenStore,
  });
  final CoreViewModel model;
  final AuthViewModel? auth;
  final PersonalDoseRepository? personalDoses;
  final PatientRepository? patients;
  final HospitalRepository? hospital;
  final HospitalAlerts? hospitalAlerts;
  final HospitalPushService? hospitalPushService;
  final FormRepository? forms;
  final IdentityRepository? identity;
  final ClinicalRepository? clinical;

  /// Nulo sin sesion de Supabase: entonces el expediente no ofrece
  /// las analiticas, en vez de ofrecerlas y fallar al abrirlas.
  final LabRepository? laboratory;
  final PrescribingRepository? prescribing;
  final ReferenceLibraryRepository? referenceLibrary;
  final InventoryRepository? inventory;
  final OperationsRepository? operations;
  final PersonalSpaceRepository? personalSpace;
  final AttendanceRepository? attendance;
  final BackupRepository? backup;
  final drive_auth.DriveBackupClient? googleDriveBackup;
  final AiRepository? ai;
  final SubscriptionRepository? subscriptions;
  final SupportRepository? support;
  final ModuleAccess? moduleAccess;
  final ModuleAccessRepository? moduleAccessRepository;
  final ClinicExperience? experience;
  final ClinicExperienceRepository? experienceRepository;
  final bool experienceReady;
  final Future<void> Function()? onExperienceSaved;
  final ReviewCatalogRepository? reviewCatalog;
  final PorcinoRepository? porcino;

  /// Registros de produccion (M15). Null sin sesion de Supabase: entonces
  /// Estadisticas no ofrece la seccion de produccion en vez de fallar.
  final AvicultureRecordsRepository? aviculture;

  /// Donde se guardan las unidades de produccion, si las hay.
  final ProductionUnitRepository? units;

  /// Donde se guarda hasta donde vio la persona la campana. Null usa el
  /// almacen del telefono; las pruebas pasan uno en memoria.
  final InboxSeenStore? inboxSeenStore;

  /// Whether [member] still matches an online session allowed hospital access.
  bool hospitalWeightContext(ClinicMembership member) =>
      auth?.signedIn == true &&
      auth?.offline == false &&
      auth?.active?.userId == member.userId &&
      auth?.active?.clinicId == member.clinicId &&
      serverAllowed('Hospitalización') &&
      [
        ClinicRole.admin,
        ClinicRole.mvz,
        ClinicRole.auxiliar,
      ].contains(auth?.active?.role);

  bool get canChooseDosePatient =>
      hospital != null &&
      clinical != null &&
      auth?.active != null &&
      hospitalWeightContext(auth!.active!) &&
      serverAllowed('Cálculo rápido');

  Future<void> chooseDosePatient(BuildContext context) async {
    final member = auth?.active;
    if (!canChooseDosePatient || member == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => HospitalCalculationAccessScope(
          auth: auth!,
          member: member,
          initialAccess: moduleAccess,
          repository: moduleAccessRepository,
          builder: (routeContext, access) => HospitalDosePatientScreen(
            hospital: hospital!,
            clinical: clinical!,
            member: member,
            sessionChanges: access,
            contextIsCurrent: () => access.current,
            onCalculate: (weight, validate) => hospitalWeightCalculation(
              routeContext,
              weight,
              validate,
              contextIsCurrent: () => access.current,
              validateAccess: access.revalidate,
            ),
          ),
        ),
      ),
    );
  }

  /// Opens the calculator after rechecking session, module access, and weight.
  ///
  /// [validate] must verify the persisted measurement; its errors propagate.
  /// Returns without navigation if access is unavailable or validation returns
  /// false. The calculator receives the same checks; completion waits for exit.
  Future<void> hospitalWeightCalculation(
    BuildContext context,
    RecordedPatientWeight weight,
    Future<bool> Function(RecordedPatientWeight) validate, {
    bool Function()? contextIsCurrent,
    Future<bool> Function()? validateAccess,
  }) async {
    final member = auth?.active;
    bool sessionCurrent() =>
        contextIsCurrent?.call() ??
        (member != null &&
            hospitalWeightContext(member) &&
            serverAllowed('Cálculo rápido'));
    if (member == null ||
        !sessionCurrent() ||
        member.clinicId != weight.clinicId) {
      return;
    }
    Future<bool> current(RecordedPatientWeight value) async {
      if (!sessionCurrent()) {
        return false;
      }
      if (validateAccess != null && !await validateAccess()) return false;
      final valid = await validate(value);
      return valid && sessionCurrent();
    }

    if (!await current(weight) || !context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Cálculo con peso registrado')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: DoseScreen(
              clinicId: member.clinicId,
              userId: member.userId,
              personalRepository: personalDoses,
              admin: member.role == ClinicRole.admin,
              recordedWeight: weight,
              validateRecordedWeight: current,
              onReviewPatientInstructions:
                  hospitalAlerts != null && patients != null
                  ? (patientId) async {
                      if (!sessionCurrent() ||
                          (validateAccess != null && !await validateAccess())) {
                        return;
                      }
                      if (!context.mounted || !sessionCurrent()) return;
                      // Reuse the complete hospital module, including prescription actions.
                      Navigator.of(context).popUntil((route) => route.isFirst);
                      model.navigate('Hospitalización', patientId: patientId);
                    }
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  // Authorization is independent of the clinic's navigation preferences.
  bool serverAllowed(String page) =>
      navigationAllowed(page, auth?.active, moduleAccess);

  bool allowed(String page) =>
      serverAllowed(page) && (experience?.visible(page) ?? true);
  Future<void> openAccount(BuildContext context) async {
    if (auth == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ClinicAccountScreen(
          model: auth!,
          personalSpaceBuilder: (_) => PersonalSpaceScreen(
            memberships: auth!.memberships,
            repository: auth!.offline ? null : personalSpace,
            medical: !auth!.offline && operations is StaffMedicalRepository
                ? operations as StaffMedicalRepository
                : null,
          ),
          identityBuilder: (_) => Column(
            children: [
              if (auth!.repository.userId != null)
                ProfileHeader(
                  userId: auth!.repository.userId!,
                  repository: identity,
                  title: auth!.active?.displayName,
                  subtitle: auth!.active?.role.label,
                ),
              if (auth!.repository.userId != null)
                ProfileAppearance(
                  key: ValueKey(auth!.repository.userId),
                  userId: auth!.repository.userId!,
                  repository: identity,
                ),
              if (auth!.active != null)
                ClinicIdentity(
                  key: ValueKey(
                    '${auth!.active!.clinicId}:${auth!.active!.role}',
                  ),
                  member: auth!.active!,
                  repository: forms,
                  identity: identity,
                  editable: true,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget bottomNavigation(BuildContext context) {
    final destinations = <(String, IconData)>[
      ('Inicio', VetIcons.home),
      if (allowed('Agenda')) ('Agenda', VetIcons.calendar),
      if (allowed('Pacientes')) ('Pacientes', VetIcons.paw),
      if (allowed('Cálculos')) ('Cálculos', VetIcons.calculator),
      // «Más» abria SectionMenu, el MISMO widget que el cajon lateral: el
      // quinto hueco de la barra repetia lo que el boton de hamburguesa ya
      // daba. Lo cede al asistente, que antes solo se alcanzaba por un icono
      // pequeño de la cabecera. Si no hay asistente (sin repositorio de IA o
      // sin permiso) el hueco vuelve a «Más» en vez de quedarse vacio.
      if (showsAiAction)
        ('Asistente IA', VetIcons.sparkles)
      else
        ('Más', VetIcons.grid),
    ];
    final page = switch (model.screen) {
      'Cálculo rápido' ||
      'Vademécum' ||
      'Operaciones de dosis' ||
      'Cálculos clínicos' => 'Cálculos',
      'Producción y grandes especies' || 'Exóticos' => 'Inicio',
      _ => model.screen,
    };
    final selected = destinations.indexWhere((entry) => entry.$1 == page);
    // Estar en una pantalla que no esta en la barra iluminaba el ULTIMO hueco,
    // que era «Más» y resultaba honesto: ahi se encontraba. Ahora el ultimo es
    // el asistente, y decir «estas en el asistente» cuando estas en
    // Hospitalizacion seria mentira. Sin coincidencia se cae a Inicio, que es
    // la raiz; a esas pantallas se llega por el cajon.
    final respaldo = destinations.indexWhere((entry) => entry.$1 == 'Más');
    return NavigationBar(
      selectedIndex: selected >= 0
          ? selected
          : (respaldo >= 0 ? respaldo : 0),
      onDestinationSelected: (index) => model.navigate(destinations[index].$1),
      destinations: [
        for (final entry in destinations)
          NavigationDestination(
            icon: Icon(entry.$2),
            selectedIcon:
                Theme.of(context).extension<WorkspaceStyle>()?.neumorphic ==
                    true
                ? AccentIcon(
                    entry.$2,
                    color: Theme.of(context).colorScheme.primary,
                    emphasis: .75,
                  )
                : Icon(entry.$2),
            label: entry.$1,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: homePilotTheme(Theme.of(context)),
    child: Builder(builder: _buildShell),
  );

  /// Si la barra lleva el boton de cuenta.
  bool get showsAccountAction => auth != null;

  /// Si la barra lleva el boton del asistente de IA.
  bool get showsAiAction =>
      ai != null && auth?.active != null && allowed('Asistente IA');

  /// Cuantos botones lleva la barra a la derecha.
  ///
  /// De aqui salen tanto el `actions` como el ancho que le queda al titulo,
  /// para que no se calculen por separado y acaben discrepando.
  /// Si la barra lleva el boton de avisos.
  bool get showsNoticesAction =>
      auth?.active != null && allowed('Anuncios y avisos');

  int get barActions =>
      (showsAccountAction ? 1 : 0) + (showsNoticesAction ? 1 : 0);

  static bool _neu(BuildContext context) =>
      Theme.of(context).extension<WorkspaceStyle>()?.neumorphic == true;

  /// La hoja del contenido: en Neu sube con esquinas redondeadas sobre la
  /// banda de marca que continua la de la barra.
  Widget _sheet(BuildContext context, Widget child) {
    if (!_neu(context)) return child;
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: screenHeaderGradient(theme)),
      // Material y no Container: los ListTile de dentro pintan su fondo y
      // sus ondas sobre el Material mas cercano, y un color intermedio se
      // los taparia.
      child: Material(
        color: theme.scaffoldBackgroundColor,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: child,
      ),
    );
  }

  Widget _buildShell(BuildContext context) => PopScope(
    canPop: model.screen == 'Inicio',
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) model.navigate('Inicio');
    },
    child: Scaffold(
      appBar: AppBar(
        // En Neu la barra lleva la banda de marca y la hoja del contenido
        // sube sobre ella; en Clasico se queda con el color del tema.
        backgroundColor: _neu(context) ? Colors.transparent : null,
        scrolledUnderElevation: _neu(context) ? 0 : null,
        flexibleSpace: _neu(context)
            ? DecoratedBox(
                decoration: BoxDecoration(
                  gradient: screenHeaderGradient(Theme.of(context)),
                ),
                child: const SizedBox.expand(),
              )
            : null,
        // El alto se calcula con la misma regla que usa ScreenTitle para
        // decidir si el nombre cabe en una linea o necesita dos. Si no, un
        // titulo de dos lineas se recorta contra una barra pensada para una.
        //
        // El ancho disponible descuenta la hamburguesa y los dos botones de
        // la derecha, que es lo que de verdad deja libre la barra.
        toolbarHeight: auth?.active == null
            ? 56
            : math.max(
                68,
                (model.screen == 'Inicio'
                        ? 44.0
                        : MediaQuery.textScalerOf(context).scale(
                                Theme.of(
                                      context,
                                    ).textTheme.titleLarge?.fontSize ??
                                    22,
                              ) *
                              1.4 *
                              screenTitleFit(
                                model.screen,
                                screenTitleAvailableWidth(
                                  MediaQuery.sizeOf(context).width,
                                  barActions,
                                ),
                                Theme.of(context).textTheme.titleLarge ??
                                    const TextStyle(fontSize: 22),
                                scaler: MediaQuery.textScalerOf(context),
                              ).lines) +
                    MediaQuery.textScalerOf(context).scale(
                          Theme.of(context).textTheme.labelSmall?.fontSize ??
                              11,
                        ) *
                        1.4 +
                    16,
              ),
        title: model.screen == 'Inicio'
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: VetDosisBrand(),
                  ),
                  if (auth?.active != null)
                    Text(
                      auth!.active!.clinicName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              )
            : ScreenTitle(
                screen: model.screen,
                clinic: auth?.active?.clinicName,
              ),
        actions: [
          if (showsAccountAction)
            IconButton(
              tooltip: 'Mi cuenta y clínicas',
              icon: AccountAvatar(
                userId: auth!.repository.userId ?? 'signed-out',
                repository: identity,
              ),
              onPressed: () => openAccount(context),
            ),
          // El asistente bajo a la barra inferior; este hueco es la campana.
          // Despliega las notificaciones personales recientes (anuncios,
          // mensajes, tareas asignadas y cambios a sus turnos) con un
          // marcador de nuevas; «Anuncios y avisos» queda al pie del menu.
          if (showsNoticesAction)
            NotificationBellMenu(
              key: ValueKey(
                'bell:${auth!.active!.userId}:${auth!.active!.clinicId}',
              ),
              source: TeamInboxSource(
                operations: operations,
                duty: auth!.repository is TeamDutyRepository
                    ? auth!.repository as TeamDutyRepository
                    : null,
              ),
              seenStore: inboxSeenStore ?? const PrefsInboxSeenStore(),
              clinicId: auth!.active!.clinicId,
              userId: auth!.active!.userId,
              refreshKey: model.screen,
              onOpenAll: () => model.navigate('Anuncios y avisos'),
              onOpenItem: (item) {
                final route = item.route;
                if (route != null) {
                  model.navigate(route);
                } else if (auth!.repository is TeamDutyRepository) {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => TeamDutyScreen(
                        model: auth!,
                        clinic: auth!.active!,
                      ),
                    ),
                  );
                }
              },
              // Sobre la banda el degradado del icono se perderia: en Neu
              // va dentro de una placa del color del lienzo, como los
              // botones de cabecera de las referencias.
              iconBuilder: (context, _) => _neu(context)
                  ? Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: neuShadows(
                          Theme.of(context).brightness == Brightness.dark,
                          depth: .5,
                        ),
                      ),
                      child: BrandGradientIcon(VetIcons.bell),
                    )
                  : BrandGradientIcon(VetIcons.bell),
            ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              // En Neu el cajon abre con la misma banda de marca que la
              // barra, con el logotipo dentro; en Clasico sigue el renglon.
              if (_neu(context))
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: screenHeaderGradient(Theme.of(context)),
                  ),
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: VetDosisBrand(),
                  ),
                )
              else ...[
                const ListTile(
                  title: Text('VetDosis Pro'),
                  subtitle: Text('Tu espacio veterinario'),
                ),
                const Divider(),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Área de trabajo'),
              ),
              for (final branch in ClinicalBranch.values.where(
                (b) => b != ClinicalBranch.management,
              ))
                ListTile(
                  leading: Icon(branch.icon),
                  title: Text(branch.label),
                  selected: model.branch == branch,
                  onTap: () {
                    Navigator.pop(context);
                    model.selectBranch(branch);
                  },
                ),
              const Divider(),
              ListTile(
                leading: const Icon(VetIcons.clinic),
                title: const Text('Gestión clínica'),
                onTap: () {
                  Navigator.pop(context);
                  model.selectBranch(ClinicalBranch.management);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SectionMenu(
                  member: auth?.active,
                  access: moduleAccess,
                  experience: experience,
                  onNavigate: (page) {
                    Navigator.pop(context);
                    model.navigate(page);
                  },
                  onAccount: auth == null
                      ? null
                      : () {
                          Navigator.pop(context);
                          openAccount(context);
                        },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: bottomNavigation(context),
      floatingActionButton:
          auth?.active != null &&
              allowed('Cálculo rápido') &&
              model.screen != 'Escanear etiqueta para dosis'
          ? AccentGlow(
              color: VetColors.violet,
              radius: 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: brandGradient(),
                ),
                child: FloatingActionButton(
                  heroTag: 'dose-label-scanner',
                  tooltip: 'Escanear etiqueta para dosis',
                  // El degradado lo pinta el contenedor; el botón aporta la
                  // pulsación y el foco, sin tapar ese fondo.
                  backgroundColor: Colors.transparent,
                  // El glifo se mide contra el degradado completo: en blanco
                  // se perdia sobre el extremo turquesa (1.79:1).
                  foregroundColor: inkOnGradient(brandGradientColors),
                  elevation: 0,
                  focusElevation: 0,
                  hoverElevation: 0,
                  highlightElevation: 0,
                  onPressed: () =>
                      model.navigate('Escanear etiqueta para dosis'),
                  child: const Icon(VetIcons.documentScan),
                ),
              ),
            )
          : null,
      body: _sheet(
        context,
        SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              key: ValueKey((
                auth?.active?.userId,
                auth?.active?.clinicId,
                model.branch,
                model.screen,
              )),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 220),
              children: [
                if (auth?.offline == true) ...[
                  const SoftPanel(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Sin conexión · Acceso guardado. La gestión del equipo requiere conexión.',
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => auth!.refresh(),
                    child: const Text('Reintentar conexión'),
                  ),
                  const SizedBox(height: 16),
                ],
                if (model.screen == 'Inicio')
                  HomePracticeSelector(
                    selected: model.branch,
                    onChanged: model.selectBranch,
                  )
                else if (![
                  'Más',
                  'Producción y grandes especies',
                  'Exóticos',
                ].contains(model.screen))
                  DropdownButtonFormField<ClinicalBranch>(
                    initialValue: model.branch,
                    key: ValueKey(model.branch),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Rama de trabajo',
                      border: OutlineInputBorder(),
                    ),
                    items: ClinicalBranch.values
                        .map(
                          (branch) => DropdownMenuItem(
                            value: branch,
                            child: Text(
                              branch.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (branch) {
                      if (branch != null) model.selectBranch(branch);
                    },
                  ),
                const SizedBox(height: 28),
                if (auth?.active != null &&
                    moduleAccess != null &&
                    !serverAllowed(model.screen))
                  const Text(
                    'Este apartado no está disponible con tus permisos actuales.',
                  )
                else if (auth?.active != null &&
                    !(experience?.visible(model.screen) ?? true) &&
                    !(model.screen == 'Hospitalización' &&
                        serverAllowed('Hospitalización')))
                  const Text(
                    'Este apartado está oculto en los ajustes de esta clínica.',
                  )
                else if (model.screen == 'Inicio')
                  ...home(context)
                else if (model.screen == 'Modo revisión')
                  auth?.active != null &&
                          reviewCatalog != null &&
                          allowed('Modo revisión')
                      ? ReviewCatalogScreen(
                          key: ValueKey(
                            'review:${auth!.active!.userId}:${auth!.active!.clinicId}',
                          ),
                          repository: reviewCatalog!,
                          clinic: auth!.active!.clinicId,
                          user: auth!.active!.userId,
                          offline: auth!.offline,
                          canManageClinic: auth!.active!.role == ClinicRole.admin,
                        )
                      : const Text(
                          'El modo revisión requiere una cuenta autorizada y conexión.',
                        )
                else if (model.screen == 'Más')
                  SectionMenu(
                    member: auth?.active,
                    access: moduleAccess,
                    experience: experience,
                    initialGroup: model.branch == ClinicalBranch.management
                        ? 'Administración y finanzas'
                        : null,
                    onNavigate: model.navigate,
                    onAccount: auth == null ? null : () => openAccount(context),
                  )
                else if (model.screen == 'Planeación financiera')
                  allowed('Planeación financiera')
                      ? FinancialPlanningPanel(
                          key: ValueKey(
                            '${auth?.active?.userId}:${auth?.active?.clinicId}',
                          ),
                        )
                      : const Text(
                          'Este apartado no está disponible con tus permisos actuales.',
                        )
                else if (model.screen == 'Cálculos')
                  CalculationMenu(
                    member: auth?.active,
                    access: moduleAccess,
                    experience: experience,
                    onNavigate: model.navigate,
                  )
                else if (model.screen == 'Producción y grandes especies')
                  ProductionMenu(
                    member: auth?.active,
                    access: moduleAccess,
                    onNavigate: model.navigate,
                    porcino: porcino,
                    units: units,
                  )
                else if (model.screen == 'Exóticos')
                  ExoticsMenu(allowed: allowed('Exóticos'))
                else if (model.screen == 'Cálculo rápido')
                  auth == null ||
                          [
                            ClinicRole.admin,
                            ClinicRole.mvz,
                          ].contains(auth!.active?.role)
                      ? DoseScreen(
                          key: ValueKey(
                            '${auth?.active?.userId}:${auth?.active?.clinicId}',
                          ),
                          personalRepository: personalDoses,
                          clinicId: auth?.active?.clinicId,
                          userId: auth?.active?.userId,
                          admin: auth?.active?.role == ClinicRole.admin,
                          offline: auth?.offline ?? false,
                          onChoosePatient: canChooseDosePatient
                              ? () => chooseDosePatient(context)
                              : null,
                        )
                      : const Text(
                          'El cálculo clínico requiere acceso de MVZ o administrador.',
                        )
                else if (model.screen == 'Escanear etiqueta para dosis')
                  auth?.active != null && allowed('Cálculo rápido')
                      ? DoseLabelScannerScreen(
                          member: auth!.active!,
                          personalRepository: personalDoses,
                          offline: auth!.offline,
                        )
                      : const Text(
                          'La lectura de etiquetas para dosis requiere acceso de MVZ o administrador.',
                        )
                else if (model.screen == 'Vademécum')
                  VademecumScreen(
                    key: ValueKey(
                      'vademecum:${auth?.active?.userId}:${auth?.active?.clinicId}',
                    ),
                    catalog: AssetCatalogRepository(),
                    personal: personalDoses,
                    clinicId: auth?.active?.clinicId,
                    userId: auth?.active?.userId,
                    admin: auth?.active?.role == ClinicRole.admin,
                    canCalculate:
                        auth?.active == null ||
                        [
                          ClinicRole.admin,
                          ClinicRole.mvz,
                        ].contains(auth?.active?.role),
                    // El revisor comprueba la pauta calculando la dosis del
                    // empaque; no calcula la dosis clínica por paciente.
                    canCalculateManufacturer:
                        auth?.active == null ||
                        [
                          ClinicRole.admin,
                          ClinicRole.mvz,
                          ClinicRole.revisor,
                        ].contains(auth?.active?.role),
                    offline: auth?.offline ?? false,
                  )
                else if (model.screen == 'Operaciones de dosis')
                  auth == null ||
                          [
                            ClinicRole.admin,
                            ClinicRole.mvz,
                          ].contains(auth!.active?.role)
                      ? DoseMathTools(
                          visualReference: model.settings.visualStyle == 'neu',
                          onChoosePatient: canChooseDosePatient
                              ? () => chooseDosePatient(context)
                              : null,
                        )
                      : const Text(
                          'El cálculo clínico requiere acceso de MVZ o administrador.',
                        )
                else if (model.screen == 'Cálculos clínicos')
                  auth == null ||
                          [
                            ClinicRole.admin,
                            ClinicRole.mvz,
                          ].contains(auth!.active?.role)
                      ? CalculationScreen(
                          patients:
                              auth?.offline == false && allowed('Pacientes')
                              ? patients
                              : null,
                          onFluidReminder:
                              hospital != null &&
                                  auth?.offline == false &&
                                  allowed('Hospitalización')
                              ? (patientId, summary) => model.navigate(
                                  'Hospitalización',
                                  patientId: patientId,
                                  instructions: summary,
                                )
                              : null,
                          referenceLibrary: referenceLibrary,
                          clinicId: auth?.active?.clinicId,
                          showAviculture:
                              model.branch == ClinicalBranch.production,
                          branch: model.branch == ClinicalBranch.management
                              ? ClinicalBranch.small
                              : model.branch,
                          key: ValueKey(
                            '${model.branch}:${auth?.active?.userId}:${auth?.active?.clinicId}',
                          ),
                        )
                      : const Text(
                          'Los cálculos clínicos requieren acceso de MVZ o administrador.',
                        )
                else if (model.screen == 'Pacientes')
                  patients != null && auth?.active != null
                      ? auth!.offline
                            ? const Text(
                                'Los expedientes requieren conexión por ahora. Reconecta para consultar o guardar datos.',
                              )
                            : PatientsScreen(
                                ai: ai,
                                key: ValueKey(
                                  '${auth!.active!.userId}:${auth!.active!.clinicId}:${auth!.active!.role.name}',
                                ),
                                repository: patients!,
                                member: auth!.active!,
                                canOpenActivity: allowed,
                                onOpenActivity: (destination, patientId) async {
                                  if (allowed(destination)) {
                                    model.navigate(
                                      destination,
                                      patientId: patientId,
                                    );
                                  }
                                },
                                onOpenLab:
                                    laboratory != null &&
                                        allowed('Analíticas')
                                    ? (patient) async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (_) => LabScreen(
                                              repository: laboratory!,
                                              clinicId:
                                                  auth!.active!.clinicId,
                                              patientId: patient.id,
                                              patientName: patient.name,
                                              referenceLibrary:
                                                  referenceLibrary,
                                            ),
                                          ),
                                        );
                                      }
                                    : null,
                                onOpenClinical:
                                    clinical != null && forms != null
                                    ? (patient) async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (_) => ClinicalScreen(
                                              repository: clinical!,
                                              prescribing: prescribing,
                                              referenceLibrary:
                                                  referenceLibrary,
                                              forms: forms!,
                                              member: auth!.active!,
                                              patientId: patient.id,
                                            ),
                                          ),
                                        );
                                      }
                                    : null,
                              )
                      : const Text(
                          'Conecta tu cuenta y clínica para abrir pacientes.',
                        )
                else if (model.screen == 'Hospitalización')
                  _hospitalSection(context)
                else if (model.screen == 'Receta')
                  _prescriptionSection()
                else if (model.screen == 'Formatos')
                  forms != null && patients != null && auth?.active != null
                      ? auth!.offline
                            ? const Text(
                                'Los formatos y las firmas requieren conexión. No se guardan documentos sensibles offline.',
                              )
                            : FormsScreen(
                                ai: ai,
                                repository: forms!,
                                clinical: clinical,
                                prescribing: prescribing,
                                patients: patients!,
                                member: auth!.active!,
                              )
                      : const Text(
                          'Conecta tu cuenta y clínica para abrir formatos.',
                        )
                else if (model.screen == 'Escanear producto')
                  inventory != null &&
                          auth?.active != null &&
                          auth?.offline != true &&
                          allowed('Escanear producto')
                      ? QuickScanScreen(
                          repository: inventory!,
                          member: auth!.active!,
                          onOpenLabelScanner: allowed('Cálculo rápido')
                              ? () => model.navigate(
                                  'Escanear etiqueta para dosis',
                                )
                              : null,
                        )
                      : const Text(
                          'Conecta tu cuenta y verifica el acceso a inventario para escanear productos.',
                        )
                else if (model.screen == 'Inventario' || model.screen == 'Caja')
                  inventory != null && auth?.active != null
                      ? auth!.offline
                            ? const Text(
                                'Inventario, ventas y caja requieren conexión para confirmar saldos y permisos.',
                              )
                            : InventoryScreen(
                                identity: identity,
                                ai: ai,
                                key: ValueKey('inventory:${model.screen}'),
                                initialSection: model.screen == 'Caja'
                                    ? 'cash'
                                    : 'stock',
                                repository: inventory!,
                                member: auth!.active!,
                              )
                      : const Text(
                          'Conecta tu cuenta y clínica para abrir inventario.',
                        )
                else if (model.screen == 'Agenda telefónica')
                  operations != null &&
                          auth?.active != null &&
                          auth?.offline != true
                      ? ContactDirectoryScreen(
                          embedded: true,
                          repository: operations!,
                          member: auth!.active!,
                        )
                      : const Text(
                          'El directorio de la clínica requiere cuenta y conexión.',
                        )
                else if (model.screen == 'Productividad y semana')
                  operations is ProductivityRepository &&
                          auth?.active != null &&
                          auth?.offline != true
                      ? ProductivityScreen(
                          embedded: true,
                          repository: operations as ProductivityRepository,
                          member: auth!.active!,
                          ai: ai,
                        )
                      : const Text(
                          'La planificación semanal requiere cuenta y conexión.',
                        )
                else if (model.screen == 'Promociones')
                  operations != null &&
                          auth?.active != null &&
                          auth?.offline != true
                      ? PromotionsScreen(
                          embedded: true,
                          repository: operations!,
                          member: auth!.active!,
                          ai: ai,
                        )
                      : const Text(
                          'Las promociones requieren cuenta y conexión.',
                        )
                else if (model.screen == 'Agenda' ||
                    model.screen == 'Equipo y avisos' ||
                    model.screen == 'Anuncios y avisos' ||
                    model.screen == 'Pendientes del equipo' ||
                    model.screen == 'Servicios' ||
                    model.screen == 'Proveedores')
                  operations != null &&
                          auth?.active != null &&
                          auth?.offline != true
                      ? OperationsScreen(
                          ai: ai,
                          key: ValueKey(
                            'operations:${model.screen}:${auth?.active?.clinicId}:${auth?.active?.userId}:${model.activityPatientId}',
                          ),
                          initialSection: model.screen == 'Servicios'
                              ? 'services'
                              : model.screen == 'Proveedores'
                              ? 'suppliers'
                              : model.screen == 'Equipo y avisos'
                              ? 'messages'
                              : model.screen == 'Anuncios y avisos'
                              ? 'notices'
                              : model.screen == 'Pendientes del equipo'
                              ? 'tasks'
                              : 'appointments',
                          initialPatientId: model.activityPatientId,
                          onNavigate: model.navigate,
                          canOpenInventory: allowed('Inventario'),
                          canOpenSales: allowed('Caja'),
                          repository: operations!,
                          member: auth!.active!,
                          onOpenDuty: auth!.repository is TeamDutyRepository
                              ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => TeamDutyScreen(
                                      model: auth!,
                                      clinic: auth!.active!,
                                    ),
                                  ),
                                )
                              : null,
                          onOpenPatient:
                              patients != null && allowed('Pacientes')
                              ? (id) async {
                                  final member = auth!.active!;
                                  final patientTheme = homePilotTheme(
                                    Theme.of(context),
                                  );
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => Theme(
                                        data: patientTheme,
                                        child: Scaffold(
                                          appBar: AppBar(
                                            title: const Text(
                                              'Paciente de la cita',
                                            ),
                                          ),
                                          body: SingleChildScrollView(
                                            padding: const EdgeInsets.all(20),
                                            child: PatientsScreen(
                                              ai: ai,
                                              repository: patients!,
                                              member: member,
                                              initialPatientId: id,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              : null,
                        )
                      : const Text(
                          'Conecta tu cuenta y clínica para abrir operación y agenda.',
                        )
                else if (model.screen == 'Control de asistencia')
                  attendance != null &&
                          auth?.active != null &&
                          auth?.offline != true
                      ? AttendanceScreen(
                          repository: attendance!,
                          member: auth!.active!,
                        )
                      : const Text(
                          'El control de asistencia requiere conexión con el servidor.',
                        )
                else if (model.screen == 'Estadísticas')
                  DashboardScreen(
                    key: ValueKey((
                      auth?.active?.userId,
                      auth?.active?.clinicId,
                      auth?.offline,
                      moduleAccess,
                      experience?.revision,
                    )),
                    model: DashboardViewModel(
                      member: auth?.active,
                      operations: operations,
                      inventory: inventory,
                      hospital: hospital,
                      patients: patients,
                      backup: allowed('Estadísticas') ? backup : null,
                      attendance: attendance,
                      // M15 y altas: los datos ya existen en la app; aquí
                      // solo se cablean a la pantalla de Estadísticas.
                      aviculture: aviculture,
                      history: hospital is HospitalHistoryRepository
                          ? hospital as HospitalHistoryRepository
                          : null,
                      moduleAccess: moduleAccess,
                    ),
                    offline: auth?.offline ?? false,
                    statisticsOnly: true,
                    isVisible: allowed,
                    identity: identity,
                    experience: experience,
                    onNavigate: model.navigate,
                  )
                else if (model.screen == 'Respaldo' ||
                    model.screen == 'Estadísticas y respaldo')
                  backup != null &&
                          allowed(model.screen) &&
                          auth?.offline != true
                      ? BackupScreen(
                          key: ValueKey(
                            'backup-${auth!.active!.userId}-${auth!.active!.clinicId}',
                          ),
                          identity: identity,
                          repository: backup!,
                          googleDrive: googleDriveBackup,
                          member: auth!.active!,
                          backupOnly: model.screen == 'Respaldo',
                        )
                      : const Text(
                          'Las estadísticas y el respaldo requieren conexión y permiso vigente.',
                        )
                else if (model.screen == 'Asistente IA')
                  ai != null && auth?.active != null && auth?.offline != true
                      ? AiScreen(
                          repository: ai!,
                          member: auth!.active!,
                          preferredProvider: experience?.defaultAiProvider,
                        )
                      : const Text('El asistente requiere cuenta y conexión.')
                else if (model.screen == 'Planes')
                  subscriptions != null &&
                          auth?.active != null &&
                          auth?.offline != true
                      ? SubscriptionScreen(
                          repository: subscriptions!,
                          member: auth!.active!,
                        )
                      : const Text('Los planes requieren cuenta y conexión.')
                else if (model.screen == 'Producto y costos')
                  ProductScreen(onNavigate: model.navigate)
                else if (model.screen == 'Inicio guiado')
                  GuidedStartScreen(
                    scope: '${auth?.active?.userId}:${auth?.active?.clinicId}',
                    onNavigate: (page) {
                      if (page == 'Mi cuenta' && auth != null) {
                        openAccount(context);
                      } else {
                        model.navigate(page);
                      }
                    },
                  )
                else if (model.screen == 'Ayuda y soporte')
                  support != null &&
                          auth?.active != null &&
                          auth?.offline != true
                      ? SupportScreen(
                          repository: support!,
                          member: auth!.active!,
                          helpPanel:
                              ai is StarterAiRepository && ai != null
                              ? StarterHelpPanel(
                                  repository: ai as StarterAiRepository,
                                  chats: ai!,
                                  clinic: auth!.active!.clinicId,
                                )
                              : null,
                          onAi: ai == null
                              ? null
                              : (draft) async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => Scaffold(
                                        appBar: AppBar(
                                          title: const Text('Ayuda con IA'),
                                        ),
                                        body: SingleChildScrollView(
                                          padding: const EdgeInsets.all(16),
                                          child: AiScreen(
                                            repository: ai!,
                                            member: auth!.active!,
                                            initialDraft: draft,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                        )
                      : const Text(
                          'El soporte requiere cuenta y conexión. Puedes consultar Producto y costos o Inicio guiado sin enviar datos.',
                        )
                else if (model.screen == 'Ajustes')
                  ...settings(context)
                else
                  ...pending(context),
              ],
            ),
          ),
        ),
        ),
      ),
    ),
  );

  List<Widget> home(BuildContext context) => [
    if (auth?.active?.role == ClinicRole.revisor)
      ListTile(
        leading: const Icon(VetIcons.clipboardChecks),
        title: const Text('Modo revisión de catálogos'),
        subtitle: const Text(
          'Datos sin verificar; comenta los errores por fila.',
        ),
        onTap: () => model.navigate('Modo revisión'),
      ),
    if (auth?.active?.role != ClinicRole.revisor) ...[
      if (auth?.active != null)
        ClinicIdentity(
          key: ValueKey(
            "identity:${auth!.active!.userId}:${auth!.active!.clinicId}:${auth!.active!.role}",
          ),
          member: auth!.active!,
          repository: forms,
          identity: identity,
        ),
      _ModuleSearch(
        member: auth?.active,
        moduleAccess: moduleAccess,
        experience: experience,
        onNavigate: model.navigate,
      ),
      DashboardScreen(
        key: ValueKey((
          auth?.active?.userId,
          auth?.active?.clinicId,
          auth?.active?.role,
          auth?.offline,
          moduleAccess,
          experience?.revision,
        )),
        model: DashboardViewModel(
          member: auth?.active,
          operations: operations,
          inventory: inventory,
          hospital: hospital,
          patients: patients,
          backup: backup,
          attendance: attendance,
          // Mismos datos que la pantalla de Estadísticas, para que el
          // desplegable «Ver estadísticas» del Inicio muestre lo mismo.
          aviculture: aviculture,
          history: hospital is HospitalHistoryRepository
              ? hospital as HospitalHistoryRepository
              : null,
          moduleAccess: moduleAccess,
        ),
        offline: auth?.offline ?? false,
        // El Inicio Neu es el predeterminado de la linea nueva; el piloto
        // sigue pudiendo apagarse con --dart-define=HOME_PILOT=false.
        homePilot: const bool.fromEnvironment('HOME_PILOT', defaultValue: true),
        alerts: hospitalAlerts,
        isVisible: allowed,
        identity: identity,
        experience: experience,
        onNavigate: model.navigate,
      ),
      FirstStepsBanner(
        key: ValueKey(
          'guide:${auth?.active?.userId}:${auth?.active?.clinicId}',
        ),
        scope: '${auth?.active?.userId}:${auth?.active?.clinicId}',
        onOpen: () => model.navigate('Inicio guiado'),
      ),
    ],
  ];

  /// Hospitalización con sus guardas (repositorios, rol, conexión), usada
  /// tanto por la ruta del armazón como por el atajo de Ajustes: así el
  /// atajo abre el apartado ya desarrollado y al volver se regresa a
  /// Ajustes, en vez de sustituir la pantalla.
  Widget _hospitalSection(BuildContext context) {
    if (hospital == null ||
        patients == null ||
        hospitalAlerts == null ||
        auth?.active == null) {
      return const Text(
        'Conecta tu cuenta y clínica para abrir hospitalización.',
      );
    }
    if (![
      ClinicRole.admin,
      ClinicRole.mvz,
      ClinicRole.auxiliar,
    ].contains(auth!.active!.role)) {
      return const Text(
        'Hospitalización requiere acceso clínico de MVZ, admin o auxiliar.',
      );
    }
    if (auth!.offline) {
      return const Text(
        'Reconecta para consultar o registrar tratamientos. Los avisos locales ya programados pueden continuar; comprueba el estado actual antes de administrar.',
      );
    }
    return HospitalScreen(
      key: ValueKey(
        '${auth!.active!.userId}:${auth!.active!.clinicId}:${auth!.active!.role.name}',
      ),
      initialPatientId: model.activityPatientId,
      initialInstructions: model.activityInstructions,
      repository: hospital!,
      patients: patients!,
      member: auth!.active!,
      alerts: hospitalAlerts!,
      pushService: hospitalPushService,
      clinical: clinical,
      contextIsCurrent: hospitalWeightContext,
      sessionChanges: auth,
      onCalculateWeight: serverAllowed('Cálculo rápido')
          ? (weight, validate) =>
                hospitalWeightCalculation(context, weight, validate)
          : null,
      onRecordMedication:
          prescribing != null && clinical != null && forms != null
          ? (task) async {
              await Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(
                      title: const Text('Registrar medicación'),
                    ),
                    body: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: PrescribingScreen(
                        identity: identity,
                        repository: prescribing!,
                        clinical: clinical!,
                        forms: forms!,
                        member: auth!.active!,
                        initialCase: task.clinicalCaseId,
                        initialTask: task.id,
                      ),
                    ),
                  ),
                ),
              );
            }
          : null,
    );
  }

  /// Recetas con sus guardas, igual que [_hospitalSection]: la ruta del
  /// armazón y el atajo de Ajustes comparten la misma construcción.
  Widget _prescriptionSection() {
    if (prescribing == null ||
        clinical == null ||
        forms == null ||
        auth?.active == null) {
      return const Text('Conecta tu cuenta y clínica para abrir recetas.');
    }
    if (auth!.offline) {
      return const Text(
        'Reconecta para consultar perfiles, recetas y medicamentos.',
      );
    }
    if (![
      ClinicRole.admin,
      ClinicRole.mvz,
      ClinicRole.auxiliar,
    ].contains(auth!.active!.role)) {
      return const Text('Este módulo requiere acceso clínico.');
    }
    return PrescribingScreen(
      identity: identity,
      repository: prescribing!,
      clinical: clinical!,
      forms: forms!,
      member: auth!.active!,
    );
  }

  List<Widget> settings(BuildContext context) => [
    Text('Ajustes', style: Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height: 24),
    Text('Estilo visual', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 12),
    Wrap(
      spacing: 12,
      children: [
        glowChip(
          ChoiceChip(
            label: const Text('Clásico'),
            selected: model.settings.visualStyle == 'standard',
            onSelected: (_) => model.updateSettings(visualStyle: 'standard'),
          ),
        ),
        glowChip(
          ChoiceChip(
            label: const Text('Neu · relieve suave'),
            selected: model.settings.visualStyle == 'neu',
            onSelected: (_) => model.updateSettings(visualStyle: 'neu'),
          ),
        ),
      ],
    ),
    const SizedBox(height: 24),
    Text('Elige tu tema', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 12),
    Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (var index = 0; index < paletteNames.length; index++)
          glowChip(
            ChoiceChip(
              label: Text(paletteNames[index]),
              avatar: CircleAvatar(
                backgroundColor: paletteColors[index],
                radius: 8,
              ),
              selected: model.settings.palette == index,
              onSelected: (_) => model.updateSettings(palette: index),
            ),
          ),
      ],
    ),
    const SizedBox(height: 24),
    DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: model.settings.brightness,
      key: ValueKey(model.settings.brightness),
      decoration: const InputDecoration(
        labelText: 'Apariencia',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 'system', child: Text('Seguir al dispositivo')),
        DropdownMenuItem(value: 'light', child: Text('Claro')),
        DropdownMenuItem(value: 'dark', child: Text('Oscuro')),
      ],
      onChanged: (value) {
        if (value != null) model.updateSettings(brightness: value);
      },
    ),
    if (model.saveError != null)
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          model.saveError!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    const SizedBox(height: 24),
    const Divider(),
    Text('Cuenta y espacio', style: Theme.of(context).textTheme.titleLarge),
    if (auth != null)
      ListTile(
        leading: const Icon(VetIcons.userCircle),
        title: const Text('Mi cuenta y clínicas'),
        subtitle: const Text('Mi espacio personal, clínicas e invitaciones'),
        // Ya con sesion, la pantalla de cuenta (no la de alta, que ofrecia
        // un segundo «Usar mi espacio personal»).
        onTap: () => openAccount(context),
      ),
    if (operations is CommissionRepository &&
        auth?.active != null &&
        auth?.offline != true)
      ListTile(
        leading: const Icon(VetIcons.coins),
        title: const Text('Mis comisiones'),
        subtitle: const Text('Saldo, próximo pago e historial'),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Mis comisiones')),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: CommissionPanel(
                  repository: operations as CommissionRepository,
                  member: auth!.active!,
                ),
              ),
            ),
          ),
        ),
      ),
    if (auth?.active != null)
      ListTile(
        leading: const Icon(VetIcons.sliders),
        title: const Text('Perfil, módulos y flujos de la clínica'),
        subtitle: Text(
          !experienceReady
              ? 'Configuración compartida aún no disponible en el servidor.'
              : auth?.active?.role == ClinicRole.admin
              ? 'Elige secciones, submódulos, procesos y proveedor IA predeterminado.'
              : 'Solo la administración puede modificar estas preferencias.',
        ),
        onTap: experienceRepository == null || !experienceReady
            ? null
            : () async {
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClinicExperienceScreen(
                      member: auth!.active!,
                      initial: experience ?? ClinicExperience.defaults(),
                      repository: experienceRepository!,
                      ready: experienceReady,
                      onSaved: onExperienceSaved,
                    ),
                  ),
                );
              },
      ),
    Text(
      'Configura tus herramientas',
      style: Theme.of(context).textTheme.titleLarge,
    ),
    for (final option in <(String, String, String)>[
      (
        'Perfil profesional, firma y permisos',
        'Revisa tus datos antes de emitir documentos.',
        'Receta',
      ),
      (
        'Membrete y plantillas',
        'Logo, versiones y formatos de tu clínica.',
        'Formatos',
      ),
      (
        'Avisos de hospitalización',
        'Activa y revisa permisos en la hoja de tratamientos.',
        'Hospitalización',
      ),
      (
        'Inventario, ventas y pagos de clientes',
        'Productos, caja y referencias de cobro.',
        'Inventario',
      ),
      (
        'Proveedor de IA y privacidad',
        'Claves, modelos y uso de contexto.',
        'Asistente IA',
      ),
      (
        'Plan y pagos de VetDosis',
        'Suscripción y beneficios de tu espacio.',
        'Planes',
      ),
      (
        'Exportación y respaldo',
        'Consulta límites y genera tus archivos.',
        'Respaldo',
      ),
      (
        'Ayuda y contacto',
        'Reportes, archivos y seguimiento.',
        'Ayuda y soporte',
      ),
      ('Primeros pasos', 'Retoma la guía de configuración.', 'Inicio guiado'),
    ])
      if (allowed(option.$3))
        ListTile(
          leading: Icon(sectionIcon(option.$3)),
          title: Text(option.$1),
          subtitle: Text(option.$2),
          trailing: const Icon(VetIcons.chevronRight),
          onTap: () {
            if (option.$1 == 'Proveedor de IA y privacidad') {
              if (ai == null || auth?.active == null || auth?.offline == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'La configuración de IA requiere cuenta y conexión.',
                    ),
                  ),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Proveedores de IA')),
                    body: SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: AiScreen(
                          repository: ai!,
                          member: auth!.active!,
                          configurationOnly: true,
                          preferredProvider: experience?.defaultAiProvider,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            } else if (option.$3 == 'Receta' ||
                option.$3 == 'Hospitalización') {
              // Estos dos atajos abren su apartado ya desarrollado encima
              // de Ajustes: al volver se regresa a Ajustes, no a Inicio.
              // (Igual que el atajo de IA, que ya usaba Navigator.push.)
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (routeContext) => Scaffold(
                    appBar: AppBar(
                      title: Text(
                        option.$3 == 'Receta'
                            ? 'Recetas'
                            : 'Hospitalización',
                      ),
                    ),
                    body: option.$3 == 'Receta'
                        ? _prescriptionSection()
                        : _hospitalSection(routeContext),
                  ),
                ),
              );
            } else {
              model.navigate(option.$3);
            }
          },
        ),
    if (serverAllowed('Hospitalización')) ...[
      const Divider(),
      Text(
        'Alertas y recordatorios',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      AlertPreferencesPanel(alerts: hospitalAlerts),
    ],
    const AppVersionLabel(),
  ];

  List<Widget> pending(BuildContext context) => [
    Text(model.screen, style: Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height: 24),
    const SoftPanel(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Este módulo está pendiente de implementar.'),
      ),
    ),
    const SizedBox(height: 24),
    Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.icon(
        onPressed: () => model.navigate('Inicio'),
        icon: const Icon(VetIcons.home),
        label: const Text('Volver al inicio'),
      ),
    ),
  ];
}

/// Tarjeta con relieve suave, el envoltorio habitual de los bloques de
/// contenido fuera de las calculadoras.
class SoftPanel extends StatelessWidget {
  const SoftPanel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final surface = dark ? VetColors.darkSurface : VetColors.surface;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [VetColors.darkRaised, VetColors.darkCanvas]
              : const [Color(0xFFFFFFFF), Color(0xFFF1F6FA)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: dark ? VetColors.darkBorder : const Color(0xFFE4EDF3),
        ),
        // El par del sistema. Ver la nota de clinical_vitals_screen: estos
        // eran los valores duros de antes del relieve suave.
        boxShadow: neuShadows(dark, depth: 1.2),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: dark ? 0.035 : 0.025),
            theme.colorScheme.secondary.withValues(alpha: dark ? 0.025 : 0.018),
            surface.withValues(alpha: 0),
          ],
        ),
      ),
      child: child,
    );
  }
}

class _ModuleSearch extends StatefulWidget {
  const _ModuleSearch({
    required this.member,
    required this.moduleAccess,
    required this.experience,
    required this.onNavigate,
  });
  final ClinicMembership? member;
  final ModuleAccess? moduleAccess;
  final ClinicExperience? experience;
  final ValueChanged<String> onNavigate;
  @override
  State<_ModuleSearch> createState() => _ModuleSearchState();
}

class _ModuleSearchState extends State<_ModuleSearch> {
  String query = '';
  static const pages = [
    'Modo revisión',
    'Más',
    'Cálculos',
    'Producción y grandes especies',
    'Exóticos',
    'Servicios',
    'Proveedores',
    'Agenda telefónica',
    'Promociones',
    'Productividad y semana',
    'Agenda',
    'Pacientes',
    'Hospitalización',
    'Inventario',
    'Caja',
    'Planeación financiera',
    'Receta',
    'Formatos',
    'Cálculo rápido',
    'Vademécum',
    'Operaciones de dosis',
    'Cálculos clínicos',
    'Estadísticas',
    'Escanear producto',
    'Equipo y avisos',
    'Anuncios y avisos',
    'Pendientes del equipo',
    'Asistente IA',
    'Ayuda y soporte',
    'Ajustes',
    'Respaldo',
  ];
  String normalize(String value) => value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
  @override
  Widget build(BuildContext context) {
    final results = pages
        .where(
          (p) =>
              navigationAllowed(p, widget.member, widget.moduleAccess) &&
              (widget.experience?.visible(p) ?? true) &&
              normalize(p).contains(normalize(query.trim())),
        )
        .toList();
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(VetIcons.search),
            labelText: 'Buscar apartados y herramientas',
          ),
          onChanged: (value) => setState(() => query = value),
        ),
        if (query.trim().isNotEmpty) ...[
          if (results.isEmpty)
            const ListTile(title: Text('No hay apartados con ese nombre.')),
          for (final page in results)
            ListTile(
              leading: Icon(sectionIcon(page)),
              title: Text(page),
              onTap: () => widget.onNavigate(page),
            ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}
