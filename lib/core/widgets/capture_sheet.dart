/// El marco que comparten los formularios de captura de los módulos.
///
/// Nació en exóticos y lo reusa producción. Centraliza lo aburrido y fácil de
/// hacer mal: el estado ocupado, el mensaje de error, que no se pueda pulsar
/// guardar dos veces y que el teclado no tape el botón.
///
/// La pieza clave es el `operation`: el recibo de idempotencia del proyecto. Se
/// genera **una vez** por formulario y sobrevive a los reintentos, de modo que
/// si el guardado falla por red y la persona vuelve a pulsar, el servidor
/// reconoce la misma operación y devuelve el registro que ya creó en lugar de
/// duplicarlo. Si se regenerara en cada pulsación, dos intentos seguidos tras
/// un error de red crearían dos registros.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../vet_ui/vet_components.dart';
import '../../vet_ui/vet_icons.dart';

/// Resultado de abrir un formulario: `true` si se guardó algo.
typedef CaptureSaved = bool;

/// Genera el identificador de operación que exige `private.vet_receipt`.
///
/// Son 24 bytes en hexadecimal, es decir 48 caracteres que cumplen
/// `^[a-f0-9]{48}$`. Cualquier otro formato lo rechaza el servidor con
/// `invalid_operation`. Mismo formato que `newOperationId` del módulo de
/// pacientes; se repite aquí para que `core` no dependa de un módulo.
String captureOperationId() {
  final r = Random.secure();
  return List.generate(
    24,
    (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// Hoja inferior con cabecera, campos, error y botón de guardar.
class CaptureSheet extends StatefulWidget {
  const CaptureSheet({
    super.key,
    required this.title,
    required this.icon,
    required this.fields,
    required this.onSave,
    required this.translateError,
    this.saveLabel = 'Guardar',
    this.notice,
  });

  final String title;
  final IconData icon;

  /// Los campos propios del formulario. Reciben si está ocupado para poder
  /// deshabilitarse durante el guardado.
  final List<Widget> Function(bool busy) fields;

  /// Devuelve el id creado. El `operation` se le pasa para que el reintento
  /// no duplique.
  final Future<String> Function(String operation) onSave;

  /// Convierte el error crudo en una frase para quien captura. Cada módulo
  /// trae el suyo porque los códigos de sus RPC son distintos.
  final String Function(Object error) translateError;

  final String saveLabel;

  /// Nota fija bajo el título, para advertencias de permiso o de alcance.
  final String? notice;

  @override
  State<CaptureSheet> createState() => _CaptureSheetState();
}

class _CaptureSheetState extends State<CaptureSheet> {
  final _form = GlobalKey<FormState>();
  final String _operation = captureOperationId();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSave(_operation);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = widget.translateError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      // El teclado no debe tapar el boton de guardar.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              Row(
                children: [
                  VetIconBox(icon: widget.icon),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.title, style: theme.textTheme.titleMedium),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed:
                        _busy ? null : () => Navigator.of(context).pop(false),
                    icon: const Icon(VetIcons.close),
                  ),
                ],
              ),
              if (widget.notice != null) ...[
                const SizedBox(height: 12),
                VetNotice(text: widget.notice!, kind: VetBadgeKind.information),
              ],
              const SizedBox(height: 16),
              ...widget.fields(_busy),
              if (_error != null) ...[
                const SizedBox(height: 16),
                VetNotice(
                  text: _error!,
                  icon: VetIcons.alertTriangle,
                  kind: VetBadgeKind.danger,
                ),
              ],
              const SizedBox(height: 20),
              VetActionButton(
                label: widget.saveLabel,
                icon: VetIcons.save,
                loading: _busy,
                onPressed: _busy ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Abre un formulario como hoja inferior y dice si se guardó algo.
Future<CaptureSaved> openCaptureSheet(BuildContext context, Widget sheet) async {
  final guardado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => sheet,
  );
  return guardado ?? false;
}

/// Lo que se enseña cuando el formulario no se puede abrir todavía.
///
/// No es un error ni un formulario vacío: es que falta un paso anterior. Se
/// dice cuál, en lugar de dejar un desplegable sin opciones.
class MissingPrerequisiteSheet extends StatelessWidget {
  const MissingPrerequisiteSheet({
    super.key,
    required this.title,
    required this.icon,
    required this.text,
  });
  final String title;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              VetIconBox(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          VetNotice(
            text: text,
            icon: VetIcons.info,
            kind: VetBadgeKind.information,
          ),
          const SizedBox(height: 20),
          VetActionButton(
            label: 'Entendido',
            style: VetActionStyle.secondary,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Piezas de campo reutilizables
// ---------------------------------------------------------------------------

/// Lee un número aceptando coma decimal. Devuelve `null` si no es un número.
///
/// En México se teclea «36,5» tanto como «36.5»; rechazar la coma sería
/// pelearse con la costumbre de quien captura.
double? readDecimal(String? texto) {
  final t = (texto ?? '').trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

/// Texto vacío a nulo, para no guardar cadenas en blanco.
String? emptyToNull(String texto) {
  final t = texto.trim();
  return t.isEmpty ? null : t;
}

/// Campo numérico opcional con coma o punto.
class CaptureNumberField extends StatelessWidget {
  const CaptureNumberField({
    super.key,
    required this.controller,
    required this.label,
    required this.busy,
    this.suffix,
    this.help,
    this.extraValidator,
  });

  final TextEditingController controller;
  final String label;
  final bool busy;
  final String? suffix;
  final String? help;

  /// Validación adicional sobre el número ya leído. Se usa para los rangos
  /// del catálogo de métricas.
  final String? Function(double value)? extraValidator;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      enabled: !busy,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]'))],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        helperText: help,
        helperMaxLines: 3,
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        final t = (v ?? '').trim();
        if (t.isEmpty) return null;
        final n = readDecimal(t);
        if (n == null) return 'Número no válido';
        return extraValidator?.call(n);
      },
    ),
  );
}

/// Campo de texto con validación de obligatorio opcional.
class CaptureTextField extends StatelessWidget {
  const CaptureTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.busy,
    this.required = false,
    this.lines = 1,
    this.maxLength,
    this.help,
  });

  final TextEditingController controller;
  final String label;
  final bool busy, required;
  final int lines;
  final int? maxLength;
  final String? help;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      enabled: !busy,
      maxLines: lines,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        helperText: help,
        helperMaxLines: 3,
        border: const OutlineInputBorder(),
      ),
      validator: !required
          ? null
          : (v) => (v ?? '').trim().isEmpty ? 'Hace falta este dato' : null,
    ),
  );
}

