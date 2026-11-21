import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Se reemplaza en main() con la instancia ya cargada.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'Falta sobreescribir sharedPreferencesProvider en main()',
  ),
);

/// Tema elegido (claro, oscuro o el del teléfono). Se guarda en el dispositivo.
class TemaNotifier extends Notifier<ThemeMode> {
  static const _clave = 'tema';

  @override
  ThemeMode build() {
    final guardado = ref.watch(sharedPreferencesProvider).getString(_clave);
    return ThemeMode.values.firstWhere(
      (m) => m.name == guardado,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> cambiar(ThemeMode modo) async {
    state = modo;
    await ref.read(sharedPreferencesProvider).setString(_clave, modo.name);
  }
}

final temaProvider = NotifierProvider<TemaNotifier, ThemeMode>(
  TemaNotifier.new,
);

String etiquetaTema(ThemeMode m) => switch (m) {
  ThemeMode.light => 'Claro',
  ThemeMode.dark => 'Oscuro',
  ThemeMode.system => 'Igual que el teléfono',
};

/// true cuando el usuario ya vio la bienvenida.
class OnboardingNotifier extends Notifier<bool> {
  static const _clave = 'onboarding_visto';

  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(_clave) ?? false;

  Future<void> terminar() async {
    state = true;
    await ref.read(sharedPreferencesProvider).setBool(_clave, true);
  }
}

final onboardingVistoProvider = NotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);

/// Diálogo para elegir el tema desde la pantalla de cuenta.
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
