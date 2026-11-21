import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../../../vet_ui/vet_components.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../auth/domain/clinic_membership.dart';
import '../../auth/domain/staff_labels.dart';
import '../../backup/data/drive_backup_authorization.dart';
import '../../clinic_experience/domain/clinic_experience.dart';
import '../../core/domain/section_catalog.dart';
import '../../core/presentation/core_view_model.dart';
import '../../exports/domain/branded_export.dart';
import '../../exports/presentation/branded_export_action.dart';
import '../../hospital/domain/hospital_models.dart';
import '../../identity/domain/identity_repository.dart';
import '../../inventory/domain/inventory_models.dart';
import '../../../vet_ui/vet_format.dart';
import '../../../vet_ui/vet_icons.dart';
import 'dashboard_view_model.dart';

/// Periodo de la caja: el selector lo aprobó Ale (semana/mes/año).
///
/// Las ventas netas salen de la serie mensual del servidor
/// (`clinic_statistics`): el mes en curso y la suma de los 12 meses. El
/// total de la semana no lo entrega ningún reporte del servidor, así que la
/// opción Semana muestra el desglose de hoy y avisa que falta ese reporte.
enum StatisticsPeriod { week, month, year }

extension on StatisticsPeriod {
  String get label => switch (this) {
    StatisticsPeriod.week => 'Semana',
    StatisticsPeriod.month => 'Mes',
    StatisticsPeriod.year => 'Año',
  };
}

/// Especie (texto libre del expediente) a rama de trabajo.
///
/// Heurística local, solo para filtrar las estadísticas: el servidor no
/// clasifica las especies por rama. Lo que no se reconoce queda sin
/// clasificar y solo aparece con el filtro en «Todas las ramas».
ClinicalBranch? branchForSpecies(String species) {
  switch (normalizeSection(species)) {
    case 'perro':
    case 'gato':
    case 'canino':
    case 'felino':
      return ClinicalBranch.small;
    case 'ave':
    case 'loro':
    case 'perico':
    case 'guacamaya':
    case 'canario':
    case 'reptil':
    case 'serpiente':
    case 'tortuga':
    case 'iguana':
    case 'lagarto':
    case 'conejo':
    case 'huron':
    case 'cobaya':
    case 'cuy':
    case 'hamster':
    case 'erizo':
    case 'chinchilla':
    case 'ardilla':
      return ClinicalBranch.exotic;
    case 'bovino':
    case 'vaca':
    case 'toro':
    case 'becerro':
    case 'ternero':
    case 'ovino':
    case 'borrego':
    case 'caprino':
    case 'cabra':
    case 'chivo':
    case 'porcino':
    case 'cerdo':
    case 'puerco':
    case 'equino':
    case 'caballo':
    case 'yegua':
    case 'potro':
    case 'abeja':
    case 'pez':
    case 'tilapia':
    case 'trucha':
    case 'cachama':
    case 'gallina':
    case 'pollo':
    case 'pato':
    case 'pavo':
    case 'ganso':
      return ClinicalBranch.production;
    default:
      return null;
  }
}

/// Ramas que atiende la clínica, según su preset: el grupo «Producción
/// animal» habilita Producción, «Exóticos y silvestres» habilita Exóticos y
/// «Administración y finanzas» habilita Gestión clínica. Pequeñas especies
/// siempre está. Sin experiencia cargada se ofrecen las cuatro.
List<ClinicalBranch> servedBranches(ClinicExperience? experience) {
  if (experience == null) return ClinicalBranch.values.toList();
  bool groupVisible(String title) {
    final group = sectionGroups.where((g) => g.title == title).firstOrNull;
    if (group == null) return false;
    return group.pages.any(experience.visible);
  }

  return [
    ClinicalBranch.small,
    if (groupVisible('Exóticos y silvestres')) ClinicalBranch.exotic,
    if (groupVisible('Producción animal')) ClinicalBranch.production,
    if (groupVisible('Administración y finanzas')) ClinicalBranch.management,
  ];
}

