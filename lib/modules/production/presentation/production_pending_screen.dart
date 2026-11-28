import 'package:flutter/material.dart';
import '../../../vet_ui/vet_components.dart';

class ProductionPendingScreen extends StatelessWidget {
  const ProductionPendingScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Estado y pendientes de Producción')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const VetNotice(
          text:
              'Estado de las funciones de esta versión del código. El acceso a datos compartidos depende de la cuenta, permisos y servicios habilitados.',
        ),
        for (final row in const [
          (
            'Bovinos',
            'Lotes, métricas, eventos, alimento y gestaciones disponibles. Pendiente: genealogía con progenitores y referencias nutricionales por etapa validadas.',
          ),
          (
            'Ovinos / caprinos',
            'Lotes, métricas, eventos, gestaciones y cálculos de crecimiento, densidad y capacidad con entradas propias. Pendiente: genealogía y recomendaciones de alimentación validadas.',
          ),
          (
            'Aves',
            'Crianza, guías, capacidad, índices e incubación. Granjas/casetas/sanidad compartidas requieren habilitar su migración. Pendiente de validar: presión de agua, temperatura por edad y algunas fichas de equipos.',
          ),
          (
            'Porcinos',
            'Calculadoras por etapa y referencias de clase, planes y bioseguridad según servicio. Pendiente: validación externa de referencias y constante de conteo seminal.',
          ),
          (
            'Peces',
            'Herramientas por especie con datos publicados y avisos donde faltan. Pendiente: tablas de ración de bagre, siembra de cachama/bagre y parámetros de temperatura/oxígeno sin referencia validada.',
          ),
          (
            'Abejas',
            'Apiarios, cosecha y eventos en registros; rendimiento por colmena y día con datos propios. Pendiente: protocolos sanitarios validados, trazabilidad por colmena individual y calendario específico de floraciones.',
          ),
          (
            'Equinos',
            'Pacientes, gestaciones y evaluación seminal. Pendiente: planes nutricionales por etapa, genealogía y módulos de clínica avanzada con fuentes validadas.',
          ),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: VetCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(row.$1, style: Theme.of(context).textTheme.titleLarge),
                  Text(row.$2),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
