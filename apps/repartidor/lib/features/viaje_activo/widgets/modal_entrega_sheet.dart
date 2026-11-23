import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/biometria.dart';

/// Foto de evidencia elegida en el modal (se libera al cerrarlo).
final _fotoEntregaProvider = StateProvider.autoDispose<XFile?>((_) => null);

/// true mientras se confirma la entrega.
final _enviandoEntregaProvider = StateProvider.autoDispose<bool>((_) => false);

/// Controlador del código de 4 dígitos (se libera al cerrar el modal).
final _codigoEntregaProvider = Provider.autoDispose<TextEditingController>((
  ref,
) {
  final c = TextEditingController();
  ref.onDispose(c.dispose);
  return c;
});

final _formEntregaProvider = Provider.autoDispose<GlobalKey<FormState>>(
  (_) => GlobalKey<FormState>(),
);

class ModalEntregaSheet extends ConsumerWidget {
  final Pedido pedido;
  final Future<bool> Function(String codigo, String? fotoPath) onConfirmar;

  const ModalEntregaSheet({
    super.key,
    required this.pedido,
    required this.onConfirmar,
  });

  /// Efectivo a cobrar en el domicilio (0 si se pagó con tarjeta).
  double get _aCobrar => pedido.metodoPago == 'efectivo' ? pedido.total : 0;

  Future<void> _capturarFoto(WidgetRef ref, ImageSource source) async {
    final imagen = await ImagePicker().pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1280,
    );
    if (imagen != null) ref.read(_fotoEntregaProvider.notifier).state = imagen;
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    if (!ref.read(_formEntregaProvider).currentState!.validate()) return;

    // Sensor (ACUERDOS §13): huella, rostro o PIN del teléfono para
    // confirmar que es el repartidor quien cierra la entrega.
    final identificado = await ref
        .read(biometriaProvider)
        .confirmar('Confirma la entrega del pedido ${pedido.folio}');
    if (!identificado) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se confirmó tu identidad')),
        );
      }
      return;
    }

    ref.read(_enviandoEntregaProvider.notifier).state = true;
    final ok = await onConfirmar(
      ref.read(_codigoEntregaProvider).text,
      ref.read(_fotoEntregaProvider)?.path,
    );
    if (!context.mounted) return;
    ref.read(_enviandoEntregaProvider.notifier).state = false;
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final foto = ref.watch(_fotoEntregaProvider);
    final enviando = ref.watch(_enviandoEntregaProvider);
    final codigoCtrl = ref.watch(_codigoEntregaProvider);
    final esquema = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 24),
      child: Form(
        key: ref.watch(_formEntregaProvider),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Confirmar entrega · ${pedido.folio}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: esquema.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _aCobrar > 0
                            ? 'Cobrar en efectivo al cliente:'
                            : 'Pagado con tarjeta: no cobres nada',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: esquema.onSecondaryContainer,
                        ),
                      ),
                    ),
                    if (_aCobrar > 0)
                      Text(
                        '\$${_aCobrar.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: esquema.onSecondaryContainer,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: codigoCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Código de entrega (4 dígitos)',
                  hintText: '0000',
                ),
                validator: (v) {
                  if (v == null || v.trim().length != 4) {
                    return 'Solicita al cliente el código de 4 dígitos';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Foto de evidencia (opcional)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              if (foto != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(foto.path),
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: enviando
                              ? null
                              : () =>
                                    ref
                                            .read(_fotoEntregaProvider.notifier)
                                            .state =
                                        null,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: enviando
                            ? null
                            : () => _capturarFoto(ref, ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Tomar foto'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: enviando
                            ? null
                            : () => _capturarFoto(ref, ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Galería'),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: enviando ? null : () => _submit(context, ref),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: enviando
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fingerprint),
                label: Text(
                  enviando
                      ? 'Confirmando entrega...'
                      : 'Finalizar entrega con huella',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
