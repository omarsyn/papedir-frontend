import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/preferencias.dart';

/// Una página de la bienvenida.
class PaginaOnboarding {
  const PaginaOnboarding({
    required this.icono,
    required this.titulo,
    required this.texto,
  });

  final IconData icono;
  final String titulo;
  final String texto;
}

class _PaginaActual extends AutoDisposeNotifier<int> {
  @override
  int build() => 0;

  void ir(int pagina) {
    state = pagina;
  }
}

final _paginaActualProvider = NotifierProvider.autoDispose<_PaginaActual, int>(
  _PaginaActual.new,
);

final _controllerProvider = Provider.autoDispose<PageController>((ref) {
  final c = PageController();
  ref.onDispose(c.dispose);
  return c;
});

/// Bienvenida que se muestra solo la primera vez que se abre la app.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key, required this.paginas});

  final List<PaginaOnboarding> paginas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actual = ref.watch(_paginaActualProvider);
    final controller = ref.watch(_controllerProvider);
    final tema = Theme.of(context);
    final ultima = actual == paginas.length - 1;
    void terminar() => ref.read(onboardingVistoProvider.notifier).terminar();

    return Scaffold(
      body: SafeArea(
        child: Center(
          // En tabletas el contenido no se estira de más.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: terminar,
                    child: const Text('Saltar'),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: controller,
                    onPageChanged: ref
                        .read(_paginaActualProvider.notifier)
                        .ir,
                    children: [
                      for (final p in paginas)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                p.icono,
                                size: 96,
                                color: tema.colorScheme.primary,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                p.titulo,
                                style: tema.textTheme.headlineSmall,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(p.texto, textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < paginas.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.all(4),
                        width: i == actual ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == actual
                              ? tema.colorScheme.primary
                              : tema.colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: ultima
                          ? terminar
                          : () => controller.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            ),
                      child: Text(ultima ? 'Empezar' : 'Siguiente'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