/// Campo entero con rango.
class CaptureIntField extends StatelessWidget {
  const CaptureIntField({
    super.key,
    required this.controller,
    required this.label,
    required this.busy,
    this.required = false,
    this.min,
    this.max,
    this.help,
  });

  final TextEditingController controller;
  final String label;
  final bool busy, required;
  final int? min, max;
  final String? help;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      enabled: !busy,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        helperText: help,
        helperMaxLines: 3,
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        final t = (v ?? '').trim();
        if (t.isEmpty) return required ? 'Hace falta este dato' : null;
        final n = int.tryParse(t);
        if (n == null) return 'Número no válido';
        if (min != null && n < min!) return 'Mínimo $min';
        if (max != null && n > max!) return 'Máximo $max';
        return null;
      },
    ),
  );
}

/// Selector de fecha. Nunca deja elegir futuro cuando [pastOnly].
class CaptureDateField extends StatelessWidget {
  const CaptureDateField({
    super.key,
    required this.value,
    required this.label,
    required this.busy,
    required this.onChanged,
    this.pastOnly = true,
    this.required = false,
  });

  final DateTime? value;
  final String label;
  final bool busy, pastOnly, required;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final texto = value == null
        ? 'Sin definir'
        : '${value!.day.toString().padLeft(2, '0')}/'
              '${value!.month.toString().padLeft(2, '0')}/${value!.year}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          border: const OutlineInputBorder(),
        ),
        child: Row(
          children: [
            Expanded(child: Text(texto)),
            if (value != null && !required)
              IconButton(
                tooltip: 'Quitar fecha',
                onPressed: busy ? null : () => onChanged(null),
                icon: const Icon(VetIcons.close, size: 18),
              ),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      final elegida = await showDatePicker(
                        context: context,
                        initialDate: value ?? hoy,
                        firstDate: DateTime(hoy.year - 30),
                        lastDate: pastOnly ? hoy : DateTime(hoy.year + 5),
                      );
                      if (elegida != null) onChanged(elegida);
                    },
              child: const Text('Elegir'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Desplegable de opciones con etiqueta legible.
class CaptureChoiceField<T> extends StatelessWidget {
  const CaptureChoiceField({
    super.key,
    required this.value,
    required this.label,
    required this.options,
    required this.nameOf,
    required this.busy,
    required this.onChanged,
    this.help,
  });

  final T? value;
  final String label;
  final List<T> options;
  final String Function(T) nameOf;
  final bool busy;
  final ValueChanged<T?> onChanged;
  final String? help;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: '$label *',
        helperText: help,
        helperMaxLines: 3,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final o in options)
          DropdownMenuItem(
            value: o,
            child: Text(nameOf(o), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: busy ? null : onChanged,
      validator: (v) => v == null ? 'Elige una opción' : null,
    ),
  );
}

/// Encabezado pequeño para separar bloques dentro de un formulario largo.
Widget captureBlockLabel(BuildContext context, String texto) => Padding(
  padding: const EdgeInsets.only(top: 4, bottom: 10),
  child: Text(
    texto,
    style: Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  ),
);
