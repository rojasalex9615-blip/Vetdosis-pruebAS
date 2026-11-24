import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/widgets/accent_glow.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_icons.dart';
import '../../../vet_ui/vet_theme.dart';
import '../../auth/domain/clinic_membership.dart';
import '../../core/domain/module_access.dart';
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

  int get autonomyDays => dailyConsumptionKg > 0
      ? (stockTon * 1000 / dailyConsumptionKg).floor()
      : 0;
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
      SiloData(
        phase: 'Silo Ensilado Maíz',
        stockTon: 85.0,
        capacityTon: 120.0,
        dailyConsumptionKg: 4800,
      ),
      SiloData(
        phase: 'Concentrado Alta Producción',
        stockTon: 9.5,
        capacityTon: 25.0,
        dailyConsumptionKg: 1900,
      ),
      SiloData(
        phase: 'Heno Alfalfa / Forraje',
        stockTon: 32.0,
        capacityTon: 40.0,
        dailyConsumptionKg: 1400,
      ),
    ],
    facilities: [
      FacilityData(
        id: 'Establo 1',
        batchId: 'Lote Alta Prod',
        ageDays: 120,
        density: 14.5,
        densityUnit: 'm²/vaca',
        mortalityRate: 0.5,
        sanitaryStatus: 'stable',
        sanitaryNote: 'Sin novedades',
      ),
      FacilityData(
        id: 'Establo 2',
        batchId: 'Lote Media Prod',
        ageDays: 210,
        density: 16.0,
        densityUnit: 'm²/vaca',
        mortalityRate: 0.8,
        sanitaryStatus: 'stable',
        sanitaryNote: 'Alimentación ajustada',
      ),
      FacilityData(
        id: 'Corral Preparto',
        batchId: 'Transición B-1',
        ageDays: 265,
        density: 22.0,
        densityUnit: 'm²/vaca',
        mortalityRate: 0.0,
        sanitaryStatus: 'warning',
        sanitaryNote: '3 vacas próximas a parto',
      ),
      FacilityData(
        id: 'Cunas Terneras',
        batchId: 'Crianza C-26',
        ageDays: 35,
        density: 4.5,
        densityUnit: 'm²/becerra',
        mortalityRate: 1.2,
        sanitaryStatus: 'critical',
        sanitaryNote: 'Tratamiento diarrea neonatal en curso',
      ),
    ],
    calendarEvents: [
      CalendarEvent(
        title: 'Vacunación Clostridiosis y Pasteurelosis',
        batch: 'Lote Transición',
        dateStr: 'Hoy · 09:00',
        category: 'Vacuna',
      ),
      CalendarEvent(
        title: 'Revisión ginecológica y eco de preñez',
        batch: 'Lote Alta Prod',
        dateStr: 'Mañana · 07:30',
        category: 'Servicio',
      ),
      CalendarEvent(
        title: 'Desparasitación lote vaquillas',
        batch: 'Vaquillas V-2',
        dateStr: 'En 3 días',
        category: 'Sanidad',
      ),
    ],
    vitals: [
      VitalSign(
        parameter: 'Temperatura rectal',
        range: '38.0 - 39.3',
        unit: '°C',
      ),
      VitalSign(
        parameter: 'Frecuencia cardíaca',
        range: '60 - 80',
        unit: 'lpm',
      ),
      VitalSign(
        parameter: 'Frecuencia respiratoria',
        range: '15 - 35',
        unit: 'rpm',
      ),
      VitalSign(
        parameter: 'Movimientos ruminales',
        range: '2 - 3',
        unit: 'mov / 2 min',
      ),
    ],
    withdrawals: [
      WithdrawalAlert(
        facility: 'Establo 1 / Vaca #402',
        batch: 'Lote Alta Prod',
        drug: 'Ceftiofur sódico 50mg/mL',
        daysRemaining: 2,
        totalWithdrawalDays: 3,
        destination: 'Leche (0 d) / Carne (3 d)',
      ),
      WithdrawalAlert(
        facility: 'Corral 3 / Toro #18',
        batch: 'Sementales',
        drug: 'Ivermectina 1%',
        daysRemaining: 18,
        totalWithdrawalDays: 35,
        destination: 'Carne',
      ),
    ],
    batches: [
      BatchData(
        name: 'Hato Lechero Lote 1',
        headcount: 140,
        stage: 'Lactancia Temprana',
        daysInStage: 65,
        lastRecordDate: 'Hoy 06:00',
        lastRecordDetail: '3,850 L ordeña matutina',
      ),
      BatchData(
        name: 'Hato Lechero Lote 2',
        headcount: 180,
        stage: 'Lactancia Media',
        daysInStage: 160,
        lastRecordDate: 'Hoy 06:00',
        lastRecordDetail: '4,120 L ordeña matutina',
      ),
      BatchData(
        name: 'Vaquillas de Reemplazo',
        headcount: 85,
        stage: 'Crecimiento',
        daysInStage: 280,
        lastRecordDate: 'Ayer',
        lastRecordDetail: 'Pesaje promedio 345 kg',
      ),
      BatchData(
        name: 'Vacas Secas y Retiro',
        headcount: 45,
        stage: 'Periodo Seco',
        daysInStage: 42,
        lastRecordDate: 'Hace 2 días',
        lastRecordDetail: 'Aplicación sellador pezones',
      ),
    ],
    alerts: [
      ProductionAlert(
        title: 'Partos próximos (48h)',
        subtitle: '3 vacas en corral de maternidad preparto',
        type: 'birth',
        daysLeft: 2,
      ),
      ProductionAlert(
        title: 'Retiro de Ceftiofur en curso',
        subtitle: 'Vaca #402: faltan 2 días para liberar a rastro',
        type: 'withdrawal',
        daysLeft: 2,
      ),
      ProductionAlert(
        title: 'Revacunación Carbunco Sintomático',
        subtitle: 'Lote Vaquillas de Reemplazo',
        type: 'vaccine',
        daysLeft: 5,
      ),
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
      SiloData(
        phase: 'Silo Preiniciador / Destete',
        stockTon: 4.8,
        capacityTon: 10.0,
        dailyConsumptionKg: 650,
      ),
      SiloData(
        phase: 'Silo Crecimiento / Desarrollo',
        stockTon: 8.2,
        capacityTon: 25.0,
        dailyConsumptionKg: 2100,
      ),
      SiloData(
        phase: 'Silo Finalizador Engorda',
        stockTon: 22.5,
        capacityTon: 30.0,
        dailyConsumptionKg: 3200,
      ),
    ],
    facilities: [
      FacilityData(
        id: 'Nave Maternidad',
        batchId: 'Camadas Semana 46',
        ageDays: 18,
        density: 1.0,
        densityUnit: 'hembra+camada',
        mortalityRate: 4.5,
        sanitaryStatus: 'stable',
        sanitaryNote: '11.8 lechones destetados/hembra',
      ),
      FacilityData(
        id: 'Nave Destete 1',
        batchId: 'Lote Des-204',
        ageDays: 45,
        density: 0.35,
        densityUnit: 'm²/lechón',
        mortalityRate: 1.1,
        sanitaryStatus: 'stable',
        sanitaryNote: 'Consumo normal 780g/día',
      ),
      FacilityData(
        id: 'Nave Engorda A',
        batchId: 'Lote Eng-102',
        ageDays: 110,
        density: 0.85,
        densityUnit: 'm²/cerdo',
        mortalityRate: 1.8,
        sanitaryStatus: 'warning',
        sanitaryNote: 'Monitoreo de tos matutina',
      ),
      FacilityData(
        id: 'Nave Engorda B',
        batchId: 'Lote Eng-103',
        ageDays: 140,
        density: 0.95,
        densityUnit: 'm²/cerdo',
        mortalityRate: 2.2,
        sanitaryStatus: 'critical',
        sanitaryNote: 'Medicación en agua con Tilosina activa',
      ),
    ],
    calendarEvents: [
      CalendarEvent(
        title: 'Vacunación Mycoplasma + PCV2',
        batch: 'Lote Des-204',
        dateStr: 'Hoy · 11:00',
        category: 'Vacuna',
      ),
      CalendarEvent(
        title: 'Destete programado 28 camadas',
        batch: 'Maternidad Sala 2',
        dateStr: 'Jueves · 06:00',
        category: 'Destete',
      ),
      CalendarEvent(
        title: 'Inseminación Artificial lote 35 cerdas',
        batch: 'Gestación 1',
        dateStr: 'Viernes · 07:00',
        category: 'Servicio',
      ),
      CalendarEvent(
        title: 'Movimiento a Finalizador (Nave 4)',
        batch: 'Lote Crec-88',
        dateStr: 'Sábado',
        category: 'Movimiento',
      ),
    ],
    vitals: [
      VitalSign(
        parameter: 'Temperatura rectal',
        range: '38.5 - 39.5',
        unit: '°C',
      ),
      VitalSign(
        parameter: 'Frecuencia cardíaca',
        range: '70 - 100',
        unit: 'lpm',
      ),
      VitalSign(
        parameter: 'Frecuencia respiratoria',
        range: '20 - 40',
        unit: 'rpm',
      ),
      VitalSign(
        parameter: 'Consumo diario agua',
        range: '8 - 15',
        unit: 'L / cerdo final',
      ),
    ],
    withdrawals: [
      WithdrawalAlert(
        facility: 'Nave Engorda B',
        batch: 'Lote Eng-103',
        drug: 'Tilosina tartrato en agua',
        daysRemaining: 5,
        totalWithdrawalDays: 7,
        destination: 'Carne',
      ),
      WithdrawalAlert(
        facility: 'Corral Enfermería 2',
        batch: 'Lote Tratados',
        drug: 'Florfenicol 300mg',
        daysRemaining: 14,
        totalWithdrawalDays: 28,
        destination: 'Carne',
      ),
    ],
    batches: [
      BatchData(
        name: 'Lote Engorda Final 101',
        headcount: 520,
        stage: 'Finalizador Engorda',
        daysInStage: 42,
        lastRecordDate: 'Hoy',
        lastRecordDetail: 'Peso prom: 104 kg · Consumo: 2.9 kg/d',
      ),
      BatchData(
        name: 'Lote Engorda A 102',
        headcount: 490,
        stage: 'Crecimiento',
        daysInStage: 28,
        lastRecordDate: 'Ayer',
        lastRecordDetail: 'Peso prom: 72 kg · ICA: 2.45',
      ),
      BatchData(
        name: 'Lote Destete 204',
        headcount: 560,
        stage: 'Destete / Transición',
        daysInStage: 21,
        lastRecordDate: 'Hace 2 días',
        lastRecordDetail: 'Peso prom: 19.8 kg',
      ),
      BatchData(
        name: 'Plantel Reproductoras',
        headcount: 280,
        stage: 'Gestación / Maternidad',
        daysInStage: 80,
        lastRecordDate: 'Hoy',
        lastRecordDetail: 'Condición corporal: 3.25',
      ),
    ],
    alerts: [
      ProductionAlert(
        title: 'Tilosina activa en Nave B',
        subtitle: 'Lote Eng-103 con 5 días restantes de resguardo cárnico',
        type: 'withdrawal',
        daysLeft: 5,
      ),
      ProductionAlert(
        title: 'Inseminación masiva de cerdas',
        subtitle: 'Lote 14 hembras post-destete detectadas en celo',
        type: 'birth',
        daysLeft: 1,
      ),
      ProductionAlert(
        title: 'Vacuna Parvovirus / Leptospira',
        subtitle: 'Hembras de reemplazo a los 6 meses de edad',
        type: 'vaccine',
        daysLeft: 7,
      ),
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
      SiloData(
        phase: 'Iniciador Parrillero',
        stockTon: 14.0,
        capacityTon: 20.0,
        dailyConsumptionKg: 1800,
      ),
      SiloData(
        phase: 'Crecimiento Aviar',
        stockTon: 18.5,
        capacityTon: 35.0,
        dailyConsumptionKg: 4200,
      ),
      SiloData(
        phase: 'Finalizador Engorda (Retiro)',
        stockTon: 8.0,
        capacityTon: 40.0,
        dailyConsumptionKg: 5800,
      ),
    ],
    facilities: [
      FacilityData(
        id: 'Caseta 01 (Túnel)',
        batchId: 'Parvada Ross-308 #12',
        ageDays: 35,
        density: 13.5,
        densityUnit: 'aves/m²',
        mortalityRate: 2.1,
        sanitaryStatus: 'stable',
        sanitaryNote: 'Ventilación y cama óptimas',
      ),
      FacilityData(
        id: 'Caseta 02 (Túnel)',
        batchId: 'Parvada Ross-308 #13',
        ageDays: 28,
        density: 14.0,
        densityUnit: 'aves/m²',
        mortalityRate: 1.8,
        sanitaryStatus: 'stable',
        sanitaryNote: 'Ganancia 85g/día',
      ),
      FacilityData(
        id: 'Caseta 03 (Abierta)',
        batchId: 'Postura Lohmann #4',
        ageDays: 196,
        density: 8.2,
        densityUnit: 'aves/m²',
        mortalityRate: 0.9,
        sanitaryStatus: 'stable',
        sanitaryNote: 'Postura al 93.4%',
      ),
    ],
    calendarEvents: [
      CalendarEvent(
        title: 'Vacunación Gumboro cepa intermedia en agua',
        batch: 'Caseta 02',
        dateStr: 'Hoy · 06:30',
        category: 'Vacuna',
      ),
      CalendarEvent(
        title: 'Pase a alimento finalizador sin coccidiostato',
        batch: 'Caseta 01',
        dateStr: 'En 2 días',
        category: 'Alimento',
      ),
      CalendarEvent(
        title: 'Muestreo de serología Salmonella e Influenza',
        batch: 'Todas las casetas',
        dateStr: 'En 4 días',
        category: 'Sanidad',
      ),
    ],
    vitals: [
      VitalSign(
        parameter: 'Temperatura corporal',
        range: '40.6 - 41.7',
        unit: '°C',
      ),
      VitalSign(
        parameter: 'Frecuencia respiratoria',
        range: '25 - 40',
        unit: 'rpm',
      ),
      VitalSign(
        parameter: 'Frecuencia cardíaca',
        range: '250 - 400',
        unit: 'lpm',
      ),
      VitalSign(
        parameter: 'Relación agua:alimento',
        range: '1.8 : 1 a 2.0 : 1',
        unit: 'L / kg',
      ),
    ],
    withdrawals: [
      WithdrawalAlert(
        facility: 'Caseta 01',
        batch: 'Parvada Ross-308 #12',
        drug: 'Enrofloxacina 10% oral',
        daysRemaining: 4,
        totalWithdrawalDays: 7,
        destination: 'Carne (huevo no permitido)',
      ),
    ],
    batches: [
      BatchData(
        name: 'Parvada Engorda Caseta 1',
        headcount: 18000,
        stage: 'Finalizador Engorda',
        daysInStage: 35,
        lastRecordDate: 'Hoy',
        lastRecordDetail: 'Peso promedio 2,210 g',
      ),
      BatchData(
        name: 'Parvada Engorda Caseta 2',
        headcount: 18000,
        stage: 'Crecimiento',
        daysInStage: 28,
        lastRecordDate: 'Ayer',
        lastRecordDetail: 'Peso promedio 1,530 g',
      ),
      BatchData(
        name: 'Lote Ponedoras Caseta 3',
        headcount: 6000,
        stage: 'Pico de Postura',
        daysInStage: 120,
        lastRecordDate: 'Hoy 10:00',
        lastRecordDetail: '5,604 huevos recolectados (93.4%)',
      ),
    ],
    alerts: [
      ProductionAlert(
        title: 'Retiro Enrofloxacina en Caseta 01',
        subtitle: '4 días restantes de resguardo antes de salida al rastro',
        type: 'withdrawal',
        daysLeft: 4,
      ),
      ProductionAlert(
        title: 'Cambio de fase alimenticia Caseta 2',
        subtitle: 'Transición a alimento finalizador programada',
        type: 'feed',
        daysLeft: 2,
      ),
      ProductionAlert(
        title: 'Inspección de bioseguridad arcos sanitarios',
        subtitle: 'Revisión periódica de desinfectante y registros',
        type: 'sanitary',
        daysLeft: 3,
      ),
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
      SiloData(
        phase: 'Concentrado Ovinos Engorda',
        stockTon: 8.5,
        capacityTon: 15.0,
        dailyConsumptionKg: 650,
      ),
      SiloData(
        phase: 'Pacas Henil Avena/Alfalfa',
        stockTon: 16.0,
        capacityTon: 25.0,
        dailyConsumptionKg: 900,
      ),
    ],
    facilities: [
      FacilityData(
        id: 'Corral Engorda 1',
        batchId: 'Lote Corderos Dorper A',
        ageDays: 85,
        density: 1.8,
        densityUnit: 'm²/cordero',
        mortalityRate: 0.8,
        sanitaryStatus: 'stable',
        sanitaryNote: 'Ganancia 305g/d',
      ),
      FacilityData(
        id: 'Corral Hembras Gestantes',
        batchId: 'Hato Cría Katahdin',
        ageDays: 115,
        density: 3.2,
        densityUnit: 'm²/oveja',
        mortalityRate: 0.2,
        sanitaryStatus: 'warning',
        sanitaryNote: 'Partos programados semana próxima',
      ),
      FacilityData(
        id: 'Área Ordeña Caprina',
        batchId: 'Hato Saanen / Alpino',
        ageDays: 140,
        density: 4.0,
        densityUnit: 'm²/cabra',
        mortalityRate: 0.5,
        sanitaryStatus: 'stable',
        sanitaryNote: '2.8 L/cabra/día',
      ),
    ],
    calendarEvents: [
      CalendarEvent(
        title: 'Vacuna Clostridial 8 vías + Tétanos',
        batch: 'Corderos Destetados',
        dateStr: 'Mañana · 08:00',
        category: 'Vacuna',
      ),
      CalendarEvent(
        title: 'Diagnóstico de preñez por ultrasonido',
        batch: 'Hato Dorper',
        dateStr: 'En 3 días',
        category: 'Servicio',
      ),
      CalendarEvent(
        title: 'Recorte de pezuñas y pediluvio sulfato',
        batch: 'Todo el rebaño',
        dateStr: 'En 5 días',
        category: 'Manejo',
      ),
    ],
    vitals: [
      VitalSign(
        parameter: 'Temperatura rectal',
        range: '38.5 - 40.0',
        unit: '°C',
      ),
      VitalSign(
        parameter: 'Frecuencia cardíaca',
        range: '70 - 90',
        unit: 'lpm',
      ),
      VitalSign(
        parameter: 'Frecuencia respiratoria',
        range: '16 - 34',
        unit: 'rpm',
      ),
      VitalSign(
        parameter: 'Movimientos ruminales',
        range: '2 - 3',
        unit: 'mov / 2 min',
      ),
    ],
    withdrawals: [
      WithdrawalAlert(
        facility: 'Corral Engorda 1',
        batch: 'Corderos Dorper A',
        drug: 'Levamisol 12%',
        daysRemaining: 6,
        totalWithdrawalDays: 14,
        destination: 'Carne',
      ),
    ],
    batches: [
      BatchData(
        name: 'Lote Corderos Engorda 1',
        headcount: 220,
        stage: 'Finalización Engorda',
        daysInStage: 60,
        lastRecordDate: 'Hoy',
        lastRecordDetail: 'Peso promedio 41.5 kg',
      ),
      BatchData(
        name: 'Rebaño Cría Katahdin',
        headcount: 280,
        stage: 'Gestación Avanzada',
        daysInStage: 118,
        lastRecordDate: 'Ayer',
        lastRecordDetail: 'Calificación FAMACHA grado 1-2',
      ),
      BatchData(
        name: 'Hato Lechero Caprino Saanen',
        headcount: 120,
        stage: 'Lactancia',
        daysInStage: 90,
        lastRecordDate: 'Hoy 07:00',
        lastRecordDetail: 'Producción 336 L leche',
      ),
    ],
    alerts: [
      ProductionAlert(
        title: 'Resguardo de Levamisol en Engorda',
        subtitle: '6 días restantes de retiro para lote Dorper A',
        type: 'withdrawal',
        daysLeft: 6,
      ),
      ProductionAlert(
        title: 'Partos programados próxima semana',
        subtitle: '18 ovejas multíparas en lote gestación',
        type: 'birth',
        daysLeft: 4,
      ),
      ProductionAlert(
        title: 'Desparasitación estratégica FAMACHA',
        subtitle: 'Revisión y dosificación selectiva de hembras',
        type: 'sanitary',
        daysLeft: 7,
      ),
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
      SiloData(
        phase: 'Alimento Extruido 32% Prot (Crecimiento)',
        stockTon: 12.0,
        capacityTon: 20.0,
        dailyConsumptionKg: 680,
      ),
      SiloData(
        phase: 'Alimento Extruido 28% Prot (Engorda)',
        stockTon: 18.5,
        capacityTon: 30.0,
        dailyConsumptionKg: 1020,
      ),
    ],
    facilities: [
      FacilityData(
        id: 'Estanque R-01 (Geomembrana)',
        batchId: 'Tilapia GIFT #09',
        ageDays: 110,
        density: 24.5,
        densityUnit: 'kg/m³',
        mortalityRate: 1.5,
        sanitaryStatus: 'stable',
        sanitaryNote: 'Oxígeno disuelto 6.2 mg/L',
      ),
      FacilityData(
        id: 'Estanque R-02 (Geomembrana)',
        batchId: 'Tilapia GIFT #10',
        ageDays: 75,
        density: 14.0,
        densityUnit: 'kg/m³',
        mortalityRate: 1.2,
        sanitaryStatus: 'stable',
        sanitaryNote: 'Temp 27.5 °C',
      ),
      FacilityData(
        id: 'Estanque R-03 (Tierra)',
        batchId: 'Bagre Canal #03',
        ageDays: 140,
        density: 8.5,
        densityUnit: 'kg/m³',
        mortalityRate: 2.8,
        sanitaryStatus: 'warning',
        sanitaryNote: 'Oxígeno bajo al amanecer (3.8 mg/L)',
      ),
    ],
    calendarEvents: [
      CalendarEvent(
        title: 'Biometría y pesaje quincenal lote R-01',
        batch: 'Estanque R-01',
        dateStr: 'Hoy · 08:30',
        category: 'Biometría',
      ),
      CalendarEvent(
        title: 'Limpieza y purga de filtros sedimentadores',
        batch: 'Módulos RAS',
        dateStr: 'Mañana',
        category: 'Mantenimiento',
      ),
      CalendarEvent(
        title: 'Desdoble y selección por tallas',
        batch: 'Estanque R-02',
        dateStr: 'En 3 días',
        category: 'Manejo',
      ),
    ],
    vitals: [
      VitalSign(
        parameter: 'Oxígeno disuelto ideal',
        range: '> 5.0',
        unit: 'mg/L',
      ),
      VitalSign(
        parameter: 'Temperatura de agua (Tilapia)',
        range: '26.0 - 30.0',
        unit: '°C',
      ),
      VitalSign(parameter: 'pH del agua', range: '6.5 - 8.5', unit: 'pH'),
      VitalSign(
        parameter: 'Amonio total (TAN)',
        range: '< 0.05',
        unit: 'mg/L tóxico',
      ),
    ],
    withdrawals: [
      WithdrawalAlert(
        facility: 'Estanque R-03',
        batch: 'Bagre Canal #03',
        drug: 'Florfenicol acuícola 50%',
        daysRemaining: 7,
        totalWithdrawalDays: 15,
        destination: 'Carne filete',
      ),
    ],
    batches: [
      BatchData(
        name: 'Lote Tilapia Estanque 1',
        headcount: 25000,
        stage: 'Engorda Final',
        daysInStage: 110,
        lastRecordDate: 'Hoy',
        lastRecordDetail: 'Peso prom: 535 g · Biomasa: 13.37 Ton',
      ),
      BatchData(
        name: 'Lote Tilapia Estanque 2',
        headcount: 28000,
        stage: 'Crecimiento',
        daysInStage: 75,
        lastRecordDate: 'Ayer',
        lastRecordDetail: 'Peso prom: 285 g · Biomasa: 7.98 Ton',
      ),
      BatchData(
        name: 'Lote Alevines Módulo A',
        headcount: 15000,
        stage: 'Alevinaje / Cría',
        daysInStage: 35,
        lastRecordDate: 'Hace 3 días',
        lastRecordDetail: 'Peso prom: 28 g',
      ),
    ],
    alerts: [
      ProductionAlert(
        title: 'Retiro activo Florfenicol Estanque 3',
        subtitle: '7 días de resguardo antes de cosecha para fileteo',
        type: 'withdrawal',
        daysLeft: 7,
      ),
      ProductionAlert(
        title: 'Alerta de Oxígeno bajo Estanque 3',
        subtitle: 'Incrementar aireación suplementaria nocturna',
        type: 'sanitary',
        daysLeft: 0,
      ),
      ProductionAlert(
        title: 'Próxima cosecha programada',
        subtitle: 'Lote Estanque 1 listo para planta procesadora',
        type: 'harvest',
        daysLeft: 12,
      ),
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
      SiloData(
        phase: 'Jarabe de Azúcar / Estimulación (Litros)',
        stockTon: 1.8,
        capacityTon: 3.0,
        dailyConsumptionKg: 80,
      ),
      SiloData(
        phase: 'Torta Proteica / Sustituto Polen (Kg)',
        stockTon: 0.6,
        capacityTon: 1.0,
        dailyConsumptionKg: 25,
      ),
    ],
    facilities: [
      FacilityData(
        id: 'Apiario 1 - Las Lomas',
        batchId: '45 Colmenas Dobles',
        ageDays: 180,
        density: 45,
        densityUnit: 'colmenas/apiario',
        mortalityRate: 2.2,
        sanitaryStatus: 'stable',
        sanitaryNote: 'Floración de mezquite activa',
      ),
      FacilityData(
        id: 'Apiario 2 - El Valle',
        batchId: '40 Colmenas Langstroth',
        ageDays: 150,
        density: 40,
        densityUnit: 'colmenas/apiario',
        mortalityRate: 1.5,
        sanitaryStatus: 'stable',
        sanitaryNote: 'Alzas melarias al 80%',
      ),
      FacilityData(
        id: 'Apiario 3 - Reserva',
        batchId: '35 Núcleos de Cría',
        ageDays: 60,
        density: 35,
        densityUnit: 'núcleos/apiario',
        mortalityRate: 3.0,
        sanitaryStatus: 'warning',
        sanitaryNote: 'Tratamiento orgánico de Varroa',
      ),
    ],
    calendarEvents: [
      CalendarEvent(
        title: 'Muestreo de infestación Varroa (conteo azúcar)',
        batch: 'Apiario 1',
        dateStr: 'Hoy · 09:00',
        category: 'Sanidad',
      ),
      CalendarEvent(
        title: 'Colocación de alzas melarias adicionales',
        batch: 'Apiario 2',
        dateStr: 'En 2 días',
        category: 'Manejo',
      ),
      CalendarEvent(
        title: 'Cambio de reinas fecundadas F1',
        batch: 'Apiario 3',
        dateStr: 'En 6 días',
        category: 'Genética',
      ),
    ],
    vitals: [
      VitalSign(
        parameter: 'Temperatura en cámara de cría',
        range: '34.5 - 35.5',
        unit: '°C',
      ),
      VitalSign(
        parameter: 'Humedad relativa en colmena',
        range: '55 - 65',
        unit: '%',
      ),
      VitalSign(
        parameter: 'Postura diaria reina',
        range: '1,500 - 2,000',
        unit: 'huevos/día',
      ),
    ],
    withdrawals: [
      WithdrawalAlert(
        facility: 'Apiario 3',
        batch: '35 Núcleos de Cría',
        drug: 'Ácido Oxálico por sublimación',
        daysRemaining: 0,
        totalWithdrawalDays: 0,
        destination: 'Miel (orgánico sin residuo en alzas vacías)',
      ),
    ],
    batches: [
      BatchData(
        name: 'Apiario 1 Las Lomas',
        headcount: 45,
        stage: 'Flujo Melario Principal',
        daysInStage: 35,
        lastRecordDate: 'Hoy',
        lastRecordDetail: '32 alzas operculadas listas',
      ),
      BatchData(
        name: 'Apiario 2 El Valle',
        headcount: 40,
        stage: 'Llenado de Alzas',
        daysInStage: 21,
        lastRecordDate: 'Hace 2 días',
        lastRecordDetail: 'Entrada fuerte de néctar',
      ),
      BatchData(
        name: 'Apiario 3 Núcleos',
        headcount: 35,
        stage: 'Multiplicación / Cría',
        daysInStage: 45,
        lastRecordDate: 'Hace 4 días',
        lastRecordDetail: 'Aceptación de reinas 92%',
      ),
    ],
    alerts: [
      ProductionAlert(
        title: 'Monitoreo de Varroa en Apiario 3',
        subtitle: 'Revisión posterior a tratamiento orgánico',
        type: 'sanitary',
        daysLeft: 2,
      ),
      ProductionAlert(
        title: 'Cosecha y centrifugado de miel',
        subtitle: 'Corte de miel de primavera en Apiario 1',
        type: 'harvest',
        daysLeft: 5,
      ),
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
      SiloData(
        phase: 'Concentrado Equino Balanceado 14% (Ton)',
        stockTon: 4.5,
        capacityTon: 10.0,
        dailyConsumptionKg: 210,
      ),
      SiloData(
        phase: 'Heno de Avena y Alfalfa Seleccionada (Pacas)',
        stockTon: 8.0,
        capacityTon: 15.0,
        dailyConsumptionKg: 350,
      ),
    ],
    facilities: [
      FacilityData(
        id: 'Cuadra A (Caballerizas)',
        batchId: 'Sementales y Entrenamiento',
        ageDays: 180,
        density: 16.0,
        densityUnit: 'm²/caballeriza',
        mortalityRate: 0.0,
        sanitaryStatus: 'stable',
        sanitaryNote: 'Paja limpia y desinfectada',
      ),
      FacilityData(
        id: 'Cuadra B (Yeguas)',
        batchId: 'Yeguas Gestantes / Lactantes',
        ageDays: 240,
        density: 20.0,
        densityUnit: 'm²/box',
        mortalityRate: 0.0,
        sanitaryStatus: 'stable',
        sanitaryNote: '2 potros nacidos saludables',
      ),
      FacilityData(
        id: 'Potrero 1 (Pastoreo)',
        batchId: 'Destetes y Añejos',
        ageDays: 320,
        density: 5000.0,
        densityUnit: 'm²/potro',
        mortalityRate: 0.0,
        sanitaryStatus: 'stable',
        sanitaryNote: 'Agua corriente y sombra',
      ),
    ],
    calendarEvents: [
      CalendarEvent(
        title: 'Vacuna Influenza Equina + Tétanos',
        batch: 'Cuadra A y B',
        dateStr: 'Hoy · 10:30',
        category: 'Vacuna',
      ),
      CalendarEvent(
        title: 'Desparasitación rotativa con Ivermectina + Praziquantel',
        batch: 'Todos los equinos',
        dateStr: 'En 3 días',
        category: 'Sanidad',
      ),
      CalendarEvent(
        title: 'Evaluación seminal semental estrella',
        batch: 'Semental "Azteca"',
        dateStr: 'En 5 días',
        category: 'Genética',
      ),
    ],
    vitals: [
      VitalSign(
        parameter: 'Temperatura rectal',
        range: '37.2 - 38.3',
        unit: '°C',
      ),
      VitalSign(
        parameter: 'Frecuencia cardíaca en reposo',
        range: '28 - 44',
        unit: 'lpm',
      ),
      VitalSign(
        parameter: 'Frecuencia respiratoria',
        range: '8 - 16',
        unit: 'rpm',
      ),
      VitalSign(
        parameter: 'Tiempo de llenado capilar (TLLC)',
        range: '< 2',
        unit: 'segundos',
      ),
    ],
    withdrawals: [
      WithdrawalAlert(
        facility: 'Cuadra A / Box 4',
        batch: 'Caballo Deporte #04',
        drug: 'Flunixin Meglumine 50mg/mL',
        daysRemaining: 3,
        totalWithdrawalDays: 7,
        destination: 'Control antidopaje deportivo',
      ),
    ],
    batches: [
      BatchData(
        name: 'Lote Sementales Activos',
        headcount: 6,
        stage: 'Monta y Extracción Seminal',
        daysInStage: 120,
        lastRecordDate: 'Hoy',
        lastRecordDetail: 'Colecta seminal 85% motilidad progresiva',
      ),
      BatchData(
        name: 'Lote Yeguas Gestantes',
        headcount: 16,
        stage: 'Último tercio gestación',
        daysInStage: 290,
        lastRecordDate: 'Ayer',
        lastRecordDetail: 'Monitoreo de ubre y pezones',
      ),
      BatchData(
        name: 'Lote Potros Crecimiento',
        headcount: 14,
        stage: 'Añejos 1-2 años',
        daysInStage: 180,
        lastRecordDate: 'Hace 3 días',
        lastRecordDetail: 'Alzada promedio 1.48 m',
      ),
      BatchData(
        name: 'Lote Trabajo / Deporte',
        headcount: 6,
        stage: 'Entrenamiento diario',
        daysInStage: 90,
        lastRecordDate: 'Hoy',
        lastRecordDetail: 'Rutina matutina completada',
      ),
    ],
    alerts: [
      ProductionAlert(
        title: 'Control antidopaje Box 4',
        subtitle:
            'Flunixin meglumine: 3 días restantes de ventana de detección',
        type: 'withdrawal',
        daysLeft: 3,
      ),
      ProductionAlert(
        title: 'Partos equinos próximos (72h)',
        subtitle: 'Yegua "Gitana" en monitoreo de calcio en leche',
        type: 'birth',
        daysLeft: 3,
      ),
      ProductionAlert(
        title: 'Desparasitación masiva de cuadras',
        subtitle: 'Rotación semestral de principio activo',
        type: 'sanitary',
        daysLeft: 3,
      ),
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
    this.initialSpecies = 'Bovinos',
  });

  final ValueChanged<String> onNavigate;
  final ClinicMembership? member;
  final ModuleAccess? access;
  final ProductionUnitRepository? units;
  final String initialSpecies;

  @override
  State<ProductionDashboard> createState() => _ProductionDashboardState();
}

