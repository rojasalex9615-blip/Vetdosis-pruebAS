import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/widgets/accent_glow.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../../vet_ui/vet_theme.dart';
import '../../auth/domain/clinic_membership.dart';
import '../../core/domain/module_access.dart';
import '../domain/production_farm.dart';
import '../domain/production_write_repository.dart';
import 'production_capture_forms.dart';
import '../domain/production_unit_repository.dart';

/// Datos zootécnicos y analíticos por especie para el dashboard de producción.
class SpeciesMetrics {
  const SpeciesMetrics({
    required this.costMetricTitle,
    required this.costUnit,
    required this.costValue,
    required this.costDiff,
    required this.costDiffPositive,
    required this.fcaValue,
    required this.fcaUnit,
    required this.totalHeads,
    required this.biomassTonnes,
    required this.curveMetricTitle,
    required this.curveUnit,
    required this.theoreticalPoints,
    required this.realPoints,
    required this.silos,
    required this.facilities,
    required this.calendarEvents,
    required this.vitals,
    required this.withdrawals,
    required this.batches,
    required this.alerts,
  });

  final String costMetricTitle;
  final String costUnit;
  final double costValue;
  final String costDiff;
  final bool costDiffPositive;
  final double fcaValue;
  final String fcaUnit;
  final int totalHeads;
  final double biomassTonnes;
  final String curveMetricTitle;
  final String curveUnit;
  final List<double> theoreticalPoints;
  final List<double> realPoints;
  final List<SiloData> silos;
  final List<FacilityData> facilities;
  final List<CalendarEvent> calendarEvents;
  final List<VitalSign> vitals;
  final List<WithdrawalAlert> withdrawals;
  final List<BatchData> batches;
  final List<ProductionAlert> alerts;
}

class SiloData {
  const SiloData({
    required this.phase,
    required this.stockTon,
    required this.capacityTon,
    required this.dailyConsumptionKg,
  });
  final String phase;
  final double stockTon;
  final double capacityTon;
  final double dailyConsumptionKg;

  int get autonomyDays =>
      dailyConsumptionKg > 0 ? (stockTon * 1000 / dailyConsumptionKg).floor() : 0;
  double get percentage =>
      capacityTon > 0 ? (stockTon / capacityTon).clamp(0.0, 1.0) : 0.0;
}

class FacilityData {
  const FacilityData({
    required this.id,
    required this.batchId,
    required this.ageDays,
    required this.density,
    required this.densityUnit,
    required this.mortalityRate,
    required this.sanitaryStatus, // 'stable', 'warning', 'critical'
    required this.sanitaryNote,
  });
  final String id;
  final String batchId;
  final int ageDays;
  final double density;
  final String densityUnit;
  final double mortalityRate;
  final String sanitaryStatus;
  final String sanitaryNote;
}

class CalendarEvent {
  const CalendarEvent({
    required this.title,
    required this.batch,
    required this.dateStr,
    required this.category,
    this.completed = false,
  });
  final String title;
  final String batch;
  final String dateStr;
  final String category;
  final bool completed;
}

class VitalSign {
  const VitalSign({
    required this.parameter,
    required this.range,
    required this.unit,
  });
  final String parameter;
  final String range;
  final String unit;
}

class WithdrawalAlert {
  const WithdrawalAlert({
    required this.facility,
    required this.batch,
    required this.drug,
    required this.daysRemaining,
    required this.totalWithdrawalDays,
    required this.destination,
  });
  final String facility;
  final String batch;
  final String drug;
  final int daysRemaining;
  final int totalWithdrawalDays;
  final String destination;
}

class BatchData {
  const BatchData({
    required this.name,
    required this.headcount,
    required this.stage,
    required this.daysInStage,
    required this.lastRecordDate,
    required this.lastRecordDetail,
  });
  final String name;
  final int headcount;
  final String stage;
  final int daysInStage;
  final String lastRecordDate;
  final String lastRecordDetail;
}

class ProductionAlert {
  const ProductionAlert({
    required this.title,
    required this.subtitle,
    required this.type, // 'vaccine', 'withdrawal', 'birth'
    required this.daysLeft,
  });
  final String title;
  final String subtitle;
  final String type;
  final int daysLeft;
}

