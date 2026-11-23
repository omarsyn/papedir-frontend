import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';

class RegistroFormState {
  final bool cargando;
  final bool aceptoTerminos;
  final bool ocultarPassword;
  final String? errorGeneral;
  final Map<String, String> erroresCampos;

  const RegistroFormState({
    this.cargando = false,
    this.aceptoTerminos = false,
    this.ocultarPassword = true,
    this.errorGeneral,
    this.erroresCampos = const {},
  });

  RegistroFormState copyWith({
    bool? cargando,
    bool? aceptoTerminos,
    bool? ocultarPassword,
    String? errorGeneral,
    Map<String, String>? erroresCampos,
  }) {
    return RegistroFormState(
      cargando: cargando ?? this.cargando,
      aceptoTerminos: aceptoTerminos ?? this.aceptoTerminos,
      ocultarPassword: ocultarPassword ?? this.ocultarPassword,
      errorGeneral: errorGeneral,
      erroresCampos: erroresCampos ?? this.erroresCampos,
    );
  }
}

final registroFormProvider =
    NotifierProvider.autoDispose<RegistroFormNotifier, RegistroFormState>(
  RegistroFormNotifier.new,
);

class RegistroFormNotifier extends AutoDisposeNotifier<RegistroFormState> {
  @override
  RegistroFormState build() => const RegistroFormState();

  void toggleTerminos(bool? value) {
    state = state.copyWith(aceptoTerminos: value ?? false);
  }

  void togglePassword() {
    state = state.copyWith(ocultarPassword: !state.ocultarPassword);
  }

  Future<bool> registrar({
    required String nombre,
    required String email,
    required String telefono,
    required String password,
  }) async {
    if (!state.aceptoTerminos) {
      state = state.copyWith(
        errorGeneral: 'Debes aceptar el aviso de privacidad y los términos.',
      );
      return false;
    }

    state = state.copyWith(
      cargando: true,
      errorGeneral: null,
      erroresCampos: {},
    );

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/auth/register',
        data: {
          'nombre': nombre.trim(),
          'email': email.trim(),
          'password': password,
          'telefono': telefono.trim(),
          'rol': 'repartidor',
          'aceptoTerminos': true,
        },
      );

      final data = response.data as Map<String, dynamic>;
      // Guardar tokens con flutter_secure_storage mediante el authProvider de core
      await ref.read(authProvider.notifier).guardarSesionDesdeRespuesta(data);

      state = state.copyWith(cargando: false);
      return true;
    } on DioException catch (e) {
      final resData = e.response?.data;
      final Map<String, String> campos = {};
      String mensaje = 'No se pudo completar el registro.';

      if (resData is Map<String, dynamic>) {
        mensaje = resData['message'] as String? ?? mensaje;
        final detalles = resData['detalles'] as List<dynamic>?;
        if (detalles != null) {
          for (final d in detalles) {
            if (d is Map<String, dynamic>) {
              final campo = d['campo'] as String?;
              final msg = d['mensaje'] as String?;
              if (campo != null && msg != null) campos[campo] = msg;
            }
          }
        }
      }

      state = state.copyWith(
        cargando: false,
        errorGeneral: mensaje,
        erroresCampos: campos,
      );
      return false;
    }
  }
}

class RegistroRepartidorScreen extends ConsumerStatefulWidget {
  const RegistroRepartidorScreen({super.key});

  @override
  ConsumerState<RegistroRepartidorScreen> createState() =>
      _RegistroRepartidorScreenState();
}

class _RegistroRepartidorScreenState
    extends ConsumerState<RegistroRepartidorScreen> {
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(registroFormProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Registro de repartidor')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Crea tu cuenta en PaPedir',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Tu cuenta quedará en revisión hasta que soporte apruebe tus datos y documentos.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nombreCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nombre completo',
                prefixIcon: const Icon(Icons.person_outline),
                border: const OutlineInputBorder(),
                errorText: formState.erroresCampos['nombre'],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: const Icon(Icons.email_outlined),
                border: const OutlineInputBorder(),
                errorText: formState.erroresCampos['email'],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _telefonoCtrl,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: InputDecoration(
                labelText: 'Teléfono (10 dígitos)',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: const OutlineInputBorder(),
                counterText: '',
                errorText: formState.erroresCampos['telefono'],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passwordCtrl,
              obscureText: formState.ocultarPassword,
              decoration: InputDecoration(
                labelText: 'Contraseña (mínimo 8 caracteres)',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                errorText: formState.erroresCampos['password'],
                suffixIcon: IconButton(
                  icon: Icon(
                    formState.ocultarPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      ref.read(registroFormProvider.notifier).togglePassword(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: formState.aceptoTerminos,
              onChanged: (v) =>
                  ref.read(registroFormProvider.notifier).toggleTerminos(v),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Acepto el Aviso de Privacidad y los Términos y Condiciones vigentes de PaPedir.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            if (formState.errorGeneral != null) ...[
              const SizedBox(height: 8),
              Text(
                formState.errorGeneral!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: formState.cargando
                  ? null
                  : () async {
                      final ok = await ref
                          .read(registroFormProvider.notifier)
                          .registrar(
                            nombre: _nombreCtrl.text,
                            email: _emailCtrl.text,
                            telefono: _telefonoCtrl.text,
                            password: _passwordCtrl.text,
                          );
                      if (ok && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
              child: formState.cargando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Crear cuenta de repartidor',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}