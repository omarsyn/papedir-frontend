import 'package:core/core.dart' show guardarPreferenciasRemotas;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tema elegido (claro, oscuro o el del teléfono). Se guarda en Firestore
/// (`usuarios/{uid}.tema`, ACUERDOS §13) y se sincroniza entre teléfonos.
class TemaNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  Future<void> cambiar(ThemeMode modo, {bool remoto = true}) async {
    state = modo;
    if (remoto) await guardarPreferenciasRemotas({'tema': _aRemoto[modo]});
  }

  /// Valor que llegó de Firestore: se aplica sin volver a guardarlo.
  void aplicarRemoto(String? valor) {
    final modo = _deRemoto[valor];
    if (modo != null && modo != state) state = modo;
  }

  static const _aRemoto = {
    ThemeMode.system: 'sistema',
    ThemeMode.light: 'claro',
    ThemeMode.dark: 'oscuro',
  };
  static const _deRemoto = {
    'sistema': ThemeMode.system,
    'claro': ThemeMode.light,
    'oscuro': ThemeMode.dark,
  };
}

final temaProvider = NotifierProvider<TemaNotifier, ThemeMode>(
  TemaNotifier.new,
);

String etiquetaTema(ThemeMode m) => switch (m) {
  ThemeMode.light => 'Claro',
  ThemeMode.dark => 'Oscuro',
  ThemeMode.system => 'Igual que el teléfono',
};

/// Diálogo para elegir el tema desde el perfil.
Future<void> elegirTema(BuildContext context, WidgetRef ref) async {
  final actual = ref.read(temaProvider);
  final modo = await showDialog<ThemeMode>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Tema'),
      children: [
        for (final m in ThemeMode.values)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, m),
            child: Row(
              children: [
                Icon(
                  m == actual
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                const SizedBox(width: 12),
                Text(etiquetaTema(m)),
              ],
            ),
          ),
      ],
    ),
  );
  if (modo != null) await ref.read(temaProvider.notifier).cambiar(modo);
}

/// Temas de Cloud Messaging de esta app (ACUERDOS §13): `novedades` (todas
/// las apps) y `repartidores` (avisos de lluvia, alta demanda...). Se envían
/// desde la consola de Firebase.
Future<void> suscribirTemasRepartidor() async {
  final fcm = FirebaseMessaging.instance;
  for (final t in const ['novedades', 'repartidores']) {
    try {
      await fcm.subscribeToTopic(t);
    } catch (_) {
      // Sin Google Play Services o sin red: se reintenta en el próximo login.
    }
  }
}
