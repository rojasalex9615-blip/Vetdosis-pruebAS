import 'package:flutter/material.dart';
import '../../../core/widgets/workspace_panel.dart';
import '../../../vet_ui/vet_components.dart';
import '../../../vet_ui/vet_theme.dart';
import '../../auth/domain/clinic_membership.dart';
import '../domain/inventory_repository.dart';
import 'barcode_screen.dart';
import 'inventory_screen.dart';
import '../../../vet_ui/vet_icons.dart';

class QuickScanScreen extends StatefulWidget {
  const QuickScanScreen({
    super.key,
    required this.repository,
    required this.member,
    this.onOpenLabelScanner,
  });
  final InventoryRepository repository;
  final ClinicMembership member;

  /// Abre el lector de etiquetas para dosis. Si es nulo, quien entra no
  /// tiene ese acceso y la tarjeta no se muestra.
  final VoidCallback? onOpenLabelScanner;
  @override
  State<QuickScanScreen> createState() => _QuickScanScreenState();
}

class _QuickScanScreenState extends State<QuickScanScreen> {
  final code = TextEditingController();
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> scan() async {
    final value = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScreen()),
    );
    if (mounted && value != null) setState(() => code.text = value);
  }

  void search() {
    final value = code.text.trim();
    if (value.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Producto encontrado')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: InventoryScreen(
              repository: widget.repository,
              member: widget.member,
              initialSearch: value,
            ),
          ),
        ),
      ),
    );
  }

  /// Cabecera de cada lector: su placa de icono, el nombre y para que sirve.
  Widget heading(IconData icon, Color color, String title, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      VetIconBox(icon: icon, accent: color, size: 52),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  // Los dos lectores de la app en una sola pantalla, cada uno en su tarjeta:
  // antes este apartado solo ofrecia el de codigo de barras y el de
  // etiquetas quedaba unicamente en el boton flotante.
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Escáneres', style: Theme.of(context).textTheme.headlineSmall),
      const Text('Elige qué quieres leer con la cámara.'),
      const SizedBox(height: 16),
      VetCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading(
              VetIcons.qrScan,
              sectionAccent('Escanear producto'),
              'Escanear producto',
              'Busca por código de barras en tu inventario. El código no '
                  'verifica concentración ni dosis.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: scan,
              icon: const Icon(VetIcons.qrScan),
              label: const Text('Abrir cámara'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: code,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Código manual o escaneado',
                prefixIcon: Icon(VetIcons.barcode),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => search(),
            ),
            OutlinedButton.icon(
              onPressed: code.text.trim().isEmpty ? null : search,
              icon: const Icon(VetIcons.search),
              label: const Text('Buscar en inventario'),
            ),
          ],
        ),
      ),
      if (widget.onOpenLabelScanner != null) ...[
        const SizedBox(height: 20),
        VetCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading(
                VetIcons.documentScan,
                VetColors.violet,
                'Etiqueta para dosis',
                'Lee la etiqueta de un producto para preparar el cálculo. '
                    'Lo leído es un borrador: revísalo contra el envase '
                    'antes de usarlo.',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: widget.onOpenLabelScanner,
                icon: const Icon(VetIcons.documentScan),
                label: const Text('Abrir lector de etiquetas'),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}
