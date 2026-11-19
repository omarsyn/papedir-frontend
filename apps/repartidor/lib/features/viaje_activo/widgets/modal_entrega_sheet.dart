import 'dart:io';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class ModalEntregaSheet extends StatefulWidget {
  final Pedido pedido;
  final Future<bool> Function(String codigo, String? fotoPath) onConfirmar;

  const ModalEntregaSheet({
    super.key,
    required this.pedido,
    required this.onConfirmar,
  });

  @override
  State<ModalEntregaSheet> createState() => _ModalEntregaSheetState();
}

class _ModalEntregaSheetState extends State<ModalEntregaSheet> {
  final _formKey = GlobalKey<FormState>();
  final _codigoCtrl = TextEditingController();
  final _picker = ImagePicker();

  XFile? _fotoSeleccionada;
  bool _enviando = false;

  @override
  void dispose() {
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _capturarFoto(ImageSource source) async {
    final imagen = await _picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1280,
    );
    if (imagen != null && mounted) {
      setState(() => _fotoSeleccionada = imagen);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);

    final ok = await widget.onConfirmar(
      _codigoCtrl.text,
      _fotoSeleccionada?.path,
    );

    if (!mounted) return;
    setState(() => _enviando = false);

    if (ok) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Confirmar entrega · ${widget.pedido.folio}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Cobrar en efectivo al cliente:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '\$${widget.pedido.total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codigoCtrl,
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
                  border: OutlineInputBorder(),
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
              if (_fotoSeleccionada != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_fotoSeleccionada!.path),
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
                          onPressed: _enviando
                              ? null
                              : () => setState(() => _fotoSeleccionada = null),
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
                        onPressed: _enviando
                            ? null
                            : () => _capturarFoto(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Tomar foto'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _enviando
                            ? null
                            : () => _capturarFoto(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Galería'),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _enviando ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: _enviando
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _enviando ? 'Confirmando entrega...' : 'Finalizar entrega',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}