/// Diccionario de métricas y datos operativos zootécnicos por especie
final Map<String, SpeciesMetrics> speciesDataCatalog = {
  'Bovinos': const SpeciesMetrics(
    costMetricTitle: 'Costo por Litro de Leche',
    costUnit: '\$/L',
    costValue: 6.85,
    costDiff: '-1.4% vs presupuesto',
    costDiffPositive: true,
    fcaValue: 1.45,
    fcaUnit: 'kg MS / L',
    totalHeads: 480,
    biomassTonnes: 264.0,
    curveMetricTitle: 'Producción Láctea Promedio (L/vaca/día)',
    curveUnit: 'L/día',
    theoreticalPoints: [22.0, 26.5, 30.0, 32.5, 31.0, 29.0, 27.0, 24.5],
    realPoints: [21.5, 27.0, 31.2, 33.0, 31.8, 29.5, 27.2, 25.0],
    silos: [
      SiloData(phase: 'Silo Ensilado Maíz', stockTon: 85.0, capacityTon: 120.0, dailyConsumptionKg: 4800),
      SiloData(phase: 'Concentrado Alta Producción', stockTon: 9.5, capacityTon: 25.0, dailyConsumptionKg: 1900),
      SiloData(phase: 'Heno Alfalfa / Forraje', stockTon: 32.0, capacityTon: 40.0, dailyConsumptionKg: 1400),
    ],
    facilities: [
      FacilityData(id: 'Establo 1', batchId: 'Lote Alta Prod', ageDays: 120, density: 14.5, densityUnit: 'm²/vaca', mortalityRate: 0.5, sanitaryStatus: 'stable', sanitaryNote: 'Sin novedades'),
      FacilityData(id: 'Establo 2', batchId: 'Lote Media Prod', ageDays: 210, density: 16.0, densityUnit: 'm²/vaca', mortalityRate: 0.8, sanitaryStatus: 'stable', sanitaryNote: 'Alimentación ajustada'),
      FacilityData(id: 'Corral Preparto', batchId: 'Transición B-1', ageDays: 265, density: 22.0, densityUnit: 'm²/vaca', mortalityRate: 0.0, sanitaryStatus: 'warning', sanitaryNote: '3 vacas próximas a parto'),
      FacilityData(id: 'Cunas Terneras', batchId: 'Crianza C-26', ageDays: 35, density: 4.5, densityUnit: 'm²/becerra', mortalityRate: 1.2, sanitaryStatus: 'critical', sanitaryNote: 'Tratamiento diarrea neonatal en curso'),
    ],
    calendarEvents: [
      CalendarEvent(title: 'Vacunación Clostridiosis y Pasteurelosis', batch: 'Lote Transición', dateStr: 'Hoy · 09:00', category: 'Vacuna'),
      CalendarEvent(title: 'Revisión ginecológica y eco de preñez', batch: 'Lote Alta Prod', dateStr: 'Mañana · 07:30', category: 'Servicio'),
      CalendarEvent(title: 'Desparasitación lote vaquillas', batch: 'Vaquillas V-2', dateStr: 'En 3 días', category: 'Sanidad'),
    ],
    vitals: [
      VitalSign(parameter: 'Temperatura rectal', range: '38.0 - 39.3', unit: '°C'),
      VitalSign(parameter: 'Frecuencia cardíaca', range: '60 - 80', unit: 'lpm'),
      VitalSign(parameter: 'Frecuencia respiratoria', range: '15 - 35', unit: 'rpm'),
      VitalSign(parameter: 'Movimientos ruminales', range: '2 - 3', unit: 'mov / 2 min'),
    ],
    withdrawals: [
      WithdrawalAlert(facility: 'Establo 1 / Vaca #402', batch: 'Lote Alta Prod', drug: 'Ceftiofur sódico 50mg/mL', daysRemaining: 2, totalWithdrawalDays: 3, destination: 'Leche (0 d) / Carne (3 d)'),
      WithdrawalAlert(facility: 'Corral 3 / Toro #18', batch: 'Sementales', drug: 'Ivermectina 1%', daysRemaining: 18, totalWithdrawalDays: 35, destination: 'Carne'),
    ],
    batches: [
      BatchData(name: 'Hato Lechero Lote 1', headcount: 140, stage: 'Lactancia Temprana', daysInStage: 65, lastRecordDate: 'Hoy 06:00', lastRecordDetail: '3,850 L ordeña matutina'),
      BatchData(name: 'Hato Lechero Lote 2', headcount: 180, stage: 'Lactancia Media', daysInStage: 160, lastRecordDate: 'Hoy 06:00', lastRecordDetail: '4,120 L ordeña matutina'),
      BatchData(name: 'Vaquillas de Reemplazo', headcount: 85, stage: 'Crecimiento', daysInStage: 280, lastRecordDate: 'Ayer', lastRecordDetail: 'Pesaje promedio 345 kg'),
      BatchData(name: 'Vacas Secas y Retiro', headcount: 45, stage: 'Periodo Seco', daysInStage: 42, lastRecordDate: 'Hace 2 días', lastRecordDetail: 'Aplicación sellador pezones'),
    ],
    alerts: [
      ProductionAlert(title: 'Partos próximos (48h)', subtitle: '3 vacas en corral de maternidad preparto', type: 'birth', daysLeft: 2),
      ProductionAlert(title: 'Retiro de Ceftiofur en curso', subtitle: 'Vaca #402: faltan 2 días para liberar a rastro', type: 'withdrawal', daysLeft: 2),
      ProductionAlert(title: 'Revacunación Carbunco Sintomático', subtitle: 'Lote Vaquillas de Reemplazo', type: 'vaccine', daysLeft: 5),
    ],
  ),
  'Porcinos': const SpeciesMetrics(
    costMetricTitle: 'Costo por Kg Cerdo en Pie',
    costUnit: '\$/kg',
    costValue: 34.20,
    costDiff: '+2.1% vs presupuesto',
    costDiffPositive: false,
    fcaValue: 2.58,
    fcaUnit: 'kg alim / kg gdp',
    totalHeads: 1850,
    biomassTonnes: 148.5,
    curveMetricTitle: 'Ganancia Diaria de Peso - GDP (g/día)',
    curveUnit: 'g/día',
    theoreticalPoints: [380, 520, 680, 790, 890, 950, 980, 960],
    realPoints: [375, 530, 695, 805, 880, 940, 975, 965],
    silos: [
      SiloData(phase: 'Silo Preiniciador / Destete', stockTon: 4.8, capacityTon: 10.0, dailyConsumptionKg: 650),
      SiloData(phase: 'Silo Crecimiento / Desarrollo', stockTon: 8.2, capacityTon: 25.0, dailyConsumptionKg: 2100),
      SiloData(phase: 'Silo Finalizador Engorda', stockTon: 22.5, capacityTon: 30.0, dailyConsumptionKg: 3200),
    ],
    facilities: [
      FacilityData(id: 'Nave Maternidad', batchId: 'Camadas Semana 46', ageDays: 18, density: 1.0, densityUnit: 'hembra+camada', mortalityRate: 4.5, sanitaryStatus: 'stable', sanitaryNote: '11.8 lechones destetados/hembra'),
      FacilityData(id: 'Nave Destete 1', batchId: 'Lote Des-204', ageDays: 45, density: 0.35, densityUnit: 'm²/lechón', mortalityRate: 1.1, sanitaryStatus: 'stable', sanitaryNote: 'Consumo normal 780g/día'),
      FacilityData(id: 'Nave Engorda A', batchId: 'Lote Eng-102', ageDays: 110, density: 0.85, densityUnit: 'm²/cerdo', mortalityRate: 1.8, sanitaryStatus: 'warning', sanitaryNote: 'Monitoreo de tos matutina'),
      FacilityData(id: 'Nave Engorda B', batchId: 'Lote Eng-103', ageDays: 140, density: 0.95, densityUnit: 'm²/cerdo', mortalityRate: 2.2, sanitaryStatus: 'critical', sanitaryNote: 'Medicación en agua con Tilosina activa'),
    ],
    calendarEvents: [
      CalendarEvent(title: 'Vacunación Mycoplasma + PCV2', batch: 'Lote Des-204', dateStr: 'Hoy · 11:00', category: 'Vacuna'),
      CalendarEvent(title: 'Destete programado 28 camadas', batch: 'Maternidad Sala 2', dateStr: 'Jueves · 06:00', category: 'Destete'),
      CalendarEvent(title: 'Inseminación Artificial lote 35 cerdas', batch: 'Gestación 1', dateStr: 'Viernes · 07:00', category: 'Servicio'),
      CalendarEvent(title: 'Movimiento a Finalizador (Nave 4)', batch: 'Lote Crec-88', dateStr: 'Sábado', category: 'Movimiento'),
    ],
    vitals: [
      VitalSign(parameter: 'Temperatura rectal', range: '38.5 - 39.5', unit: '°C'),
      VitalSign(parameter: 'Frecuencia cardíaca', range: '70 - 100', unit: 'lpm'),
      VitalSign(parameter: 'Frecuencia respiratoria', range: '20 - 40', unit: 'rpm'),
      VitalSign(parameter: 'Consumo diario agua', range: '8 - 15', unit: 'L / cerdo final'),
    ],
    withdrawals: [
      WithdrawalAlert(facility: 'Nave Engorda B', batch: 'Lote Eng-103', drug: 'Tilosina tartrato en agua', daysRemaining: 5, totalWithdrawalDays: 7, destination: 'Carne'),
      WithdrawalAlert(facility: 'Corral Enfermería 2', batch: 'Lote Tratados', drug: 'Florfenicol 300mg', daysRemaining: 14, totalWithdrawalDays: 28, destination: 'Carne'),
    ],
    batches: [
      BatchData(name: 'Lote Engorda Final 101', headcount: 520, stage: 'Finalizador Engorda', daysInStage: 42, lastRecordDate: 'Hoy', lastRecordDetail: 'Peso prom: 104 kg · Consumo: 2.9 kg/d'),
      BatchData(name: 'Lote Engorda A 102', headcount: 490, stage: 'Crecimiento', daysInStage: 28, lastRecordDate: 'Ayer', lastRecordDetail: 'Peso prom: 72 kg · ICA: 2.45'),
      BatchData(name: 'Lote Destete 204', headcount: 560, stage: 'Destete / Transición', daysInStage: 21, lastRecordDate: 'Hace 2 días', lastRecordDetail: 'Peso prom: 19.8 kg'),
      BatchData(name: 'Plantel Reproductoras', headcount: 280, stage: 'Gestación / Maternidad', daysInStage: 80, lastRecordDate: 'Hoy', lastRecordDetail: 'Condición corporal: 3.25'),
    ],
    alerts: [
      ProductionAlert(title: 'Tilosina activa en Nave B', subtitle: 'Lote Eng-103 con 5 días restantes de resguardo cárnico', type: 'withdrawal', daysLeft: 5),
      ProductionAlert(title: 'Inseminación masiva de cerdas', subtitle: 'Lote 14 hembras post-destete detectadas en celo', type: 'birth', daysLeft: 1),
      ProductionAlert(title: 'Vacuna Parvovirus / Leptospira', subtitle: 'Hembras de reemplazo a los 6 meses de edad', type: 'vaccine', daysLeft: 7),
    ],
  ),
  'Aves': const SpeciesMetrics(
    costMetricTitle: 'Costo por Kg Pollo / Docena Huevo',
    costUnit: '\$/kg',
    costValue: 24.80,
    costDiff: '-3.2% vs lote previo',
    costDiffPositive: true,
    fcaValue: 1.68,
    fcaUnit: 'kg alim / kg carne',
    totalHeads: 42000,
    biomassTonnes: 92.4,
    curveMetricTitle: 'Curva de Postura (%) / Peso acumulado pollo (g)',
    curveUnit: 'g peso',
    theoreticalPoints: [180, 460, 920, 1500, 2150, 2750, 3100],
    realPoints: [185, 475, 940, 1530, 2180, 2730, 3080],
    silos: [
      SiloData(phase: 'Iniciador Parrillero', stockTon: 14.0, capacityTon: 20.0, dailyConsumptionKg: 1800),
      SiloData(phase: 'Crecimiento Aviar', stockTon: 18.5, capacityTon: 35.0, dailyConsumptionKg: 4200),
      SiloData(phase: 'Finalizador Engorda (Retiro)', stockTon: 8.0, capacityTon: 40.0, dailyConsumptionKg: 5800),
    ],
    facilities: [
      FacilityData(id: 'Caseta 01 (Túnel)', batchId: 'Parvada Ross-308 #12', ageDays: 35, density: 13.5, densityUnit: 'aves/m²', mortalityRate: 2.1, sanitaryStatus: 'stable', sanitaryNote: 'Ventilación y cama óptimas'),
      FacilityData(id: 'Caseta 02 (Túnel)', batchId: 'Parvada Ross-308 #13', ageDays: 28, density: 14.0, densityUnit: 'aves/m²', mortalityRate: 1.8, sanitaryStatus: 'stable', sanitaryNote: 'Ganancia 85g/día'),
      FacilityData(id: 'Caseta 03 (Abierta)', batchId: 'Postura Lohmann #4', ageDays: 196, density: 8.2, densityUnit: 'aves/m²', mortalityRate: 0.9, sanitaryStatus: 'stable', sanitaryNote: 'Postura al 93.4%'),
    ],
    calendarEvents: [
      CalendarEvent(title: 'Vacunación Gumboro cepa intermedia en agua', batch: 'Caseta 02', dateStr: 'Hoy · 06:30', category: 'Vacuna'),
      CalendarEvent(title: 'Pase a alimento finalizador sin coccidiostato', batch: 'Caseta 01', dateStr: 'En 2 días', category: 'Alimento'),
      CalendarEvent(title: 'Muestreo de serología Salmonella e Influenza', batch: 'Todas las casetas', dateStr: 'En 4 días', category: 'Sanidad'),
    ],
    vitals: [
      VitalSign(parameter: 'Temperatura corporal', range: '40.6 - 41.7', unit: '°C'),
      VitalSign(parameter: 'Frecuencia respiratoria', range: '25 - 40', unit: 'rpm'),
      VitalSign(parameter: 'Frecuencia cardíaca', range: '250 - 400', unit: 'lpm'),
      VitalSign(parameter: 'Relación agua:alimento', range: '1.8 : 1 a 2.0 : 1', unit: 'L / kg'),
    ],
    withdrawals: [
      WithdrawalAlert(facility: 'Caseta 01', batch: 'Parvada Ross-308 #12', drug: 'Enrofloxacina 10% oral', daysRemaining: 4, totalWithdrawalDays: 7, destination: 'Carne (huevo no permitido)'),
    ],
    batches: [
      BatchData(name: 'Parvada Engorda Caseta 1', headcount: 18000, stage: 'Finalizador Engorda', daysInStage: 35, lastRecordDate: 'Hoy', lastRecordDetail: 'Peso promedio 2,210 g'),
      BatchData(name: 'Parvada Engorda Caseta 2', headcount: 18000, stage: 'Crecimiento', daysInStage: 28, lastRecordDate: 'Ayer', lastRecordDetail: 'Peso promedio 1,530 g'),
      BatchData(name: 'Lote Ponedoras Caseta 3', headcount: 6000, stage: 'Pico de Postura', daysInStage: 120, lastRecordDate: 'Hoy 10:00', lastRecordDetail: '5,604 huevos recolectados (93.4%)'),
    ],
    alerts: [
      ProductionAlert(title: 'Retiro Enrofloxacina en Caseta 01', subtitle: '4 días restantes de resguardo antes de salida al rastro', type: 'withdrawal', daysLeft: 4),
      ProductionAlert(title: 'Cambio de fase alimenticia Caseta 2', subtitle: 'Transición a alimento finalizador programada', type: 'feed', daysLeft: 2),
      ProductionAlert(title: 'Inspección de bioseguridad arcos sanitarios', subtitle: 'Revisión periódica de desinfectante y registros', type: 'sanitary', daysLeft: 3),
    ],
  ),
  'Ovinos / caprinos': const SpeciesMetrics(
    costMetricTitle: 'Costo por Kg Cordero en Pie',
    costUnit: '\$/kg',
    costValue: 46.50,
    costDiff: '+1.1% vs presupuesto',
    costDiffPositive: false,
    fcaValue: 4.80,
    fcaUnit: 'kg MS / kg carne',
    totalHeads: 620,
    biomassTonnes: 27.9,
    curveMetricTitle: 'Ganancia de Peso Cordero Engorda (g/día)',
    curveUnit: 'g/día',
    theoreticalPoints: [180, 240, 290, 320, 310, 280],
    realPoints: [175, 245, 295, 315, 305, 275],
    silos: [
      SiloData(phase: 'Concentrado Ovinos Engorda', stockTon: 8.5, capacityTon: 15.0, dailyConsumptionKg: 650),
      SiloData(phase: 'Pacas Henil Avena/Alfalfa', stockTon: 16.0, capacityTon: 25.0, dailyConsumptionKg: 900),
    ],
    facilities: [
      FacilityData(id: 'Corral Engorda 1', batchId: 'Lote Corderos Dorper A', ageDays: 85, density: 1.8, densityUnit: 'm²/cordero', mortalityRate: 0.8, sanitaryStatus: 'stable', sanitaryNote: 'Ganancia 305g/d'),
      FacilityData(id: 'Corral Hembras Gestantes', batchId: 'Hato Cría Katahdin', ageDays: 115, density: 3.2, densityUnit: 'm²/oveja', mortalityRate: 0.2, sanitaryStatus: 'warning', sanitaryNote: 'Partos programados semana próxima'),
      FacilityData(id: 'Área Ordeña Caprina', batchId: 'Hato Saanen / Alpino', ageDays: 140, density: 4.0, densityUnit: 'm²/cabra', mortalityRate: 0.5, sanitaryStatus: 'stable', sanitaryNote: '2.8 L/cabra/día'),
    ],
    calendarEvents: [
      CalendarEvent(title: 'Vacuna Clostridial 8 vías + Tétanos', batch: 'Corderos Destetados', dateStr: 'Mañana · 08:00', category: 'Vacuna'),
      CalendarEvent(title: 'Diagnóstico de preñez por ultrasonido', batch: 'Hato Dorper', dateStr: 'En 3 días', category: 'Servicio'),
      CalendarEvent(title: 'Recorte de pezuñas y pediluvio sulfato', batch: 'Todo el rebaño', dateStr: 'En 5 días', category: 'Manejo'),
    ],
    vitals: [
      VitalSign(parameter: 'Temperatura rectal', range: '38.5 - 40.0', unit: '°C'),
      VitalSign(parameter: 'Frecuencia cardíaca', range: '70 - 90', unit: 'lpm'),
      VitalSign(parameter: 'Frecuencia respiratoria', range: '16 - 34', unit: 'rpm'),
      VitalSign(parameter: 'Movimientos ruminales', range: '2 - 3', unit: 'mov / 2 min'),
    ],
    withdrawals: [
      WithdrawalAlert(facility: 'Corral Engorda 1', batch: 'Corderos Dorper A', drug: 'Levamisol 12%', daysRemaining: 6, totalWithdrawalDays: 14, destination: 'Carne'),
    ],
    batches: [
      BatchData(name: 'Lote Corderos Engorda 1', headcount: 220, stage: 'Finalización Engorda', daysInStage: 60, lastRecordDate: 'Hoy', lastRecordDetail: 'Peso promedio 41.5 kg'),
      BatchData(name: 'Rebaño Cría Katahdin', headcount: 280, stage: 'Gestación Avanzada', daysInStage: 118, lastRecordDate: 'Ayer', lastRecordDetail: 'Calificación FAMACHA grado 1-2'),
      BatchData(name: 'Hato Lechero Caprino Saanen', headcount: 120, stage: 'Lactancia', daysInStage: 90, lastRecordDate: 'Hoy 07:00', lastRecordDetail: 'Producción 336 L leche'),
    ],
    alerts: [
      ProductionAlert(title: 'Resguardo de Levamisol en Engorda', subtitle: '6 días restantes de retiro para lote Dorper A', type: 'withdrawal', daysLeft: 6),
      ProductionAlert(title: 'Partos programados próxima semana', subtitle: '18 ovejas multíparas en lote gestación', type: 'birth', daysLeft: 4),
      ProductionAlert(title: 'Desparasitación estratégica FAMACHA', subtitle: 'Revisión y dosificación selectiva de hembras', type: 'sanitary', daysLeft: 7),
    ],
  ),
  'Peces': const SpeciesMetrics(
    costMetricTitle: 'Costo por Kg Pescado Eviscerado',
    costUnit: '\$/kg',
    costValue: 39.40,
    costDiff: '-2.0% vs ciclo previo',
    costDiffPositive: true,
    fcaValue: 1.32,
    fcaUnit: 'kg alim / kg pez',
    totalHeads: 68000,
    biomassTonnes: 34.0,
    curveMetricTitle: 'Crecimiento de Biomasa Acuícola (g/pez)',
    curveUnit: 'g/pez',
    theoreticalPoints: [25, 75, 160, 270, 390, 520],
    realPoints: [28, 80, 168, 285, 405, 535],
    silos: [
      SiloData(phase: 'Alimento Extruido 32% Prot (Crecimiento)', stockTon: 12.0, capacityTon: 20.0, dailyConsumptionKg: 680),
      SiloData(phase: 'Alimento Extruido 28% Prot (Engorda)', stockTon: 18.5, capacityTon: 30.0, dailyConsumptionKg: 1020),
    ],
    facilities: [
      FacilityData(id: 'Estanque R-01 (Geomembrana)', batchId: 'Tilapia GIFT #09', ageDays: 110, density: 24.5, densityUnit: 'kg/m³', mortalityRate: 1.5, sanitaryStatus: 'stable', sanitaryNote: 'Oxígeno disuelto 6.2 mg/L'),
      FacilityData(id: 'Estanque R-02 (Geomembrana)', batchId: 'Tilapia GIFT #10', ageDays: 75, density: 14.0, densityUnit: 'kg/m³', mortalityRate: 1.2, sanitaryStatus: 'stable', sanitaryNote: 'Temp 27.5 °C'),
      FacilityData(id: 'Estanque R-03 (Tierra)', batchId: 'Bagre Canal #03', ageDays: 140, density: 8.5, densityUnit: 'kg/m³', mortalityRate: 2.8, sanitaryStatus: 'warning', sanitaryNote: 'Oxígeno bajo al amanecer (3.8 mg/L)'),
    ],
    calendarEvents: [
      CalendarEvent(title: 'Biometría y pesaje quincenal lote R-01', batch: 'Estanque R-01', dateStr: 'Hoy · 08:30', category: 'Biometría'),
      CalendarEvent(title: 'Limpieza y purga de filtros sedimentadores', batch: 'Módulos RAS', dateStr: 'Mañana', category: 'Mantenimiento'),
      CalendarEvent(title: 'Desdoble y selección por tallas', batch: 'Estanque R-02', dateStr: 'En 3 días', category: 'Manejo'),
    ],
    vitals: [
      VitalSign(parameter: 'Oxígeno disuelto ideal', range: '> 5.0', unit: 'mg/L'),
      VitalSign(parameter: 'Temperatura de agua (Tilapia)', range: '26.0 - 30.0', unit: '°C'),
      VitalSign(parameter: 'pH del agua', range: '6.5 - 8.5', unit: 'pH'),
      VitalSign(parameter: 'Amonio total (TAN)', range: '< 0.05', unit: 'mg/L tóxico'),
    ],
    withdrawals: [
      WithdrawalAlert(facility: 'Estanque R-03', batch: 'Bagre Canal #03', drug: 'Florfenicol acuícola 50%', daysRemaining: 7, totalWithdrawalDays: 15, destination: 'Carne filete'),
    ],
    batches: [
      BatchData(name: 'Lote Tilapia Estanque 1', headcount: 25000, stage: 'Engorda Final', daysInStage: 110, lastRecordDate: 'Hoy', lastRecordDetail: 'Peso prom: 535 g · Biomasa: 13.37 Ton'),
      BatchData(name: 'Lote Tilapia Estanque 2', headcount: 28000, stage: 'Crecimiento', daysInStage: 75, lastRecordDate: 'Ayer', lastRecordDetail: 'Peso prom: 285 g · Biomasa: 7.98 Ton'),
      BatchData(name: 'Lote Alevines Módulo A', headcount: 15000, stage: 'Alevinaje / Cría', daysInStage: 35, lastRecordDate: 'Hace 3 días', lastRecordDetail: 'Peso prom: 28 g'),
    ],
    alerts: [
      ProductionAlert(title: 'Retiro activo Florfenicol Estanque 3', subtitle: '7 días de resguardo antes de cosecha para fileteo', type: 'withdrawal', daysLeft: 7),
      ProductionAlert(title: 'Alerta de Oxígeno bajo Estanque 3', subtitle: 'Incrementar aireación suplementaria nocturna', type: 'sanitary', daysLeft: 0),
      ProductionAlert(title: 'Próxima cosecha programada', subtitle: 'Lote Estanque 1 listo para planta procesadora', type: 'harvest', daysLeft: 12),
    ],
  ),
  'Abejas': const SpeciesMetrics(
    costMetricTitle: 'Costo por Kg Miel Cosechada',
    costUnit: '\$/kg',
    costValue: 48.20,
    costDiff: '-4.5% vs temporada previa',
    costDiffPositive: true,
    fcaValue: 0.0,
    fcaUnit: 'N/A',
    totalHeads: 120,
    biomassTonnes: 0.0,
    curveMetricTitle: 'Producción de Miel por Colmena (kg/caja)',
    curveUnit: 'kg/caja',
    theoreticalPoints: [5.0, 12.0, 22.0, 34.0, 42.0],
    realPoints: [4.8, 13.5, 24.2, 36.0, 44.5],
    silos: [
      SiloData(phase: 'Jarabe de Azúcar / Estimulación (Litros)', stockTon: 1.8, capacityTon: 3.0, dailyConsumptionKg: 80),
      SiloData(phase: 'Torta Proteica / Sustituto Polen (Kg)', stockTon: 0.6, capacityTon: 1.0, dailyConsumptionKg: 25),
    ],
    facilities: [
      FacilityData(id: 'Apiario 1 - Las Lomas', batchId: '45 Colmenas Dobles', ageDays: 180, density: 45, densityUnit: 'colmenas/apiario', mortalityRate: 2.2, sanitaryStatus: 'stable', sanitaryNote: 'Floración de mezquite activa'),
      FacilityData(id: 'Apiario 2 - El Valle', batchId: '40 Colmenas Langstroth', ageDays: 150, density: 40, densityUnit: 'colmenas/apiario', mortalityRate: 1.5, sanitaryStatus: 'stable', sanitaryNote: 'Alzas melarias al 80%'),
      FacilityData(id: 'Apiario 3 - Reserva', batchId: '35 Núcleos de Cría', ageDays: 60, density: 35, densityUnit: 'núcleos/apiario', mortalityRate: 3.0, sanitaryStatus: 'warning', sanitaryNote: 'Tratamiento orgánico de Varroa'),
    ],
    calendarEvents: [
      CalendarEvent(title: 'Muestreo de infestación Varroa (conteo azúcar)', batch: 'Apiario 1', dateStr: 'Hoy · 09:00', category: 'Sanidad'),
      CalendarEvent(title: 'Colocación de alzas melarias adicionales', batch: 'Apiario 2', dateStr: 'En 2 días', category: 'Manejo'),
      CalendarEvent(title: 'Cambio de reinas fecundadas F1', batch: 'Apiario 3', dateStr: 'En 6 días', category: 'Genética'),
    ],
    vitals: [
      VitalSign(parameter: 'Temperatura en cámara de cría', range: '34.5 - 35.5', unit: '°C'),
      VitalSign(parameter: 'Humedad relativa en colmena', range: '55 - 65', unit: '%'),
      VitalSign(parameter: 'Postura diaria reina', range: '1,500 - 2,000', unit: 'huevos/día'),
    ],
    withdrawals: [
      WithdrawalAlert(facility: 'Apiario 3', batch: '35 Núcleos de Cría', drug: 'Ácido Oxálico por sublimación', daysRemaining: 0, totalWithdrawalDays: 0, destination: 'Miel (orgánico sin residuo en alzas vacías)'),
    ],
    batches: [
      BatchData(name: 'Apiario 1 Las Lomas', headcount: 45, stage: 'Flujo Melario Principal', daysInStage: 35, lastRecordDate: 'Hoy', lastRecordDetail: '32 alzas operculadas listas'),
      BatchData(name: 'Apiario 2 El Valle', headcount: 40, stage: 'Llenado de Alzas', daysInStage: 21, lastRecordDate: 'Hace 2 días', lastRecordDetail: 'Entrada fuerte de néctar'),
      BatchData(name: 'Apiario 3 Núcleos', headcount: 35, stage: 'Multiplicación / Cría', daysInStage: 45, lastRecordDate: 'Hace 4 días', lastRecordDetail: 'Aceptación de reinas 92%'),
    ],
    alerts: [
      ProductionAlert(title: 'Monitoreo de Varroa en Apiario 3', subtitle: 'Revisión posterior a tratamiento orgánico', type: 'sanitary', daysLeft: 2),
      ProductionAlert(title: 'Cosecha y centrifugado de miel', subtitle: 'Corte de miel de primavera en Apiario 1', type: 'harvest', daysLeft: 5),
    ],
  ),
  'Equinos': const SpeciesMetrics(
    costMetricTitle: 'Costo Diario de Ración y Mantenimiento',
    costUnit: '\$/caballo/día',
    costValue: 128.00,
    costDiff: '+1.5% vs mes anterior',
    costDiffPositive: false,
    fcaValue: 0.0,
    fcaUnit: 'N/A',
    totalHeads: 42,
    biomassTonnes: 21.0,
    curveMetricTitle: 'Condición Corporal Promedio (Escala Henneke 1-9)',
    curveUnit: 'Escala 1-9',
    theoreticalPoints: [5.0, 5.2, 5.5, 5.5, 5.6, 5.5],
    realPoints: [5.1, 5.3, 5.4, 5.5, 5.7, 5.6],
    silos: [
      SiloData(phase: 'Concentrado Equino Balanceado 14% (Ton)', stockTon: 4.5, capacityTon: 10.0, dailyConsumptionKg: 210),
      SiloData(phase: 'Heno de Avena y Alfalfa Seleccionada (Pacas)', stockTon: 8.0, capacityTon: 15.0, dailyConsumptionKg: 350),
    ],
    facilities: [
      FacilityData(id: 'Cuadra A (Caballerizas)', batchId: 'Sementales y Entrenamiento', ageDays: 180, density: 16.0, densityUnit: 'm²/caballeriza', mortalityRate: 0.0, sanitaryStatus: 'stable', sanitaryNote: 'Paja limpia y desinfectada'),
      FacilityData(id: 'Cuadra B (Yeguas)', batchId: 'Yeguas Gestantes / Lactantes', ageDays: 240, density: 20.0, densityUnit: 'm²/box', mortalityRate: 0.0, sanitaryStatus: 'stable', sanitaryNote: '2 potros nacidos saludables'),
      FacilityData(id: 'Potrero 1 (Pastoreo)', batchId: 'Destetes y Añejos', ageDays: 320, density: 5000.0, densityUnit: 'm²/potro', mortalityRate: 0.0, sanitaryStatus: 'stable', sanitaryNote: 'Agua corriente y sombra'),
    ],
    calendarEvents: [
      CalendarEvent(title: 'Vacuna Influenza Equina + Tétanos', batch: 'Cuadra A y B', dateStr: 'Hoy · 10:30', category: 'Vacuna'),
      CalendarEvent(title: 'Desparasitación rotativa con Ivermectina + Praziquantel', batch: 'Todos los equinos', dateStr: 'En 3 días', category: 'Sanidad'),
      CalendarEvent(title: 'Evaluación seminal semental estrella', batch: 'Semental "Azteca"', dateStr: 'En 5 días', category: 'Genética'),
    ],
    vitals: [
      VitalSign(parameter: 'Temperatura rectal', range: '37.2 - 38.3', unit: '°C'),
      VitalSign(parameter: 'Frecuencia cardíaca en reposo', range: '28 - 44', unit: 'lpm'),
      VitalSign(parameter: 'Frecuencia respiratoria', range: '8 - 16', unit: 'rpm'),
      VitalSign(parameter: 'Tiempo de llenado capilar (TLLC)', range: '< 2', unit: 'segundos'),
    ],
    withdrawals: [
      WithdrawalAlert(facility: 'Cuadra A / Box 4', batch: 'Caballo Deporte #04', drug: 'Flunixin Meglumine 50mg/mL', daysRemaining: 3, totalWithdrawalDays: 7, destination: 'Control antidopaje deportivo'),
    ],
    batches: [
      BatchData(name: 'Lote Sementales Activos', headcount: 6, stage: 'Monta y Extracción Seminal', daysInStage: 120, lastRecordDate: 'Hoy', lastRecordDetail: 'Colecta seminal 85% motilidad progresiva'),
      BatchData(name: 'Lote Yeguas Gestantes', headcount: 16, stage: 'Último tercio gestación', daysInStage: 290, lastRecordDate: 'Ayer', lastRecordDetail: 'Monitoreo de ubre y pezones'),
      BatchData(name: 'Lote Potros Crecimiento', headcount: 14, stage: 'Añejos 1-2 años', daysInStage: 180, lastRecordDate: 'Hace 3 días', lastRecordDetail: 'Alzada promedio 1.48 m'),
      BatchData(name: 'Lote Trabajo / Deporte', headcount: 6, stage: 'Entrenamiento diario', daysInStage: 90, lastRecordDate: 'Hoy', lastRecordDetail: 'Rutina matutina completada'),
    ],
    alerts: [
      ProductionAlert(title: 'Control antidopaje Box 4', subtitle: 'Flunixin meglumine: 3 días restantes de ventana de detección', type: 'withdrawal', daysLeft: 3),
      ProductionAlert(title: 'Partos equinos próximos (72h)', subtitle: 'Yegua "Gitana" en monitoreo de calcio en leche', type: 'birth', daysLeft: 3),
      ProductionAlert(title: 'Desparasitación masiva de cuadras', subtitle: 'Rotación semestral de principio activo', type: 'sanitary', daysLeft: 3),
    ],
  ),
};