/// Estadísticas de la clínica, en el orden aprobado por Ale:
///
/// 0. lo que tiene hoy, sin cambios; 1. Caja del periodo; 2. Citas por estado
/// y responsable; 3. Hospitalización; 4. Inventario; 5. Producción M15;
/// 6. Comparativa mes actual vs anterior + compartir/exportar.
///
/// Los datos ya existen en la app (resumen, caja, agenda, hospital,
/// inventario, M15); aquí solo se cablean. Caja e Inventario son datos de
/// toda la clínica y no se dividen por rama con los datos actuales.
class StatisticsPanel extends StatefulWidget {
  const StatisticsPanel({
    super.key,
    required this.model,
    required this.statisticsOnly,
    this.identity,
    this.experience,
  });
  final DashboardViewModel model;
  final bool statisticsOnly;
  final IdentityRepository? identity;
  final ClinicExperience? experience;
  @override
  State<StatisticsPanel> createState() => _StatisticsPanelState();
}

class _StatisticsPanelState extends State<StatisticsPanel> {
  StatisticsPeriod _period = StatisticsPeriod.month;
  ClinicalBranch? _branch;
  bool _exporting = false;
  String? _exportMessage;

  /// Filtro por defecto: una rama a la vez (decisión de Ale, 2026-11-17).
  /// La primera rama que atiende la clínica (Pequeñas especies siempre).
  /// «Todas las ramas» sigue disponible como chip.
  @override
  void initState() {
    super.initState();
    final branches = servedBranches(widget.experience);
    if (branches.isNotEmpty) _branch = branches.first;
  }

