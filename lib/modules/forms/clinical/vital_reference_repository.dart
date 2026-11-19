import 'package:flutter/services.dart';

import 'vital_reference_catalog.dart';

/// Carga el catálogo de referencias de constantes desde el paquete.
///
/// Es solo lectura y de consulta: alimenta el indicador en vivo de la pantalla
/// de constantes. No decide qué se guarda; eso lo sigue haciendo el catálogo
/// con [VitalReferenceCatalog.snapshotFor], que solo usa entradas verificadas.
abstract interface class VitalReferenceRepository {
  Future<VitalReferenceCatalog> load();
}

class AssetVitalReferenceRepository implements VitalReferenceRepository {
  const AssetVitalReferenceRepository();

  static const _asset = 'assets/clinical/vital_references.v1.json';

  @override
  Future<VitalReferenceCatalog> load() async =>
      VitalReferenceCatalog.parse(await rootBundle.loadString(_asset));
}