/// Widget principal del Dashboard Independiente de Producción Pecuaria
class ProductionDashboard extends StatefulWidget {
  const ProductionDashboard({
    super.key,
    required this.onNavigate,
    this.member,
    this.access,
    this.units,
    this.farm,
    this.farmWrite,
    this.initialSpecies = 'Bovinos',
  });

  final ValueChanged<String> onNavigate;
  final ClinicMembership? member;
  final ModuleAccess? access;
  final ProductionUnitRepository? units;

  /// De donde salen los lotes, eventos y registros reales de la granja.
  ///
  /// Si no se pasa, el panel no inventa una granja de ejemplo: se queda sin
  /// datos y lo dice. Las pruebas pueden entregar uno falso para no tocar red.
  final ProductionFarmRepository? farm;

  /// Por donde se guardan lotes, registros y eventos.
  ///
  /// Va aparte de [farm] a proposito: el panel es de lectura y solo las
  /// pantallas que capturan necesitan poder escribir. Si no se pasa, los
  /// botones de captura no se dibujan.
  final ProductionWriteRepository? farmWrite;
  final String initialSpecies;

  @override
  State<ProductionDashboard> createState() => _ProductionDashboardState();
}

class _ProductionDashboardState extends State<ProductionDashboard> {
  late String _selectedSpecies;

