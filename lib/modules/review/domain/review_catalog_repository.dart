class ReviewCatalogItem {
  const ReviewCatalogItem({
    required this.key,
    required this.version,
    required this.title,
    required this.laboratory,
    required this.status,
    required this.snapshot,
    this.globalStatus = 'sin_verificar',
    this.personalStatus = 'sin_verificar',
    this.ingredient,
    this.presentation,
    this.source,
    this.page,
    this.doseText,
  });

  final String key;
  final String version;
  final String title;
  final String laboratory;
  final String status;
  final String globalStatus;
  final String personalStatus;
  final String? ingredient;
  final String? presentation;
  final String? source;
  final int? page;
  final String? doseText;
  final Map<String, dynamic> snapshot;

  factory ReviewCatalogItem.read(Map<String, dynamic> row) {
    final snapshot = Map<String, dynamic>.from(row['snapshot'] as Map);
    return ReviewCatalogItem(
      key: row['source_key'] as String,
      version: row['catalog_version'] as String,
      title: row['title'] as String,
      laboratory: row['laboratory'] as String? ?? '',
      status: row['clinic_review_status'] as String? ??
          row['review_status'] as String? ??
          'sin_verificar',
      globalStatus: row['global_review_status'] as String? ?? 'sin_verificar',
      personalStatus: row['personal_review_status'] as String? ?? 'sin_verificar',
      ingredient: row['active_ingredients'] as String?,
      presentation: row['presentation'] as String?,
      source: row['source_document'] as String?,
      page: row['source_page'] as int?,
      doseText: row['catalog_dose_text'] as String?,
      snapshot: snapshot,
    );
  }
}

abstract interface class ReviewCatalogRepository {
  Future<List<ReviewCatalogItem>> list(
    String clinic,
    String search,
    int offset, {
    String source = 'inventario_comercial',
  });
  Future<Map<String, dynamic>> progress(
    String clinic, {
    String source = 'inventario_comercial',
  });
  Future<bool> isPlatformOwner();
  Future<void> setGlobalStatus(String sourceKey, String status);
  Future<void> setClinicStatus(String clinic, String sourceKey, String status);
  Future<void> setPersonalStatus(String sourceKey, String status);
  Future<void> report({
    required String clinic,
    required String reviewer,
    required ReviewCatalogItem item,
    required String comment,
    String? expected,
    String? source,
  });
}
