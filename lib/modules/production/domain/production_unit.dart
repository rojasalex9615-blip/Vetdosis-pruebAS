import 'production_catalog.dart';

/// Una unidad de produccion: el grupo con el que se trabaja a diario.
///
/// Se llama distinto segun la especie —hato, rebaño, parvada, lote, apiario,
/// camada— pero es la misma pieza: un conjunto de animales que se registra,
/// se cuenta y al que luego se le cuelgan los demas registros. Por eso hay un
/// solo modelo y no siete.
///
/// No clasifica ni evalua nada: guarda lo que el profesional escribe. El
/// numero de animales es un dato capturado, no un calculo ni una meta.
class ProductionUnit {
  const ProductionUnit({
    required this.id,
    required this.clinicId,
    required this.species,
    required this.activity,
    required this.name,
    required this.createdAt,
    this.headcount,
    this.notes,
    this.updatedAt,
  });

  /// Identificador propio de la unidad.
  final String id;

  /// Espacio de trabajo al que pertenece.
  final String clinicId;

  /// Especie, tal y como la nombra el catalogo de [productionSpecies].
  final String species;

  /// Actividad dentro de esa especie, del mismo catalogo.
  final String activity;

  /// Nombre que le pone el profesional: «Lote 3», «Caseta A», «Apiario norte».
  final String name;

  /// Cuantos animales declara el profesional. Nulo si no lo ha anotado.
  final int? headcount;

  /// Nota libre.
  final String? notes;

  /// Cuando se creo el registro.
  final DateTime createdAt;

  /// Ultima modificacion, si la hubo.
  final DateTime? updatedAt;

  /// Copia con los campos indicados cambiados.
  ProductionUnit copyWith({
    String? name,
    int? headcount,
    String? notes,
    DateTime? updatedAt,
    bool clearHeadcount = false,
    bool clearNotes = false,
  }) => ProductionUnit(
    id: id,
    clinicId: clinicId,
    species: species,
    activity: activity,
    name: name ?? this.name,
    headcount: clearHeadcount ? null : (headcount ?? this.headcount),
    notes: clearNotes ? null : (notes ?? this.notes),
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// La fila tal y como se guarda, con la cuenta dueña dentro.
  Map<String, Object?> toRow(String userId) => {
    'id': id,
    'userId': userId,
    'clinicId': clinicId,
    'species': species,
    'activity': activity,
    'name': name,
    'headcount': headcount,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  /// Reconstruye una unidad desde su fila, o null si la fila no es de fiar.
  ///
  /// Devuelve null, en vez de lanzar o de adivinar, cuando la fila es de otra
  /// cuenta, cuando le falta algo obligatorio o cuando la especie o la
  /// actividad no estan en el catalogo. Es a proposito: una fila manipulada o
  /// de una version futura se descarta en silencio en lugar de aparecer como
  /// un registro valido.
  static ProductionUnit? fromRow(Map<String, Object?> row, String userId) {
    if (row['userId'] != userId) return null;
    final id = row['id'];
    final clinicId = row['clinicId'];
    final species = row['species'];
    final activity = row['activity'];
    final name = row['name'];
    final createdAt = row['createdAt'];
    if (id is! String || id.isEmpty) return null;
    if (clinicId is! String || clinicId.isEmpty) return null;
    if (species is! String || activity is! String) return null;
    if (name is! String || name.trim().isEmpty) return null;
    if (createdAt is! String) return null;
    if (!isKnownProductionArea(species, activity)) return null;
    final creado = DateTime.tryParse(createdAt);
    if (creado == null) return null;
    final actualizado = row['updatedAt'];
    final headcount = row['headcount'];
    final notes = row['notes'];
    return ProductionUnit(
      id: id,
      clinicId: clinicId,
      species: species,
      activity: activity,
      name: name,
      headcount: headcount is int && headcount >= 0 ? headcount : null,
      notes: notes is String && notes.trim().isNotEmpty ? notes : null,
      createdAt: creado,
      updatedAt: actualizado is String ? DateTime.tryParse(actualizado) : null,
    );
  }
}

/// Si esa pareja de especie y actividad existe en el catalogo.
///
/// Se comprueba al guardar y al leer: asi un registro no puede quedar colgado
/// de una actividad que la app no ofrece.
bool isKnownProductionArea(String species, String activity) =>
    productionSpecies[species]?.contains(activity) ?? false;
