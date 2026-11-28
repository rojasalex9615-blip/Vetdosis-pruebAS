import 'package:flutter/services.dart';
import '../domain/pullet_guide.dart';

class PulletGuideRepository {
  Future<PulletGuideCatalog> load() async => PulletGuideCatalog.parse(
    await rootBundle.loadString(
      'assets/clinical/aviculture/guia_linea.v1.json',
    ),
  );
}