  @override
  void didUpdateWidget(covariant StatisticsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.experience != widget.experience &&
        _branch != null &&
        !servedBranches(widget.experience).contains(_branch)) {
      final branches = servedBranches(widget.experience);
      _branch = branches.isNotEmpty ? branches.first : null;
    }
  }

  DashboardViewModel get m => widget.model;
  ClinicMembership? get member => m.member;

  String money(dynamic value) {
    try {
      return Money.parse('$value', signed: true).display;
    } catch (_) {
      return 'No disponible';
    }
  }

  /// Fecha visible en la zona de la clínica, en el formato único de la app
  /// (`22 oct 2026`). Antes iba en barras y se leía distinto que en el resto.
  String shortDate(DateTime value) => VetFormat.date(m.localTime(value));

  String fileDate(DateTime value) {
    final d = m.localTime(value);
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Mes en curso en la zona de la clínica, en el formato 'YYYY-MM' de la
  /// serie del servidor.
  String get currentMonth {
    final d = m.localTime(m.now());
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
  }

  String monthLabel(String yyyyMm) {
    final parts = yyyyMm.split('-');
    if (parts.length != 2) return yyyyMm;
    return '${parts[1]}/${parts[0]}';
  }

  /// Ventas netas del periodo elegido, desde la serie mensual del servidor.
  /// La semana no tiene serie: devuelve null y la sección lo explica.
  Money? get periodNetSales {
    final sales = m.rows(m.statistics, 'sales');
    if (sales.isEmpty) return null;
    try {
      if (_period == StatisticsPeriod.year) {
        var sum = Money(BigInt.zero);
        for (final s in sales) {
          sum += Money.parse('${s['amount']}', signed: true);
        }
        return sum;
      }
      if (_period == StatisticsPeriod.month) {
        final row = sales.where((s) => '${s['month']}' == currentMonth).firstOrNull;
        if (row == null) return null;
        return Money.parse('${row['amount']}', signed: true);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  bool get _branchIsProduction => _branch == ClinicalBranch.production;

  /// Filtra por rama una fila con especie; sin filtro o sin especie
  /// reconocida, la fila pasa solo con «Todas las ramas».
  bool _inBranch(String? species) {
    if (_branch == null) return true;
    if (species == null) return false;
    return branchForSpecies(species) == _branch;
  }

  List<Map<String, dynamic>> get _appointments =>
      m.rows(m.agenda, 'appointments');

  List<Map<String, dynamic>> get _filteredAppointments =>
      _appointments.where((a) => _inBranch('${a['species'] ?? ''}')).toList();

  /// Citas de los últimos 90 días: es la ventana que entrega el resumen de
  /// agenda del servidor (`ops_dashboard`).
  static const _appointmentStates = [
    ('agendado', 'Agendadas'),
    ('en_atencion', 'En atención'),
    ('listo', 'Listas'),
    ('entregado', 'Entregadas'),
    ('cancelado', 'Canceladas'),
  ];

  List<HospitalStay> get _stays =>
      (m.ward?.stays ?? [])
          .where((s) => _inBranch(s.species))
          .toList();

  List<Map<String, dynamic>> get _discharges =>
      (m.discharges?.stays ?? [])
          .where((s) => _inBranch('${s['species'] ?? ''}'))
          .toList();

  /// Lotes próximos a caducar: caducidad dentro de los próximos 30 días.
  /// El umbral es decisión de trabajo; la app no tenía uno definido.
  List<(String, Map<String, dynamic>)> get _nearExpiry {
    final result = <(String, Map<String, dynamic>)>[];
    for (final p in m.products) {
      final lots = p['lots'];
      if (lots is! List) continue;
      for (final raw in lots) {
        if (raw is! Map) continue;
        final lot = Map<String, dynamic>.from(raw);
        final days = lot['days'];
        if (days is int && days > 0 && days <= 30) {
          result.add(('${p['nombre']}', lot));
        }
      }
    }
    result.sort((a, b) {
      final da = a.$2['days'] as int? ?? 0;
      final db = b.$2['days'] as int? ?? 0;
      return da.compareTo(db);
    });
    return result;
  }

  int get _expiredLots {
    var count = 0;
    for (final p in m.products) {
      final lots = p['lots'];
      if (lots is! List) continue;
      for (final raw in lots) {
        if (raw is! Map) continue;
        final lot = Map<String, dynamic>.from(raw);
        final days = lot['days'];
        if (lot['expired'] == true || (days is int && days <= 0)) count++;
      }
    }
    return count;
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );

  Widget _metric(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );

  Widget _listTile(String title, String trailing, [String? subtitle]) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: Text(trailing),
      );

  // -- Exportar / compartir (punto 6) -------------------------------------

  String get _periodLabel => _period.label;
  String get _branchLabel => _branch?.label ?? 'Todas las ramas';
  String get _exportTitle =>
      'Estadísticas · $_periodLabel · $_branchLabel';

  String get _fileName => 'estadisticas-${fileDate(m.now())}';

  List<List<String>> _exportRows() {
    final rows = <List<String>>[
      ['Estadísticas de la clínica', member?.clinicName ?? ''],
      ['Periodo', _periodLabel],
      ['Rama', _branchLabel],
      ['Generado', shortDate(m.now())],
      [],
      ['Caja del periodo'],
      [
        'Ventas netas del periodo',
        periodNetSales?.display ?? 'No disponible',
      ],
    ];
    final totals = m.dayTotals;
    if (totals != null) {
      rows.addAll([
        ['Efectivo (hoy)', money(totals['cash'])],
        ['Tarjeta (hoy)', money(totals['card'])],
        ['Transferencia (hoy)', money(totals['transfer'])],
        ['Ingresos (hoy)', money(totals['income'])],
        ['Retiros (hoy)', money(totals['withdrawal'])],
        ['Gastos (hoy)', money(totals['expense'])],
        ['Resultado del turno (hoy)', money(totals['recorded_net'])],
      ]);
    }
    rows.addAll([
      [],
      ['Citas por estado (últimos 90 días)'],
      for (final state in _appointmentStates)
        [
          state.$2,
          '${_filteredAppointments.where((a) => a['state'] == state.$1).length}',
        ],
    ]);
    final people = m.rows(m.agenda, 'people');
    final byProfessional = <String, int>{};
    for (final a in _filteredAppointments) {
      final id = '${a['professional_id'] ?? ''}';
      byProfessional[id] = (byProfessional[id] ?? 0) + 1;
    }
    for (final entry in byProfessional.entries) {
      rows.add([
        'Responsable: ${staffLabel(entry.key, people)}',
        '${entry.value}',
      ]);
    }
    rows.addAll([
      [],
      ['Hospitalización'],
      ['Internados ahora', '${_stays.length}'],
      [
        'Jaulas ocupadas',
        '${_stays.map((s) => s.cageLabel).toSet().length}',
      ],
      ['Altas registradas', '${_discharges.length}'],
      [],
      ['Inventario'],
      ['Productos con stock bajo', '${m.lowStock.length}'],
      ['Lotes próximos a caducar', '${_nearExpiry.length}'],
      ['Lotes caducados', '$_expiredLots'],
    ]);
    final avi = m.avi;
    if (avi != null && (_branch == null || _branchIsProduction)) {
      final today = avi.records
          .where((r) => DateUtils.isSameDay(r.date, avi.day))
          .fold<int>(0, (sum, r) => sum + r.eggs);
      rows.addAll([
        [],
        ['Producción M15'],
        ['Huevos hoy', '$today'],
        for (final flock in avi.activeFlocks)
          [
            'Parvada ${flock.house}',
            '${flock.lastEggs ?? flock.eggsTotal} huevos',
          ],
      ]);
    }
    final comparison = _comparison();
    if (comparison != null) {
      rows.addAll([
        [],
        ['Comparativa'],
        ['Mes actual (${monthLabel(comparison.$1)})', money(comparison.$3)],
        ['Mes anterior (${monthLabel(comparison.$2)})', money(comparison.$4)],
        ['Diferencia', money(comparison.$5)],
      ]);
    }
    return rows;
  }

  /// (mes actual, mes anterior, importe actual, importe anterior, diferencia).
  (String, String, Money, Money, Money)? _comparison() {
    final sales = m.rows(m.statistics, 'sales');
    if (sales.length < 2) return null;
    try {
      final sorted = [...sales]
        ..sort((a, b) => '${a['month']}'.compareTo('${b['month']}'));
      final current = sorted[sorted.length - 1];
      final previous = sorted[sorted.length - 2];
      final currentAmount = Money.parse(
        '${current['amount']}',
        signed: true,
      );
      final previousAmount = Money.parse(
        '${previous['amount']}',
        signed: true,
      );
      return (
        '${current['month']}',
        '${previous['month']}',
        currentAmount,
        previousAmount,
        currentAmount - previousAmount,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _pdfBytes() async {
    final id = widget.identity;
    if (member == null || id == null) return null;
    final branding = await id.clinic(member!.clinicId);
    final brand = ExportBranding.fromMap(member!.clinicName, branding);
    return brandedPdf(brand, _exportTitle, _exportRows());
  }

  /// Guarda el PDF en Drive con el mismo flujo verificado de Respaldo
  /// (elegir cuenta, confirmar, subir y verificar por descarga + SHA-256,
  /// cerrar sesión). El cliente de respaldos solo admite archivos cifrados
  /// `.vetbackup`, así que el informe en PDF usa su propia subida con
  /// `mimeType` PDF; no cifra el informe.
  Future<void> _saveToDrive() async {
    if (_exporting || member == null) return;
    setState(() {
      _exporting = true;
      _exportMessage = null;
    });
    final client = http.Client();
    try {
      final pdf = await _pdfBytes();
      if (pdf == null || !mounted) return;
      final account = await DriveBackupAuthorization.chooseAccount();
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Guardar copia en Drive'),
          content: Text(
            'Cuenta: ${account.email}\nClínica: ${member!.clinicName}\n\nSe guardará el informe en PDF con membrete.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar en Drive'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final token = await DriveBackupAuthorization.token(account);
      final digest = sha256.convert(pdf).toString();
      final boundary = 'vetdosis-${DateTime.now().microsecondsSinceEpoch}';
      final metadata = jsonEncode({
        'name': '$_fileName.pdf',
        'mimeType': 'application/pdf',
      });
      final body = BytesBuilder()
        ..add(
          utf8.encode(
            '--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$metadata\r\n',
          ),
        )
        ..add(
          utf8.encode(
            '--$boundary\r\nContent-Type: application/pdf\r\n\r\n',
          ),
        )
        ..add(pdf)
        ..add(utf8.encode('\r\n--$boundary--\r\n'));
      final uploaded = await client
          .post(
            Uri.https('www.googleapis.com', '/upload/drive/v3/files', {
              'uploadType': 'multipart',
              'fields': 'id',
            }),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'multipart/related; boundary=$boundary',
            },
            body: body.takeBytes(),
          )
          .timeout(const Duration(minutes: 3));
      if (uploaded.statusCode != 200 && uploaded.statusCode != 201) {
        throw const FormatException('Drive no confirmó la subida.');
      }
      final id =
          (jsonDecode(uploaded.body) as Map<String, dynamic>)['id'];
      if (id is! String || !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
        throw const FormatException('Drive no devolvió un identificador válido.');
      }
      try {
        final request = http.Request(
          'GET',
          Uri.https('www.googleapis.com', '/drive/v3/files/$id', {
            'alt': 'media',
          }),
        )
          ..headers['Authorization'] = 'Bearer $token'
          ..followRedirects = false;
        final response = await client
            .send(request)
            .timeout(const Duration(seconds: 60));
        if (response.statusCode != 200) {
          throw const FormatException('Download failed');
        }
        final downloaded = BytesBuilder();
        await for (final chunk
            in response.stream.timeout(const Duration(seconds: 60))) {
          if (downloaded.length + chunk.length > pdf.length) {
            throw const FormatException('Size mismatch');
          }
          downloaded.add(chunk);
        }
        if (downloaded.length != pdf.length ||
            sha256.convert(downloaded.takeBytes()).toString() != digest) {
          throw const FormatException('Hash mismatch');
        }
      } catch (_) {
        throw const FormatException(
          'La copia se subió, pero NO quedó verificada. Revisa Drive antes de reintentar: podría existir una copia.',
        );
      }
      if (mounted) {
        setState(
          () =>
              _exportMessage =
                  'Copia verificada en Drive de ${account.email}. Archivo: $id.',
        );
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => _exportMessage = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _exportMessage =
              'No se pudo guardar en Drive. Revisa tu cuenta y sus permisos.',
        );
      }
    } finally {
      client.close();
      try {
        await DriveBackupAuthorization.signOut();
      } catch (_) {
        /* No se retienen credenciales en esta pantalla. */
      }
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Comparte el PDF por el selector del sistema; ahí se elige WhatsApp.
  /// No hay envío directo a WhatsApp en la app: el canal de avisos por
  /// WhatsApp requiere activar el envío del servidor.
  Future<void> _shareWhatsApp() async {
    if (_exporting || member == null) return;
    setState(() {
      _exporting = true;
      _exportMessage = null;
    });
    try {
      final pdf = await _pdfBytes();
      if (pdf == null || !mounted) return;
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$_fileName.pdf');
      await file.writeAsBytes(pdf, flush: true);
      final net = periodNetSales;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          title: 'Estadísticas de ${member!.clinicName}',
          text:
              'Estadísticas de ${member!.clinicName} · $_periodLabel · $_branchLabel. '
              'Ventas netas del periodo: ${net?.display ?? 'no disponible'}.',
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _exportMessage =
              'No se pudo preparar el archivo para compartir.',
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _comparisonText((String, String, Money, Money, Money) c) {
    final previous = c.$4.cents;
    if (previous == BigInt.zero) return 'Sin mes anterior para comparar.';
    final pct =
        c.$5.cents.toDouble() / previous.toDouble() * 100;
    final direction = pct > 0
        ? 'Subió'
        : pct < 0
        ? 'Bajó'
        : 'Igual que';
    return '$direction ${pct.abs().toStringAsFixed(1)} % respecto al mes anterior.';
  }

  @override
  Widget build(BuildContext context) {
    if (member == null) {
      return const Text(
        'Conecta tu cuenta y elige una clínica para consultar sus datos.',
      );
    }
    final stats = m.statistics;
    final totals = m.dayTotals;
    final branches = servedBranches(widget.experience);
    final people = m.rows(m.agenda, 'people');
    final byProfessional = <String, int>{};
    for (final a in _filteredAppointments) {
      final id = '${a['professional_id'] ?? ''}';
      byProfessional[id] = (byProfessional[id] ?? 0) + 1;
    }
    final stayIds = _stays.map((s) => s.id).toSet();
    final doneTasks = (m.ward?.tasks ?? [])
        .where(
          (t) =>
              stayIds.contains(t.stayId) &&
              t.state == HospitalTaskState.done,
        )
        .toList();
    final onTimeTasks = doneTasks
        .where(
          (t) =>
              t.performedAt != null && !t.performedAt!.isAfter(t.dueAt),
        )
        .length;
    final comparison = _comparison();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Periodo', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<StatisticsPeriod>(
          segments: const [
            ButtonSegment(
              value: StatisticsPeriod.week,
              label: Text('Semana'),
            ),
            ButtonSegment(
              value: StatisticsPeriod.month,
              label: Text('Mes'),
            ),
            ButtonSegment(
              value: StatisticsPeriod.year,
              label: Text('Año'),
            ),
          ],
          selected: {_period},
          onSelectionChanged: (value) =>
              setState(() => _period = value.single),
        ),
        const SizedBox(height: 16),
        Text('Rama de trabajo', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Todas las ramas'),
              selected: _branch == null,
              onSelected: (_) => setState(() => _branch = null),
            ),
            for (final b in branches)
              ChoiceChip(
                label: Text(b.label),
                selected: _branch == b,
                onSelected: (_) => setState(() => _branch = b),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'El filtro por rama aplica a citas, hospitalización y producción '
          'M15. Caja e inventario son datos de toda la clínica.',
        ),
        // 0. Lo que tiene hoy, sin cambios.
        if (m.errors['Estadísticas'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(m.errors['Estadísticas']!),
          )
        else if (stats == null)
          const VetEmptyState(
            text: 'Resumen no disponible.',
            icon: VetIcons.info,
          )
        else ...[
          const SizedBox(height: 16),
          const Text(
            'Ventas mensuales netas de devoluciones · MXN. No representan utilidad neta.',
          ),
          for (final s in m
              .rows(stats, 'sales')
              .reversed
              .take(widget.statisticsOnly ? 12 : 3))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${s['month']}'),
              trailing: Text(money(s['amount'])),
            ),
          if (widget.statisticsOnly) ...[
            const Text('Citas no canceladas del mes por especie'),
            for (final s in m.rows(stats, 'species'))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${s['species']}'),
                trailing: Text('${s['count']}'),
              ),
          ],
        ],
        // 1. Caja del periodo.
        _sectionTitle('Caja del periodo'),
        if (_period == StatisticsPeriod.week)
          const Text(
            'El servidor entrega las ventas por mes; el total de la semana '
            'aún no está disponible en la app. Abajo va el desglose de hoy.',
          ),
        _metric(
          'Ventas netas del periodo',
          periodNetSales?.display ?? 'No disponible',
        ),
        if (totals == null)
          const Text(
            'El desglose del día solo está disponible para administración.',
          )
        else ...[
          _metric('Efectivo (hoy)', money(totals['cash'])),
          _metric('Tarjeta (hoy)', money(totals['card'])),
          _metric('Transferencia (hoy)', money(totals['transfer'])),
          _metric('Ventas netas del día', money(totals['gross'])),
          _metric(
            'Margen tras costos y comisiones',
            money(totals['margin']),
          ),
          _metric('Ingresos (hoy)', money(totals['income'])),
          _metric('Retiros (hoy)', money(totals['withdrawal'])),
          _metric('Gastos (hoy)', money(totals['expense'])),
          _metric('Resultado del turno (hoy)', money(totals['recorded_net'])),
        ],
        const Text('Últimos cortes'),
        if (m.recentCuts.isEmpty)
          const Text('No hay cortes cerrados en los datos consultados.')
        else
          for (final sh in m.recentCuts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Cierre: ${DateTime.tryParse('${sh['closed_at']}') == null ? '${sh['closed_at']}' : shortDate(DateTime.parse('${sh['closed_at']}'))}',
              ),
              trailing: Text('Contado: ${money(sh['counted_cash'])}'),
            ),
        // 2. Citas por estado y responsable.
        _sectionTitle('Citas por estado y responsable'),
        const Text('Últimos 90 días · citas cargadas en el resumen.'),
        if (m.errors['Agenda'] != null)
          Text(m.errors['Agenda']!)
        else if (m.agenda == null)
          const VetEmptyState(
            text: 'Resumen no disponible.',
            icon: VetIcons.info,
          )
        else ...[
          for (final state in _appointmentStates)
            _metric(
              state.$2,
              '${_filteredAppointments.where((a) => a['state'] == state.$1).length}',
            ),
          if (byProfessional.isNotEmpty) const Text('Por responsable'),
          for (final entry in byProfessional.entries)
            _metric(
              entry.key.isEmpty
                  ? 'Sin asignar'
                  : staffLabel(entry.key, people),
              '${entry.value}',
            ),
        ],
        // 3. Hospitalización.
        _sectionTitle('Hospitalización'),
        if (m.errors['Hospitalización'] != null)
          Text(m.errors['Hospitalización']!)
        else if (m.ward == null)
          const VetEmptyState(
            text: 'Resumen no disponible.',
            icon: VetIcons.info,
          )
        else ...[
          _metric('Internados ahora', '${_stays.length}'),
          _metric(
            'Jaulas ocupadas',
            '${_stays.map((s) => s.cageLabel).toSet().length}',
          ),
          const Text('Estancias'),
          if (_stays.isEmpty)
            const Text('No hay estancias en esta rama.')
          else
            for (final s in _stays.take(5))
              _listTile(
                '${s.patientName} · ${s.species}',
                s.cageLabel,
                'Ingreso: ${shortDate(s.admittedAt)}',
              ),
          _metric('Tareas terminadas', '${doneTasks.length}'),
          _metric('Tareas con horario cumplido', '$onTimeTasks'),
          const Text('Altas'),
          if (m.errors['Altas'] != null)
            Text(m.errors['Altas']!)
          else if (m.discharges == null)
            const Text('Las altas aún no se cargaron en este resumen.')
          else if (_discharges.isEmpty)
            const Text('No hay altas registradas en esta rama.')
          else
            for (final d in _discharges.take(5))
              _listTile(
                '${d['patient_name']} · ${d['species']}',
                'Alta: ${DateTime.tryParse('${d['discharged_at']}') == null ? '${d['discharged_at']}' : shortDate(DateTime.parse('${d['discharged_at']}'))}',
                'Ingreso: ${DateTime.tryParse('${d['admitted_at']}') == null ? '${d['admitted_at']}' : shortDate(DateTime.parse('${d['admitted_at']}'))}',
              ),
        ],
        // 4. Inventario.
        _sectionTitle('Inventario'),
        const Text('Datos de toda la clínica.'),
        if (m.errors['Inventario'] != null)
          Text(m.errors['Inventario']!)
        else if (m.stock == null)
          const VetEmptyState(
            text: 'Resumen no disponible.',
            icon: VetIcons.info,
          )
        else ...[
          const Text('Stock bajo'),
          if (m.lowStock.isEmpty)
            const Text('Sin productos con stock bajo.')
          else
            for (final p in m.lowStock.take(5))
              _listTile(
                '${p['nombre']}',
                'Disponible: ${p['available_stock']}',
                'Mínimo: ${p['stock_minimo']}',
              ),
          const Text('Próximos a caducar (30 días)'),
          if (_nearExpiry.isEmpty)
            const Text('Sin lotes próximos a caducar.')
          else
            for (final e in _nearExpiry.take(5))
              _listTile(e.$1, expiryLabel(e.$2)),
          if (_expiredLots > 0) Text('Lotes caducados: $_expiredLots'),
        ],
        // 5. Producción M15.
        _sectionTitle('Producción M15'),
        if (_branch != null && !_branchIsProduction)
          const Text('La producción M15 pertenece a la rama Producción.')
        else if (m.errors['Producción M15'] != null)
          Text(m.errors['Producción M15']!)
        else if (m.avi == null)
          const Text('Producción M15 no disponible.')
        else ...[
          _metric('Parvadas activas', '${m.avi!.activeFlocks.length}'),
          _metric(
            'Huevos hoy',
            '${m.avi!.records.where((r) => DateUtils.isSameDay(r.date, m.avi!.day)).fold<int>(0, (sum, r) => sum + r.eggs)}',
          ),
          const Text('Huevos por parvada (último registro)'),
          if (m.avi!.activeFlocks.isEmpty)
            const Text('Sin parvadas activas.')
          else
            for (final flock in m.avi!.activeFlocks)
              _listTile(
                'Parvada ${flock.code} · ${flock.house}',
                '${flock.lastEggs ?? flock.eggsTotal} huevos',
                flock.lastRecord == null
                    ? null
                    : 'Último registro: ${shortDate(flock.lastRecord!)}',
              ),
          const Text('Últimos días'),
          ...() {
            final byDay = <DateTime, int>{};
            for (final r in m.avi!.records) {
              final day = DateTime(r.date.year, r.date.month, r.date.day);
              byDay[day] = (byDay[day] ?? 0) + r.eggs;
            }
            final days = byDay.keys.toList()
              ..sort((a, b) => b.compareTo(a));
            return [
              if (days.isEmpty) const Text('Sin registros de producción.'),
              for (final d in days.take(5))
                _metric(shortDate(d), '${byDay[d]} huevos'),
            ];
          }(),
        ],
        // 6. Comparativa mes actual vs anterior + compartir/exportar.
        _sectionTitle('Comparativa y exportar'),
        if (comparison == null)
          const Text('Faltan dos meses de ventas para comparar.')
        else ...[
          _metric(
            'Mes actual (${monthLabel(comparison.$1)})',
            money(comparison.$3),
          ),
          _metric(
            'Mes anterior (${monthLabel(comparison.$2)})',
            money(comparison.$4),
          ),
          _metric('Diferencia', money(comparison.$5)),
          Text(_comparisonText(comparison)),
        ],
        const SizedBox(height: 12),
        if (widget.identity == null)
          const Text(
            'La exportación con membrete requiere la identidad de la clínica.',
          )
        else ...[
          BrandedExportAction(
            repository: widget.identity,
            clinicId: member!.clinicId,
            clinicName: member!.clinicName,
            title: _exportTitle,
            fileName: _fileName,
            rows: () async => _exportRows(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _exporting ? null : _saveToDrive,
                icon: const Icon(VetIcons.cloudUpload),
                label: const Text('Guardar copia en Drive'),
              ),
              OutlinedButton.icon(
                onPressed: _exporting ? null : _shareWhatsApp,
                icon: const Icon(VetIcons.share),
                label: const Text('Compartir por WhatsApp'),
              ),
              if (_exporting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ],
        if (_exportMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_exportMessage!),
          ),
      ],
    );
  }
}