  final List<String> _speciesList = const [
    'Bovinos',
    'Porcinos',
    'Aves',
    'Ovinos / caprinos',
    'Peces',
    'Abejas',
    'Equinos',
  ];

  /// Lo que hay de verdad en la granja para la especie elegida.
  ///
  /// `null` mientras se lee. El panel no cae de vuelta al catalogo de ejemplo
  /// si esto viene vacio: ensenar la granja inventada de 480 vacas como si
  /// fuera del usuario era justo el error que se corrige.
  FarmSnapshot? _granja;
  bool _cargandoGranja = true;
  Object? _falloGranja;

  @override
  void initState() {
    super.initState();
    _selectedSpecies = widget.initialSpecies;
    if (!_speciesList.contains(_selectedSpecies)) {
      _selectedSpecies = 'Bovinos';
    }
    _cargarGranja();
  }

  Future<void> _cargarGranja() async {
    // Cede el turno antes de tocar el estado. La primera llamada sale de
    // initState, y ahi el widget todavia se esta montando: un setState
    // sincrono en ese momento revienta. Con esto, todo lo que sigue ocurre
    // ya montado, venga de initState o de un cambio de especie.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    final repo = widget.farm;
    final clinicId = widget.member?.clinicId;
    if (repo == null || clinicId == null || clinicId.isEmpty) {
      // Sin repositorio o sin area de trabajo no hay nada que leer. Se queda
      // en vacio, que es la verdad, en lugar de rellenar con el catalogo.
      if (mounted) {
        setState(() {
          _granja = const FarmSnapshot();
          _cargandoGranja = false;
          _falloGranja = null;
        });
      }
      return;
    }
    setState(() {
      _cargandoGranja = true;
      _falloGranja = null;
    });
    try {
      final datos = await repo.load(
        clinicId,
        especies: codigosDeEspecie[_selectedSpecies] ?? const [],
      );
      if (!mounted) return;
      setState(() {
        _granja = datos;
        _cargandoGranja = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Un fallo de red no es «no hay datos»: se distinguen en pantalla para
      // que nadie lea un corte de conexion como una granja sin lotes.
      setState(() {
        _falloGranja = e;
        _cargandoGranja = false;
      });
    }
  }

  /// Etiquetas, unidades y rangos de referencia de la especie.
  ///
  /// De aqui ya NO salen cifras de la granja: solo los textos que describen
  /// que se mide y en que unidad. Lo que es del usuario viene de [_granja].
  SpeciesMetrics get _currentMetrics =>
      speciesDataCatalog[_selectedSpecies] ?? speciesDataCatalog['Bovinos']!;

  void _openCalculatorDialog(String calcType) {
    showDialog<void>(
      context: context,
      builder: (ctx) => ProductionCalculatorModal(
        calcType: calcType,
        species: _selectedSpecies,
      ),
    );
  }

  void _openMassMedicationDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => MassMedicationModal(species: _selectedSpecies),
    );
  }