class _ProductionDashboardState extends State<ProductionDashboard> {
  late String _selectedSpecies;
  final Set<String> _completedEvents = {};
  final Set<String> _clearedWithdrawals = {};

  final List<String> _speciesList = const [
    'Bovinos',
    'Porcinos',
    'Aves',
    'Ovinos / caprinos',
    'Peces',
    'Abejas',
    'Equinos',
  ];

  @override
  void initState() {
    super.initState();
    _selectedSpecies = widget.initialSpecies;
    if (!_speciesList.contains(_selectedSpecies)) {
      _selectedSpecies = 'Bovinos';
    }
  }

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

  void _openFacilityDetail(FacilityData facility) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(VetIcons.barn, color: VetColors.turquoise),
            const SizedBox(width: 8),
            Expanded(child: Text(facility.id)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lote actual: ${facility.batchId}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text('Edad / Ciclo: ${facility.ageDays} días'),
            Text('Densidad: ${facility.density} ${facility.densityUnit}'),
            Text('Mortalidad acumulada: ${facility.mortalityRate}%'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: facility.sanitaryStatus == 'critical'
                    ? VetColors.danger.withValues(alpha: 0.12)
                    : (facility.sanitaryStatus == 'warning'
                          ? VetColors.warning.withValues(alpha: 0.12)
                          : VetColors.success.withValues(alpha: 0.12)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    facility.sanitaryStatus == 'critical'
                        ? VetIcons.alertOctagon
                        : (facility.sanitaryStatus == 'warning'
                              ? VetIcons.alertTriangle
                              : VetIcons.checkCircle),
                    color: facility.sanitaryStatus == 'critical'
                        ? VetColors.danger
                        : (facility.sanitaryStatus == 'warning'
                              ? VetColors.warning
                              : VetColors.success),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Estado 24h: ${facility.sanitaryNote}',
                      style: TextStyle(
                        fontSize: 14,
                        color: facility.sanitaryStatus == 'critical'
                            ? VetColors.danger
                            : (facility.sanitaryStatus == 'warning'
                                  ? VetColors.warning
                                  : VetColors.success),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
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

        // Banner Crítico de Tiempos de Retiro (Alerta Crítica)
        _buildWithdrawalBanner(metrics),
        const SizedBox(height: 16),

        // Fila 1: Pulso Financiero y Productivo (KPIs de Alto Impacto)
        _buildRow1Kpis(metrics),
        const SizedBox(height: 20),

        // Fila 2: Gráficas de Rendimiento (Núcleo Analítico)
        _buildRow2Analytics(metrics, specAccent),
        const SizedBox(height: 20),

        // Fila 3: Mapa Operativo de Instalaciones (Naves / Corrales / Estanques)
        _buildRow3Facilities(metrics),
        const SizedBox(height: 20),

        // Fila 4: Ejecución Diaria (Calendario Sanitario & Dosificación Masiva)
        _buildRow4DailyExecution(metrics),
        const SizedBox(height: 24),

        // 2. Herramientas de la especie elegida (tarjetas interactivas)
        _buildSpeciesToolsSection(metrics, specIcon, specAccent),
        const SizedBox(height: 24),

        // 3. Mis lotes / hatos (resumen)
        _buildBatchesSummarySection(metrics),
        const SizedBox(height: 24),

        // 4. Alertas (vacunas por vencer, retiros, partos o servicios próximos)
        _buildAlertsSection(metrics),
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
                          Text(sp),
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

  // BANNER CRÍTICO: Tiempos de Retiro
  Widget _buildWithdrawalBanner(SpeciesMetrics metrics) {
    final activeWithdrawals = metrics.withdrawals
        .where((w) => !_clearedWithdrawals.contains('${w.facility}_${w.drug}'))
        .toList();

    if (activeWithdrawals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: VetColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VetColors.success.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(VetIcons.checkCircle, color: VetColors.success, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sin tiempos de retiro activos en esta especie. Todos los lotes aptos para consumo/venta.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: VetColors.success,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VetColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VetColors.danger.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                VetIcons.alertOctagon,
                color: VetColors.danger,
                size: 22,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ALERTA CRÍTICA: TIEMPOS DE RETIRO ACTIVOS',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: VetColors.danger,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: VetColors.danger,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${activeWithdrawals.length} ACTIVOS',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Prohibida la salida a rastro, ordeña o comercialización sin cumplir periodo de resguardo farmacológico:',
            style: TextStyle(fontSize: 12, color: VetColors.muted),
          ),
          const SizedBox(height: 10),
          for (final w in activeWithdrawals) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${w.facility} · ${w.batch}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Fármaco: ${w.drug} (${w.destination})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: VetColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: VetColors.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Faltan ${w.daysRemaining} d',
                      style: const TextStyle(
                        color: VetColors.danger,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // FILA 1: Pulso Financiero y Productivo (KPIs de Alto Impacto)
  Widget _buildRow1Kpis(SpeciesMetrics metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VetSectionHeader(
          title: 'Pulso Financiero y Productivo',
          subtitle: 'KPIs clave actualizados de la piara, hato o parvada',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // KPI 1: Costo por unidad producida
            Expanded(
              child: _KpiCard(
                title: metrics.costMetricTitle,
                value: '\$${metrics.costValue.toStringAsFixed(2)}',
                unit: metrics.costUnit,
                indicatorText: metrics.costDiff,
                indicatorPositive: metrics.costDiffPositive,
                icon: VetIcons.banknote,
                accentColor: VetColors.turquoise,
              ),
            ),
            const SizedBox(width: 8),
            // KPI 2: Conversión Alimenticia (ICA)
            Expanded(
              child: _KpiCard(
                title: 'Conversión Alimenticia (ICA)',
                value: metrics.fcaValue > 0
                    ? metrics.fcaValue.toStringAsFixed(2)
                    : 'N/A',
                unit: metrics.fcaUnit,
                indicatorText: 'Promedio activo',
                indicatorPositive: true,
                icon: VetIcons.balance,
                accentColor: VetColors.violet,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // KPI 3: Inventario total
            Expanded(
              child: _KpiCard(
                title: 'Inventario Total en Granja',
                value: '${metrics.totalHeads}',
                unit: 'cabezas / animales',
                indicatorText: 'Censo activo',
                indicatorPositive: true,
                icon: VetIcons.clipboardList,
                accentColor: VetColors.cyan,
              ),
            ),
            const SizedBox(width: 8),
            // KPI 4: Biomasa viva estimada
            Expanded(
              child: _KpiCard(
                title: 'Biomasa Viva Estimada',
                value: metrics.biomassTonnes > 0
                    ? metrics.biomassTonnes.toStringAsFixed(1)
                    : 'N/A',
                unit: 'Toneladas vivas',
                indicatorText: 'Proyección de venta',
                indicatorPositive: true,
                icon: VetIcons.kgToMeat,
                accentColor: VetColors.pink,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // FILA 2: Gráficas de Rendimiento (Núcleo Analítico)
  Widget _buildRow2Analytics(SpeciesMetrics metrics, Color specAccent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VetSectionHeader(
          title: 'Núcleo Analítico de Rendimiento',
          subtitle: 'Curva genética vs real y autonomía de inventario en silos',
        ),
        const SizedBox(height: 10),
        VetCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      metrics.curveMetricTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: VetColors.turquoise.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '+2.8% vs estándar genético',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: VetColors.turquoise,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Canvas de la curva
              SizedBox(
                height: 140,
                child: CustomPaint(
                  size: const Size(double.infinity, 140),
                  painter: _PerformanceCurvePainter(
                    theoretical: metrics.theoreticalPoints,
                    real: metrics.realPoints,
                    accentColor: specAccent,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 3,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Tabla Genética Teórica',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: VetColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 12, height: 3, color: specAccent),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Rendimiento Real en Granja',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Consumo de Alimento vs Inventario en Silos
        VetCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Inventario en Silos y Autonomía',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Flexible(
                    child: TextButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Pedido automático enviado a planta de alimentos.',
                            ),
                            backgroundColor: VetColors.turquoise,
                          ),
                        );
                      },
                      icon: const Icon(VetIcons.cart, size: 16),
                      label: const Text(
                        'Pedir a planta',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final silo in metrics.silos) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              silo.phase,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${silo.stockTon} / ${silo.capacityTon} Ton (${(silo.percentage * 100).toStringAsFixed(0)}%)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: VetColors.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: silo.percentage,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            silo.autonomyDays <= 5
                                ? VetColors.danger
                                : VetColors.turquoise,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Consumo: ${(silo.dailyConsumptionKg).toStringAsFixed(0)} kg/día',
                              style: const TextStyle(
                                fontSize: 12,
                                color: VetColors.muted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              silo.autonomyDays <= 5
                                  ? 'Autonomía: ${silo.autonomyDays} días ⚠️ ¡URGENTE!'
                                  : 'Autonomía: ${silo.autonomyDays} días',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: silo.autonomyDays <= 5
                                    ? VetColors.danger
                                    : VetColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // FILA 3: Mapa Operativo de Instalaciones
  Widget _buildRow3Facilities(SpeciesMetrics metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VetSectionHeader(
          title: 'Mapa Operativo de Instalaciones',
          subtitle:
              'Naves, corrales y estanques con densidad y semáforo sanitario 24h',
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.sizeOf(context).width >= 420 ? 2 : 1,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 132,
          ),
          itemCount: metrics.facilities.length,
          itemBuilder: (context, idx) {
            final f = metrics.facilities[idx];
            final statusColor = f.sanitaryStatus == 'critical'
                ? VetColors.danger
                : (f.sanitaryStatus == 'warning'
                      ? VetColors.warning
                      : VetColors.success);

            return InkWell(
              onTap: () => _openFacilityDetail(f),
              borderRadius: BorderRadius.circular(16),
              child: VetCard(
                padding: const EdgeInsets.all(12),
                radius: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            f.id,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      f.batchId,
                      style: const TextStyle(
                        fontSize: 12,
                        color: VetColors.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Divider(height: 10),
                    _facilityRow('Edad / Ciclo:', '${f.ageDays} d', bold: true),
                    _facilityRow(
                      'Densidad:',
                      '${f.density} ${f.densityUnit}',
                      bold: true,
                    ),
                    _facilityRow(
                      'Mortalidad:',
                      '${f.mortalityRate}%',
                      color: f.mortalityRate > 2.0
                          ? VetColors.danger
                          : VetColors.ink,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _facilityRow(
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) => Row(
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: VetColors.muted)),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          value,
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ),
    ],
  );

  // FILA 4: Ejecución Diaria (Calendario + Dosificación Masiva)
  Widget _buildRow4DailyExecution(SpeciesMetrics metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VetSectionHeader(
          title: 'Ejecución Diaria en Campo',
          subtitle:
              'Calendario zoosanitario de lote y dosificación masiva en agua y alimento',
        ),
        const SizedBox(height: 10),
        VetCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(
                          VetIcons.calendarCheck,
                          color: VetColors.violet,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Calendario Zootécnico y Sanitario',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _openMassMedicationDialog(),
                    icon: const Icon(VetIcons.calculator, size: 16),
                    label: const Text(
                      'Dosificación Masiva',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final ev in metrics.calendarEvents) ...[
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _completedEvents.contains(ev.title),
                  title: Text(
                    ev.title,
                    style: TextStyle(
                      fontSize: 14,
                      decoration: _completedEvents.contains(ev.title)
                          ? TextDecoration.lineThrough
                          : null,
                      color: _completedEvents.contains(ev.title)
                          ? VetColors.muted
                          : null,
                    ),
                  ),
                  subtitle: Text(
                    '${ev.batch} · ${ev.dateStr} (${ev.category})',
                    style: const TextStyle(
                      fontSize: 12,
                      color: VetColors.muted,
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _completedEvents.add(ev.title);
                      } else {
                        _completedEvents.remove(ev.title);
                      }
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // 2. HERRAMIENTAS DE LA ESPECIE ELEGIDA (Tarjetas)
  Widget _buildSpeciesToolsSection(
    SpeciesMetrics metrics,
    IconData specIcon,
    Color specAccent,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VetSectionHeader(
          title: 'Herramientas de $_selectedSpecies',
          subtitle:
              'Calculadoras zootécnicas, constantes fisiológicas, vademécum y registros',
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.35,
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
            Text('Constantes: $_selectedSpecies'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final v in metrics.vitals) ...[
              ListTile(
                dense: true,
                title: Text(
                  v.parameter,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: Text(
                  '${v.range} ${v.unit}',
                  style: const TextStyle(
                    color: VetColors.turquoise,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
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
              decoration: const InputDecoration(
                labelText: 'Pesaje promedio del lote (kg o g)',
              ),
            ),
            TextField(
              controller: mortCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Mortalidad del día (cabezas)',
              ),
            ),
            TextField(
              controller: consCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Consumo de alimento diario (kg)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
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

  // 3. MIS LOTES / HATOS (Resumen)
  Widget _buildBatchesSummarySection(SpeciesMetrics metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VetSectionHeader(
          title: 'Mis Lotes y Hatos',
          subtitle: 'Resumen de cabezas, etapa zootécnica y últimos registros',
        ),
        const SizedBox(height: 10),
        for (final b in metrics.batches) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: VetCard(
              padding: const EdgeInsets.all(14),
              radius: 16,
              child: Row(
                children: [
                  VetIconBox(
                    icon: _speciesVisual(_selectedSpecies).$1,
                    accent: VetColors.turquoise,
                    size: 42,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${b.headcount} animales · Etapa: ${b.stage} (${b.daysInStage} días)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: VetColors.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Último registro: ${b.lastRecordDate} (${b.lastRecordDetail})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: VetColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // 4. ALERTAS
  Widget _buildAlertsSection(SpeciesMetrics metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VetSectionHeader(
          title: 'Alertas y Tareas Críticas',
          subtitle:
              'Vacunas por vencer, resguardos farmacológicos y partos o servicios',
        ),
        const SizedBox(height: 10),
        for (final a in metrics.alerts) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: VetCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              radius: 16,
              child: Row(
                children: [
                  Icon(
                    a.type == 'withdrawal'
                        ? VetIcons.alertOctagon
                        : (a.type == 'birth' ? VetIcons.heart : VetIcons.bell),
                    color: a.type == 'withdrawal'
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
                          a.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          a.subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: VetColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (a.daysLeft <= 2
                                  ? VetColors.danger
                                  : VetColors.warning)
                              .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      a.daysLeft == 0 ? 'Hoy' : 'En ${a.daysLeft} d',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: a.daysLeft <= 2
                            ? VetColors.danger
                            : VetColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // 5. RECETAS Y CONTROL
  Widget _buildPrescriptionAndControlSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VetSectionHeader(
          title: 'Recetas y Control Oficial',
          subtitle:
              'Acceso directo a receta médica pecuaria simple y cuantificada',
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
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            'Protocolos quirúrgicos de campo, cesáreas y laparotomía',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    VetStatusBadge(
                      label: 'En desarrollo',
                      kind: VetBadgeKind.unverified,
                    ),
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
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            'Lagunas de oxidación, compostaje de mortalidad y biodigestores',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    VetStatusBadge(
                      label: 'En desarrollo',
                      kind: VetBadgeKind.unverified,
                    ),
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
                    color: indicatorPositive
                        ? VetColors.success
                        : VetColors.danger,
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

// Pintor de Curvas de Rendimiento Teórico vs Real
class _PerformanceCurvePainter extends CustomPainter {
  _PerformanceCurvePainter({
    required this.theoretical,
    required this.real,
    required this.accentColor,
  });

  final List<double> theoretical;
  final List<double> real;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (theoretical.isEmpty || real.isEmpty) return;

    final double minVal = [...theoretical, ...real].reduce(math.min);
    final double maxVal = [...theoretical, ...real].reduce(math.max);
    final double range = (maxVal - minVal) > 0 ? (maxVal - minVal) : 1.0;

    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.18)
      ..strokeWidth = 1;

    // Líneas horizontales de guía
    for (int i = 0; i <= 3; i++) {
      final y = size.height * (i / 3.0);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final theoryPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final realPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withValues(alpha: 0.25),
          accentColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final theoryPath = Path();
    final realPath = Path();
    final fillPath = Path();

    final stepX = size.width / (theoretical.length - 1);

    for (int i = 0; i < theoretical.length; i++) {
      final x = i * stepX;
      final yNorm = (theoretical[i] - minVal) / range;
      final y = size.height - (yNorm * (size.height - 20) + 10);
      if (i == 0) {
        theoryPath.moveTo(x, y);
      } else {
        theoryPath.lineTo(x, y);
      }
    }

    for (int i = 0; i < real.length; i++) {
      final x = i * stepX;
      final yNorm = (real[i] - minVal) / range;
      final y = size.height - (yNorm * (size.height - 20) + 10);
      if (i == 0) {
        realPath.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        realPath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
      // Dibujar punto
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = accentColor);
      canvas.drawCircle(Offset(x, y), 2.0, Paint()..color = Colors.white);
    }
    fillPath.lineTo((real.length - 1) * stepX, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(theoryPath, theoryPaint);
    canvas.drawPath(realPath, realPaint);
  }

  @override
  bool shouldRepaint(covariant _PerformanceCurvePainter oldDelegate) => true;
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: VetColors.muted),
                  maxLines: 1,
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
  State<ProductionCalculatorModal> createState() =>
      ProductionCalculatorModalState();
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
        _result =
            '${porAnimal.toStringAsFixed(2)} kg / animal / día\nTotal lote: ${totalDia.toStringAsFixed(1)} kg/día (${(totalDia / 1000).toStringAsFixed(2)} Ton)';
      } else if (widget.calcType == 'fca') {
        final alim = double.tryParse(paramCtrl1.text) ?? 1;
        final peso = double.tryParse(paramCtrl2.text) ?? 1;
        final fca = peso > 0 ? (alim / peso) : 0.0;
        _result =
            'FCA: ${fca.toStringAsFixed(2)} : 1\n(Se requieren ${fca.toStringAsFixed(2)} kg de alimento para producir 1 kg vivo)';
      } else if (widget.calcType == 'density') {
        final sup = double.tryParse(paramCtrl1.text) ?? 1;
        final anim = double.tryParse(paramCtrl2.text) ?? 1;
        final dens = sup > 0 ? (anim / sup) : 0.0;
        final m2PorAnimal = anim > 0 ? (sup / anim) : 0.0;
        _result =
            '${dens.toStringAsFixed(2)} animales / m²\nEspacio por animal: ${m2PorAnimal.toStringAsFixed(2)} m²/cabeza';
      } else if (widget.calcType == 'capacity') {
        final ancho = double.tryParse(paramCtrl1.text) ?? 1;
        final largo = double.tryParse(paramCtrl2.text) ?? 1;
        final dens = double.tryParse(paramCtrl3.text) ?? 1;
        final area = ancho * largo;
        final cap = area * dens;
        _result =
            'Área útil: ${area.toStringAsFixed(0)} m²\nCapacidad total recomendada: ${cap.toStringAsFixed(0)} animales';
      } else if (widget.calcType == 'semen') {
        final vol = double.tryParse(paramCtrl1.text) ?? 1;
        final conc = double.tryParse(paramCtrl2.text) ?? 1;
        final dosisReq = double.tryParse(paramCtrl3.text) ?? 1;
        final totalEsp = vol * conc; // millones
        final numDosis = dosisReq > 0 ? (totalEsp / dosisReq).floor() : 0;
        _result =
            'Total espermatozoides: ${totalEsp.toStringAsFixed(0)} M\nDosis seminales obtenibles: $numDosis dosis';
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
                decoration: const InputDecoration(
                  labelText: 'Número de animales en lote',
                ),
                onChanged: (_) => _calculate(),
              ),
              TextField(
                controller: paramCtrl1,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Peso promedio por animal (kg)',
                ),
                onChanged: (_) => _calculate(),
              ),
              TextField(
                controller: paramCtrl2,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '% de peso vivo a consumir (ej. 2.5 - 3.5%)',
                ),
                onChanged: (_) => _calculate(),
              ),
            ] else if (widget.calcType == 'fca') ...[
              TextField(
                controller: paramCtrl1,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Total alimento consumido en periodo (kg)',
                ),
                onChanged: (_) => _calculate(),
              ),
              TextField(
                controller: paramCtrl2,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Ganancia de peso total en periodo (kg)',
                ),
                onChanged: (_) => _calculate(),
              ),
            ] else if (widget.calcType == 'density') ...[
              TextField(
                controller: paramCtrl1,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Superficie de corral / nave (m²)',
                ),
                onChanged: (_) => _calculate(),
              ),
              TextField(
                controller: paramCtrl2,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Número de animales alojados',
                ),
                onChanged: (_) => _calculate(),
              ),
            ] else if (widget.calcType == 'capacity') ...[
              TextField(
                controller: paramCtrl1,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Ancho de la nave (m)',
                ),
                onChanged: (_) => _calculate(),
              ),
              TextField(
                controller: paramCtrl2,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Largo de la nave (m)',
                ),
                onChanged: (_) => _calculate(),
              ),
              TextField(
                controller: paramCtrl3,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Densidad meta (animales / m²)',
                ),
                onChanged: (_) => _calculate(),
              ),
            ] else if (widget.calcType == 'semen') ...[
              TextField(
                controller: paramCtrl1,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Volumen eyaculado (mL)',
                ),
                onChanged: (_) => _calculate(),
              ),
              TextField(
                controller: paramCtrl2,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Concentración (millones esp / mL)',
                ),
                onChanged: (_) => _calculate(),
              ),
              TextField(
                controller: paramCtrl3,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Concentración objetivo por dosis (millones)',
                ),
                onChanged: (_) => _calculate(),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VetColors.turquoise.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: VetColors.turquoise.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                _result,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
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
  final waterPctCtrl = TextEditingController(
    text: '10',
  ); // Concentración producto %

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
        _calcOutput =
            'Principio activo total: ${gActivoTotal.toStringAsFixed(1)} g\n'
            'Agregar de producto comercial ($concPct*100%):\n'
            '👉 ${gProducto.toStringAsFixed(1)} gramos (o ${(gProducto / 1000).toStringAsFixed(2)} kg) para los ${l.toStringAsFixed(0)} L';
      } else {
        final ton = double.tryParse(feedTonCtrl.text) ?? 1;
        final ppm = double.tryParse(feedPpmCtrl.text) ?? 1; // 1 ppm = 1 g/Ton
        final prePct = (double.tryParse(feedPrePctCtrl.text) ?? 1) / 100.0;
        final gActivoTotal = ton * ppm;
        final gPremezcla = prePct > 0 ? (gActivoTotal / prePct) : 0.0;
        _calcOutput =
            'Activo requerido: ${gActivoTotal.toStringAsFixed(0)} g\n'
            'Mezclar en planta por batch:\n'
            '👉 ${(gPremezcla / 1000).toStringAsFixed(2)} kg de premezcla para las ${ton.toStringAsFixed(1)} Ton';
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
                decoration: const InputDecoration(
                  labelText: 'Volumen tinaco / bebedero (Litros)',
                ),
                onChanged: (_) => _recalc(),
              ),
              TextField(
                controller: waterMgLCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Dosis meta en agua (mg / L o ppm)',
                ),
                onChanged: (_) => _recalc(),
              ),
              TextField(
                controller: waterPctCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Concentración producto comercial (%)',
                ),
                onChanged: (_) => _recalc(),
              ),
            ] else ...[
              TextField(
                controller: feedTonCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Toneladas de alimento a mezclar',
                ),
                onChanged: (_) => _recalc(),
              ),
              TextField(
                controller: feedPpmCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Concentración objetivo en alimento (ppm o g/Ton)',
                ),
                onChanged: (_) => _recalc(),
              ),
              TextField(
                controller: feedPrePctCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Concentración de la premezcla comercial (%)',
                ),
                onChanged: (_) => _recalc(),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VetColors.violet.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: VetColors.violet.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                _calcOutput,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
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
      (
        'Oxitetraciclina 200 LA',
        'Antimicrobiano amplio espectro',
        '28 días carne / 7 días leche',
        '20 mg/kg IM/SC',
      ),
      (
        'Tilmicosina 300 mg/mL',
        'Neumonías y complejo respiratorio',
        '28 días carne / Prohibido en leche humana',
        '10 mg/kg SC única',
      ),
      (
        'Florfenicol 300 mg/mL',
        'Respiratorio y pododermatitis',
        '28 - 38 días carne / No en lactancia',
        '20 mg/kg IM (48h) o 40 mg/kg SC',
      ),
      (
        'Ivermectina 1%',
        'Endectocida sistémico',
        '28 - 35 días carne / No en leche para consumo',
        '200 mcg/kg SC',
      ),
      (
        'Flunixin Meglumine 50mg',
        'Antiinflamatorio no esteroideo (AINE)',
        '4 días carne / 36 h leche',
        '1.1 - 2.2 mg/kg IV/IM',
      ),
      (
        'Tilosina Tartrato',
        'Disentería porcina, micoplasmosis',
        '5 - 7 días carne',
        '10 - 20 mg/kg agua',
      ),
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
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  cat,
                  style: const TextStyle(fontSize: 12, color: VetColors.muted),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: VetColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Retiro oficial: $retiro',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: VetColors.danger,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Dosis referencia: $dose',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
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
  State<PecuariaPrescriptionModal> createState() =>
      PecuariaPrescriptionModalState();
}

class PecuariaPrescriptionModalState extends State<PecuariaPrescriptionModal> {
  final uppCtrl = TextEditingController(text: 'UPP-04-129-882');
  final loteCtrl = TextEditingController(text: 'Lote Principal');
  final drugCtrl = TextEditingController(text: 'Oxitetraciclina 200 LA');
  final doseCtrl = TextEditingController(
    text: '20 mg/kg IM cada 48h por 3 dosis',
  );
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
              widget.quantified
                  ? 'Receta Médica Cuantificada'
                  : 'Receta Médica Simple',
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
                  Text(
                    'Médico: ${widget.mvzName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Granja / UPP: ${widget.clinicName}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: VetColors.muted,
                    ),
                  ),
                  Text(
                    'Especie destino: ${widget.species}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: VetColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: uppCtrl,
              decoration: const InputDecoration(
                labelText: 'Clave UPP / PSG oficial',
              ),
            ),
            TextField(
              controller: loteCtrl,
              decoration: const InputDecoration(
                labelText: 'Lote / Corral / Nave destino',
              ),
            ),
            TextField(
              controller: drugCtrl,
              decoration: const InputDecoration(
                labelText: 'Principio activo y concentración comercial',
              ),
            ),
            TextField(
              controller: doseCtrl,
              decoration: const InputDecoration(
                labelText: 'Pauta posológica e indicación terapéutica',
              ),
            ),
            TextField(
              controller: withdrawalCtrl,
              decoration: const InputDecoration(
                labelText: 'Tiempo de retiro obligatorio prescrito',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
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