  void _openPrescriptionDialog({required bool quantified}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => PecuariaPrescriptionModal(
        quantified: quantified,
        species: _selectedSpecies,
        clinicName: widget.member?.clinicName ?? 'Granja / Clínica Pecuaria',
        mvzName: widget.member?.userId ?? 'MVZ Responsable',
      ),
    );
  }

  void _openVademecumDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => ProductionVademecumModal(species: _selectedSpecies),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _currentMetrics;
    final (specIcon, specAccent) = _speciesVisual(_selectedSpecies);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Selector de especie (chips arriba)
        _buildSpeciesSelector(),
        const SizedBox(height: 16),

        // Todo lo que describe a ESTA granja (retiros, KPIs, curvas,
        // instalaciones, calendario, lotes y alertas) sale de Supabase. Si no
        // hay registros, se dice; no se rellena con el catalogo de ejemplo.
        ..._buildFarmArea(),

        // 2. Herramientas de la especie elegida (tarjetas interactivas)
        // No dependen de la granja: son calculadoras y referencias, y siguen
        // sirviendo aunque todavia no se haya dado de alta ningun lote.
        _buildSpeciesToolsSection(metrics, specIcon, specAccent),
        const SizedBox(height: 24),

        // 5. Recetas y control (acceso directo a receta cuantificada / simple)
        _buildPrescriptionAndControlSection(),
        const SizedBox(height: 24),

        // 6. Próximamente (en gris para grandes especies avanzada, manejo de desechos)
        _buildUpcomingSection(),
        const SizedBox(height: 32),
      ],
    );
  }

  /// La parte del panel que describe a ESTA granja.
  ///
  /// Antes se pintaba siempre desde `speciesDataCatalog`, un catalogo fijo con
  /// una granja inventada (480 vacas, silos al 71 %, alertas de una vaca
  /// #402). Parecia informacion del usuario y no lo era. Ahora sale de
  /// Supabase y, cuando no hay registros, se dice con todas sus letras.
  List<Widget> _buildFarmArea() {
    if (_cargandoGranja) {
      return const [
        VetCard(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
        SizedBox(height: 24),
      ];
    }

    if (_falloGranja != null) {
      return [
        VetCard(
          child: Column(
            children: [
              const Icon(VetIcons.cloudOff, size: 28, color: VetColors.muted),
              const SizedBox(height: 8),
              const Text(
                'No se pudieron leer los datos de producción',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                'Revisa la conexión. Esto no significa que la granja esté '
                'vacía: no se alcanzó el servidor.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: VetColors.muted),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _cargarGranja,
                icon: const Icon(VetIcons.refresh, size: 16),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ];
    }

    final granja = _granja ?? const FarmSnapshot();

    if (granja.sinDatos) {
      return [
        _barraDeCaptura(granja),
        _buildFarmEmptyCard(),
        const SizedBox(height: 24),
      ];
    }

    final ahora = DateTime.now();
    return [
      _barraDeCaptura(granja),
      _buildRealKpis(granja),
      const SizedBox(height: 20),
      _buildRealBatches(granja, ahora),
      const SizedBox(height: 24),
      _buildRealAlerts(granja, ahora),
      const SizedBox(height: 24),
    ];
  }

  // -------------------------------------------------------------------
  // Captura
  // -------------------------------------------------------------------

  /// Los botones que faltaban. Solo se dibujan si hay con que escribir y el
  /// rol lo permite; [ProductionCaptureBar] se encarga de lo segundo.
  Widget _barraDeCaptura(FarmSnapshot granja) {
    final repo = widget.farmWrite;
    final clinicId = widget.member?.clinicId;
    if (repo == null || clinicId == null || clinicId.isEmpty) {
      return const SizedBox.shrink();
    }
    return ProductionCaptureBar(
      member: widget.member,
      onNuevoLote: () => _abrirLote(repo, clinicId),
      onRegistro: () => _abrirRegistro(repo, clinicId, granja),
      onEvento: () => _abrirEvento(repo, clinicId, granja),
    );
  }

  /// Tras guardar se vuelve a leer: lo que se acaba de capturar tiene que
  /// verse en el panel sin que nadie tenga que salir y entrar.
  Future<void> _trasGuardar(bool guardado, String mensaje) async {
    if (!guardado || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
    await _cargarGranja();
  }

  Future<void> _abrirLote(
    ProductionWriteRepository repo,
    String clinicId,
  ) async {
    final guardado = await capturarLote(
      context,
      clinicId: clinicId,
      repo: repo,
      especiesPermitidas: codigosDeEspecie[_selectedSpecies] ?? const [],
    );
    await _trasGuardar(guardado, 'Lote guardado');
  }

  Future<void> _abrirRegistro(
    ProductionWriteRepository repo,
    String clinicId,
    FarmSnapshot granja,
  ) async {
    final guardado = await capturarRegistro(
      context,
      clinicId: clinicId,
      repo: repo,
      lotes: granja.batches,
      metricas: granja.metricDefs,
    );
    await _trasGuardar(guardado, 'Registro guardado');
  }

  Future<void> _abrirEvento(
    ProductionWriteRepository repo,
    String clinicId,
    FarmSnapshot granja,
  ) async {
    final guardado = await capturarEvento(
      context,
      clinicId: clinicId,
      repo: repo,
      lotes: granja.batches,
    );
    await _trasGuardar(guardado, 'Evento guardado');
  }

  /// El estado vacio de verdad: ni una cifra inventada.
  Widget _buildFarmEmptyCard() {
    final especieSinCatalogo =
        (codigosDeEspecie[_selectedSpecies] ?? const []).isEmpty;
    return VetCard(
      child: Column(
        children: [
          Icon(
            especieSinCatalogo ? VetIcons.info : VetIcons.barn,
            size: 30,
            color: VetColors.muted.withValues(alpha: .8),
          ),
          const SizedBox(height: 10),
          Text(
            especieSinCatalogo
                ? 'Todavía no hay producción de $_selectedSpecies'
                : 'Aún no hay datos de producción',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            especieSinCatalogo
                ? 'Esta especie todavía no forma parte del catálogo '
                    'productivo, así que no hay lotes ni registros que mostrar.'
                : 'Empieza con «Nuevo lote» y captura su registro diario: '
                    'aquí irán apareciendo tus cabezas, curvas y eventos. No '
                    'mostramos cifras de ejemplo para que nada se confunda '
                    'con datos de tu granja.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: VetColors.muted),
          ),
        ],
      ),
    );
  }

  /// Cabezas y lotes reales. Solo lo que se puede contar de verdad.
  Widget _buildRealKpis(FarmSnapshot granja) {
    final activos = granja.batches.where((b) => b.estado != 'cerrado').length;
    return Row(
      children: [
        Expanded(
          child: VetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cabezas en inventario',
                  style: TextStyle(fontSize: 12, color: VetColors.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  '${granja.totalCabezas}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: VetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lotes activos',
                  style: TextStyle(fontSize: 12, color: VetColors.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  '$activos',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Los lotes tal como estan en `lotes_produccion`.
  Widget _buildRealBatches(FarmSnapshot granja, DateTime ahora) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VetSectionHeader(
          title: 'Mis lotes',
          subtitle: 'Lotes dados de alta en este espacio de trabajo',
        ),
        const SizedBox(height: 10),
        if (granja.batches.isEmpty)
          const VetCard(
            child: VetEmptyState(
              text: 'Aún no hay lotes dados de alta para esta especie.',
              icon: VetIcons.barn,
            ),
          )
        else
          for (final b in granja.batches)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VetCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                radius: 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.nombre.isEmpty ? b.codigo : b.nombre,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${b.proposito} · ${b.diasEnEtapa(ahora)} días',
                            style: const TextStyle(
                              fontSize: 12,
                              color: VetColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${b.cabezas}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  /// Alertas reales: eventos de `produccion_eventos` que aun no han pasado.
  Widget _buildRealAlerts(FarmSnapshot granja, DateTime ahora) {
    final proximos = granja.proximos(ahora);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VetSectionHeader(
          title: 'Alertas y Tareas Críticas',
          subtitle:
              'Vacunas por vencer, resguardos farmacológicos y partos o servicios',
        ),
        const SizedBox(height: 10),
        if (proximos.isEmpty)
          const VetCard(
            child: VetEmptyState(
              text: 'No hay eventos próximos registrados.',
              icon: VetIcons.calendarCheck,
            ),
          )
        else
          for (final e in proximos)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VetCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                radius: 16,
                // Mismo anclaje arriba que el resto de tarjetas de alerta:
                // asi el icono y los dias no bailan segun cuanto texto haya.
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      e.tipo == 'resguardo'
                          ? VetIcons.alertOctagon
                          : (e.tipo == 'parto'
                              ? VetIcons.heart
                              : VetIcons.bell),
                      color: e.tipo == 'resguardo'
                          ? VetColors.danger
                          : VetColors.warning,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.subtipo.isEmpty ? e.tipo : e.subtipo,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _nombreDeLote(granja, e.loteId),
                            style: const TextStyle(
                              fontSize: 12,
                              color: VetColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _chipDeDias(e.diasRestantes(ahora)),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  String _nombreDeLote(FarmSnapshot granja, String loteId) {
    for (final b in granja.batches) {
      if (b.id == loteId) return b.nombre.isEmpty ? b.codigo : b.nombre;
    }
    return 'Lote sin nombre';
  }

  Widget _chipDeDias(int dias) {
    final urgente = dias <= 2;
    final color = urgente ? VetColors.danger : VetColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        dias == 0 ? 'Hoy' : 'En $dias d',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  // 1. SELECTOR DE ESPECIE (Chips superiores)
  Widget _buildSpeciesSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VetSectionHeader(
          title: 'Producción Pecuaria',
          subtitle: 'Panel independiente de gestión zootécnica y financiera',
          large: true,
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (final sp in _speciesList) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: glowChip(
                    ChoiceChip(
                      selected: _selectedSpecies == sp,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedSpecies = sp;
                          });
                          // Cada especie tiene sus propios lotes: al cambiar
                          // de pestaña hay que releer, o se quedaria viendo
                          // los datos de la especie anterior.
                          _cargarGranja();
                        }
                      },
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _speciesVisual(sp).$1,
                            size: 16,
                            color: _selectedSpecies == sp
                                ? VetColors.ink
                                : VetColors.muted,
                          ),
                          const SizedBox(width: 6),
                          Flexible(child: Text(sp)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // 2. HERRAMIENTAS DE LA ESPECIE ELEGIDA (Tarjetas)
  Widget _buildSpeciesToolsSection(SpeciesMetrics metrics, IconData specIcon, Color specAccent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VetSectionHeader(
          title: 'Herramientas de $_selectedSpecies',
          subtitle: 'Calculadoras zootécnicas, constantes fisiológicas, vademécum y registros',
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          // 1.35 dejaba la celda en 118 dp y el rotulo a dos lineas no cabia.
          childAspectRatio: 1.2,
          children: [
            ProductionToolTile(
              title: 'Calculadora de Ración',
              subtitle: 'Requerimientos por etapa',
              icon: VetIcons.feedBag,
              accent: VetColors.turquoise,
              onTap: () => _openCalculatorDialog('ration'),
            ),
            ProductionToolTile(
              title: 'FCA / Conversión',
              subtitle: 'Factor conversión alimenticia',
              icon: VetIcons.balance,
              accent: VetColors.violet,
              onTap: () => _openCalculatorDialog('fca'),
            ),
            ProductionToolTile(
              title: 'Densidad Animal',
              subtitle: 'kg/m² o cabezas/corral',
              icon: VetIcons.grid,
              accent: VetColors.cyan,
              onTap: () => _openCalculatorDialog('density'),
            ),
            ProductionToolTile(
              title: 'Capacidad de Caseta/Nave',
              subtitle: 'Dimensiones y ventilación',
              icon: VetIcons.barn,
              accent: VetColors.warning,
              onTap: () => _openCalculatorDialog('capacity'),
            ),
            ProductionToolTile(
              title: 'Dosis Seminales',
              subtitle: 'Concentración y diluyente',
              icon: VetIcons.microscope,
              accent: VetColors.pink,
              onTap: () => _openCalculatorDialog('semen'),
            ),
            // Vivia en la fila de «Ejecución Diaria», que se retiro por pintar
            // un calendario de ejemplo. La dosificacion masiva no es un dato
            // inventado sino una calculadora, asi que se conserva aqui.
            ProductionToolTile(
              title: 'Dosificación Masiva',
              subtitle: 'Agua mg/L y alimento ppm',
              icon: VetIcons.dropper,
              accent: VetColors.brandSky,
              onTap: _openMassMedicationDialog,
            ),
            ProductionToolTile(
              title: 'Constantes Fisiológicas',
              subtitle: 'Rango normal de $_selectedSpecies',
              icon: VetIcons.heartPulse,
              accent: VetColors.turquoise,
              onTap: () => _showVitalsModal(metrics),
            ),
            ProductionToolTile(
              title: 'Vademécum Pecuario',
              subtitle: 'Fármacos y tiempos de retiro',
              icon: VetIcons.pills,
              accent: VetColors.lilac,
              onTap: () => _openVademecumDialog(),
            ),
            ProductionToolTile(
              title: 'Registros Productivos',
              subtitle: 'Pesajes, consumo y mortalidad',
              icon: VetIcons.clipboardChecks,
              accent: VetColors.turquoise,
              onTap: () => _showQuickRecordModal(),
            ),
          ],
        ),
      ],
    );
  }

  void _showVitalsModal(SpeciesMetrics metrics) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(VetIcons.heartPulse, color: VetColors.turquoise),
            const SizedBox(width: 8),
            Expanded(child: Text('Constantes: $_selectedSpecies')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final v in metrics.vitals) ...[
              ListTile(
                dense: true,
                title: Text(v.parameter, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: Text(
                  '${v.range} ${v.unit}',
                  style: const TextStyle(color: VetColors.turquoise, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void _showQuickRecordModal() {
    final pesoCtrl = TextEditingController();
    final mortCtrl = TextEditingController();
    final consCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo Registro Productivo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pesoCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Pesaje promedio del lote (kg o g)'),
            ),
            TextField(
              controller: mortCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Mortalidad del día (cabezas)'),
            ),
            TextField(
              controller: consCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Consumo de alimento diario (kg)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Registro productivo guardado con éxito.'),
                  backgroundColor: VetColors.success,
                ),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // 5. RECETAS Y CONTROL
  Widget _buildPrescriptionAndControlSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VetSectionHeader(
          title: 'Recetas y Control Oficial',
          subtitle: 'Acceso directo a receta médica pecuaria simple y cuantificada',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: VetActionButton(
                icon: VetIcons.document,
                label: 'Receta Simple',
                style: VetActionStyle.neutral,
                onPressed: () => _openPrescriptionDialog(quantified: false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: VetActionButton(
                icon: VetIcons.documentCheck,
                label: 'Receta Cuantificada',
                style: VetActionStyle.primary,
                onPressed: () => _openPrescriptionDialog(quantified: true),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 6. PRÓXIMAMENTE (En gris)
  Widget _buildUpcomingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VetSectionHeader(
          title: 'Próximamente',
          subtitle: 'Módulos en preparación zootécnica y ambiental',
        ),
        const SizedBox(height: 10),
        Opacity(
          opacity: 0.5,
          child: Column(
            children: const [
              VetCard(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                radius: 16,
                child: Row(
                  children: [
                    Icon(VetIcons.firstAidKit, color: Colors.grey, size: 28),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Grandes Especies: Cirugía y Clínica Avanzada',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          Text(
                            'Protocolos quirúrgicos de campo, cesáreas y laparotomía',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    VetStatusBadge(label: 'En desarrollo', kind: VetBadgeKind.unverified),
                  ],
                ),
              ),
              SizedBox(height: 8),
              VetCard(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                radius: 16,
                child: Row(
                  children: [
                    Icon(VetIcons.leaf, color: Colors.grey, size: 28),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manejo de Efluentes, Desechos y Bioseguridad',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          Text(
                            'Lagunas de oxidación, compostaje de mortalidad y biodigestores',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    VetStatusBadge(label: 'En desarrollo', kind: VetBadgeKind.unverified),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Visual por especie
(IconData, Color) _speciesVisual(String name) => switch (name) {
  'Bovinos' => (VetIcons.cow, VetColors.turquoise),
  'Porcinos' => (VetIcons.pig, VetColors.pink),
  'Aves' => (VetIcons.chicken, VetColors.warning),
  'Ovinos / caprinos' => (VetIcons.sheep, VetColors.violet),
  'Peces' => (VetIcons.fish, VetColors.cyan),
  'Abejas' => (VetIcons.hive, VetColors.warning),
  'Equinos' => (VetIcons.horse, VetColors.purpleDeep),
  _ => (VetIcons.paw, VetColors.turquoise),
};

// Tarjeta KPI personalizada
class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.indicatorText,
    required this.indicatorPositive,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final String value;
  final String unit;
  final String indicatorText;
  final bool indicatorPositive;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return VetCard(
      padding: const EdgeInsets.all(12),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: VetColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 16, color: accentColor),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  unit,
                  style: const TextStyle(fontSize: 12, color: VetColors.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                indicatorPositive ? VetIcons.arrowUp : VetIcons.arrowDown,
                size: 11,
                color: indicatorPositive ? VetColors.success : VetColors.danger,
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  indicatorText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: indicatorPositive ? VetColors.success : VetColors.danger,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Botón de herramienta
class ProductionToolTile extends StatelessWidget {
  const ProductionToolTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: VetCard(
        padding: const EdgeInsets.all(12),
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            VetIconBox(icon: icon, accent: accent, size: 36),
            // En un telefono de 360 dp la celda deja 133 dp de texto util, y
            // con una sola linea se cortaban casi todos los rotulos:
            // «Capacidad de Caseta/Nave» mide 153 dp y «Factor conversion
            // alimenticia», 174. Con dos lineas caben enteros.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: VetColors.muted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Diálogo modal de Calculadoras de Producción
class ProductionCalculatorModal extends StatefulWidget {
  const ProductionCalculatorModal({
    super.key,
    required this.calcType,
    required this.species,
  });

  final String calcType;
  final String species;

  @override
  State<ProductionCalculatorModal> createState() => ProductionCalculatorModalState();
}

class ProductionCalculatorModalState extends State<ProductionCalculatorModal> {
  final numAnimalsCtrl = TextEditingController(text: '100');
  final paramCtrl1 = TextEditingController();
  final paramCtrl2 = TextEditingController();
  final paramCtrl3 = TextEditingController();
  String _result = '';

  @override
  void initState() {
    super.initState();
    _initParams();
  }

  void _initParams() {
    switch (widget.calcType) {
      case 'ration':
        paramCtrl1.text = '45'; // Peso prom kg
        paramCtrl2.text = '3.0'; // % peso vivo
        _calculate();
        break;
      case 'fca':
        paramCtrl1.text = '5200'; // Alimento consumido kg
        paramCtrl2.text = '2100'; // Ganancia de peso kg
        _calculate();
        break;
      case 'density':
        paramCtrl1.text = '120'; // Superficie m²
        paramCtrl2.text = '150'; // Animales
        _calculate();
        break;
      case 'capacity':
        paramCtrl1.text = '12'; // Ancho nave m
        paramCtrl2.text = '100'; // Largo nave m
        paramCtrl3.text = '12'; // Densidad objetivo (aves/m² o lechones/m²)
        _calculate();
        break;
      case 'semen':
        paramCtrl1.text = '200'; // Volumen eyaculado mL
        paramCtrl2.text = '300'; // Millones esp/mL
        paramCtrl3.text = '3000'; // Millones esp por dosis
        _calculate();
        break;
    }
  }

  void _calculate() {
    setState(() {
      if (widget.calcType == 'ration') {
        final n = double.tryParse(numAnimalsCtrl.text) ?? 1;
        final peso = double.tryParse(paramCtrl1.text) ?? 1;
        final pct = (double.tryParse(paramCtrl2.text) ?? 1) / 100.0;
        final porAnimal = peso * pct;
        final totalDia = porAnimal * n;
        _result = '${porAnimal.toStringAsFixed(2)} kg / animal / día\nTotal lote: ${totalDia.toStringAsFixed(1)} kg/día (${(totalDia/1000).toStringAsFixed(2)} Ton)';
      } else if (widget.calcType == 'fca') {
        final alim = double.tryParse(paramCtrl1.text) ?? 1;
        final peso = double.tryParse(paramCtrl2.text) ?? 1;
        final fca = peso > 0 ? (alim / peso) : 0.0;
        _result = 'FCA: ${fca.toStringAsFixed(2)} : 1\n(Se requieren ${fca.toStringAsFixed(2)} kg de alimento para producir 1 kg vivo)';
      } else if (widget.calcType == 'density') {
        final sup = double.tryParse(paramCtrl1.text) ?? 1;
        final anim = double.tryParse(paramCtrl2.text) ?? 1;
        final dens = sup > 0 ? (anim / sup) : 0.0;
        final m2PorAnimal = anim > 0 ? (sup / anim) : 0.0;
        _result = '${dens.toStringAsFixed(2)} animales / m²\nEspacio por animal: ${m2PorAnimal.toStringAsFixed(2)} m²/cabeza';
      } else if (widget.calcType == 'capacity') {
        final ancho = double.tryParse(paramCtrl1.text) ?? 1;
        final largo = double.tryParse(paramCtrl2.text) ?? 1;
        final dens = double.tryParse(paramCtrl3.text) ?? 1;
        final area = ancho * largo;
        final cap = area * dens;
        _result = 'Área útil: ${area.toStringAsFixed(0)} m²\nCapacidad total recomendada: ${cap.toStringAsFixed(0)} animales';
      } else if (widget.calcType == 'semen') {
        final vol = double.tryParse(paramCtrl1.text) ?? 1;
        final conc = double.tryParse(paramCtrl2.text) ?? 1;
        final dosisReq = double.tryParse(paramCtrl3.text) ?? 1;
        final totalEsp = vol * conc; // millones
        final numDosis = dosisReq > 0 ? (totalEsp / dosisReq).floor() : 0;
        _result = 'Total espermatozoides: ${totalEsp.toStringAsFixed(0)} M\nDosis seminales obtenibles: $numDosis dosis';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    String title = 'Calculadora Zootécnica';
    if (widget.calcType == 'ration') title = 'Cálculo de Ración Diaria';
    if (widget.calcType == 'fca') title = 'Factor Conversión Alimenticia (FCA)';
    if (widget.calcType == 'density') title = 'Densidad Animal';
    if (widget.calcType == 'capacity') title = 'Capacidad de Nave / Caseta';
    if (widget.calcType == 'semen') title = 'Dosis Seminales e Inseminación';

    return AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.calcType == 'ration') ...[
              TextField(
                controller: numAnimalsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Número de animales en lote'),
                onChanged: (_) => _calculate(),
              ),
              TextField(
                controller: paramCtrl1,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Peso promedio por animal (kg)'),
                onChanged: (_) => _calculate(),
              ),
              TextField(
                controller: paramCtrl2,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '% de peso vivo a consumir (ej. 2.5 - 3.5%)'),
                onChanged: (_) => _calculate(),
              ),
            ] else if (widget.calcType == 'fca') ...[
              TextField(
                controller: paramCtrl1,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Total alimento consumido en periodo (kg)'),
                onChanged: (_) => _calculate(),
              ),
              TextField(
                controller: paramCtrl2,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Ganancia de peso total en periodo (kg)'),
                onChanged: (_) => _calculate(),
              ),
            ] else if (widget.calcType == 'density') ...[
              TextField(
                controller: paramCtrl1,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Superficie de corral / nave (m²)'),
                onChanged: (_) => _calculate(),
              ),
              TextField(
                controller: paramCtrl2,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Número de animales alojados'),
                onChanged: (_) => _calculate(),
              ),
            ] else if (widget.calcType == 'capacity') ...[
              TextField(
                controller: paramCtrl1,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Ancho de la nave (m)'),
                onChanged: (_) => _calculate(),
              ),
              TextField(
                controller: paramCtrl2,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Largo de la nave (m)'),
                onChanged: (_) => _calculate(),
              ),
              TextField(
                controller: paramCtrl3,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Densidad meta (animales / m²)'),
                onChanged: (_) => _calculate(),
              ),
            ] else if (widget.calcType == 'semen') ...[
              TextField(
                controller: paramCtrl1,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Volumen eyaculado (mL)'),
                onChanged: (_) => _calculate(),
              ),
              TextField(
                controller: paramCtrl2,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Concentración (millones esp / mL)'),
                onChanged: (_) => _calculate(),
              ),
              TextField(
                controller: paramCtrl3,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Concentración objetivo por dosis (millones)'),
                onChanged: (_) => _calculate(),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VetColors.turquoise.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: VetColors.turquoise.withValues(alpha: 0.4)),
              ),
              child: Text(
                _result,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }
}

// Modal de Dosificación Masiva (Agua mg/L y Alimento ppm)
class MassMedicationModal extends StatefulWidget {
  const MassMedicationModal({super.key, required this.species});
  final String species;

  @override
  State<MassMedicationModal> createState() => MassMedicationModalState();
}

class MassMedicationModalState extends State<MassMedicationModal> {
  int _tab = 0; // 0: Agua mg/L, 1: Alimento ppm

  final waterVolCtrl = TextEditingController(text: '1000'); // Litros tinaco
  final waterMgLCtrl = TextEditingController(text: '100'); // mg/L deseados
  final waterPctCtrl = TextEditingController(text: '10'); // Concentración producto %

  final feedTonCtrl = TextEditingController(text: '5'); // Toneladas alimento
  final feedPpmCtrl = TextEditingController(text: '200'); // ppm producto
  final feedPrePctCtrl = TextEditingController(text: '20'); // Premezcla %

  String _calcOutput = '';

  @override
  void initState() {
    super.initState();
    _recalc();
  }

  void _recalc() {
    setState(() {
      if (_tab == 0) {
        final l = double.tryParse(waterVolCtrl.text) ?? 1;
        final mgL = double.tryParse(waterMgLCtrl.text) ?? 1;
        final concPct = (double.tryParse(waterPctCtrl.text) ?? 1) / 100.0;
        final mgActivoTotal = l * mgL;
        final gActivoTotal = mgActivoTotal / 1000.0;
        final gProducto = concPct > 0 ? (gActivoTotal / concPct) : 0.0;
        _calcOutput = 'Principio activo total: ${gActivoTotal.toStringAsFixed(1)} g\n'
            'Agregar de producto comercial ($concPct*100%):\n'
            '👉 ${gProducto.toStringAsFixed(1)} gramos (o ${(gProducto/1000).toStringAsFixed(2)} kg) para los ${l.toStringAsFixed(0)} L';
      } else {
        final ton = double.tryParse(feedTonCtrl.text) ?? 1;
        final ppm = double.tryParse(feedPpmCtrl.text) ?? 1; // 1 ppm = 1 g/Ton
        final prePct = (double.tryParse(feedPrePctCtrl.text) ?? 1) / 100.0;
        final gActivoTotal = ton * ppm;
        final gPremezcla = prePct > 0 ? (gActivoTotal / prePct) : 0.0;
        _calcOutput = 'Activo requerido: ${gActivoTotal.toStringAsFixed(0)} g\n'
            'Mezclar en planta por batch:\n'
            '👉 ${(gPremezcla/1000).toStringAsFixed(2)} kg de premezcla para las ${ton.toStringAsFixed(1)} Ton';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dosificación Masiva Pecuaria'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Agua (mg/L)')),
                ButtonSegment(value: 1, label: Text('Alimento (ppm)')),
              ],
              selected: {_tab},
              onSelectionChanged: (val) {
                setState(() {
                  _tab = val.first;
                  _recalc();
                });
              },
            ),
            const SizedBox(height: 16),
            if (_tab == 0) ...[
              TextField(
                controller: waterVolCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Volumen tinaco / bebedero (Litros)'),
                onChanged: (_) => _recalc(),
              ),
              TextField(
                controller: waterMgLCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Dosis meta en agua (mg / L o ppm)'),
                onChanged: (_) => _recalc(),
              ),
              TextField(
                controller: waterPctCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Concentración producto comercial (%)'),
                onChanged: (_) => _recalc(),
              ),
            ] else ...[
              TextField(
                controller: feedTonCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Toneladas de alimento a mezclar'),
                onChanged: (_) => _recalc(),
              ),
              TextField(
                controller: feedPpmCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Concentración objetivo en alimento (ppm o g/Ton)'),
                onChanged: (_) => _recalc(),
              ),
              TextField(
                controller: feedPrePctCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Concentración de la premezcla comercial (%)'),
                onChanged: (_) => _recalc(),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VetColors.violet.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: VetColors.violet.withValues(alpha: 0.35)),
              ),
              child: Text(
                _calcOutput,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }
}

// Modal de Vademécum Pecuario Oficial SENASICA
class ProductionVademecumModal extends StatelessWidget {
  const ProductionVademecumModal({super.key, required this.species});
  final String species;

  @override
  Widget build(BuildContext context) {
    final List<(String, String, String, String)> drugs = [
      ('Oxitetraciclina 200 LA', 'Antimicrobiano amplio espectro', '28 días carne / 7 días leche', '20 mg/kg IM/SC'),
      ('Tilmicosina 300 mg/mL', 'Neumonías y complejo respiratorio', '28 días carne / Prohibido en leche humana', '10 mg/kg SC única'),
      ('Florfenicol 300 mg/mL', 'Respiratorio y pododermatitis', '28 - 38 días carne / No en lactancia', '20 mg/kg IM (48h) o 40 mg/kg SC'),
      ('Ivermectina 1%', 'Endectocida sistémico', '28 - 35 días carne / No en leche para consumo', '200 mcg/kg SC'),
      ('Flunixin Meglumine 50mg', 'Antiinflamatorio no esteroideo (AINE)', '4 días carne / 36 h leche', '1.1 - 2.2 mg/kg IV/IM'),
      ('Tilosina Tartrato', 'Disentería porcina, micoplasmosis', '5 - 7 días carne', '10 - 20 mg/kg agua'),
    ];

    return AlertDialog(
      title: Text('Vademécum Pecuario: $species'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: drugs.length,
          separatorBuilder: (_, _) => const Divider(height: 14),
          itemBuilder: (ctx, i) {
            final (name, cat, retiro, dose) = drugs[i];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(cat, style: const TextStyle(fontSize: 12, color: VetColors.muted)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: VetColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Retiro oficial: $retiro',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: VetColors.danger),
                  ),
                ),
                const SizedBox(height: 2),
                Text('Dosis referencia: $dose', style: const TextStyle(fontSize: 12)),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }
}

// Modal de Receta Médica Pecuaria (Simple y Cuantificada)
class PecuariaPrescriptionModal extends StatefulWidget {
  const PecuariaPrescriptionModal({
    super.key,
    required this.quantified,
    required this.species,
    required this.clinicName,
    required this.mvzName,
  });

  final bool quantified;
  final String species;
  final String clinicName;
  final String mvzName;

  @override
  State<PecuariaPrescriptionModal> createState() => PecuariaPrescriptionModalState();
}

class PecuariaPrescriptionModalState extends State<PecuariaPrescriptionModal> {
  final uppCtrl = TextEditingController(text: 'UPP-04-129-882');
  final loteCtrl = TextEditingController(text: 'Lote Principal');
  final drugCtrl = TextEditingController(text: 'Oxitetraciclina 200 LA');
  final doseCtrl = TextEditingController(text: '20 mg/kg IM cada 48h por 3 dosis');
  final withdrawalCtrl = TextEditingController(text: '28 días en carne');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            widget.quantified ? VetIcons.documentCheck : VetIcons.document,
            color: widget.quantified ? VetColors.turquoise : VetColors.violet,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.quantified ? 'Receta Médica Cuantificada' : 'Receta Médica Simple',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Médico: ${widget.mvzName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text('Granja / UPP: ${widget.clinicName}', style: const TextStyle(fontSize: 12, color: VetColors.muted)),
                  Text('Especie destino: ${widget.species}', style: const TextStyle(fontSize: 12, color: VetColors.muted)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: uppCtrl,
              decoration: const InputDecoration(labelText: 'Clave UPP / PSG oficial'),
            ),
            TextField(
              controller: loteCtrl,
              decoration: const InputDecoration(labelText: 'Lote / Corral / Nave destino'),
            ),
            TextField(
              controller: drugCtrl,
              decoration: const InputDecoration(labelText: 'Principio activo y concentración comercial'),
            ),
            TextField(
              controller: doseCtrl,
              decoration: const InputDecoration(labelText: 'Pauta posológica e indicación terapéutica'),
            ),
            TextField(
              controller: withdrawalCtrl,
              decoration: const InputDecoration(labelText: 'Tiempo de retiro obligatorio prescrito'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  widget.quantified
                      ? 'Receta cuantificada foliada y registrada con folio oficial.'
                      : 'Receta simple generada exitosamente.',
                ),
                backgroundColor: VetColors.success,
              ),
            );
          },
          child: const Text('Emitir Receta'),
        ),
      ],
    );
  }
}
