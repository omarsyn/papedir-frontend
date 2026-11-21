import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/onboarding_provider.dart';

class _PasoOnboarding {
  final IconData icono;
  final String titulo;
  final String descripcion;

  const _PasoOnboarding({
    required this.icono,
    required this.titulo,
    required this.descripcion,
  });
}

class OnboardingRepartidorScreen extends ConsumerStatefulWidget {
  final VoidCallback? onFinalizar;

  const OnboardingRepartidorScreen({super.key, this.onFinalizar});

  @override
  ConsumerState<OnboardingRepartidorScreen> createState() =>
      _OnboardingRepartidorScreenState();
}

class _OnboardingRepartidorScreenState
    extends ConsumerState<OnboardingRepartidorScreen> {
  final PageController _pageController = PageController();

  // Paleta exacta de las capturas de referencia
  static const Color _bgOscuro = Color(0xFF1C1513);
  static const Color _acentoDurazno = Color(0xFFF5B79E);
  static const Color _textoBoton = Color(0xFF2B1710);
  static const Color _textoSecundario = Color(0xFFD6CCC8);

  static const List<_PasoOnboarding> _pasos = [
    _PasoOnboarding(
      icono: Icons.two_wheeler_rounded,
      titulo: 'Tu ruta en PaPedir',
      descripcion:
          'Activa tu disponibilidad en el mapa y recibe pedidos de tiendas cercanas.',
    ),
    _PasoOnboarding(
      icono: Icons.inventory_2_outlined,
      titulo: 'Recoge y entrega a tiempo',
      descripcion:
          'Acepta el viaje, recoge el pedido en el local y sigue la ruta hasta el cliente.',
    ),
    _PasoOnboarding(
      icono: Icons.account_balance_wallet_outlined,
      titulo: 'Controla tu cartera',
      descripcion:
          'Consulta tu saldo y movimientos; liquida a tiempo para no alcanzar el límite.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _terminar() {
    ref.read(onboardingRepartidorProvider.notifier).completar();
    widget.onFinalizar?.call();
  }

  void _siguiente(int paginaActual) {
    if (paginaActual < _pasos.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _terminar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingRepartidorProvider);
    final paginaActual = onboardingState.paginaActual;
    final esUltimo = paginaActual == _pasos.length - 1;

    return Scaffold(
      backgroundColor: _bgOscuro,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              // Cabecera: Logo a la izquierda + "Saltar" a la derecha
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset(
                    'assets/images/Logo.png',
                    height: 36,
                    fit: BoxFit.contain,
                  ),
                  TextButton(
                    onPressed: _terminar,
                    child: const Text(
                      'Saltar',
                      style: TextStyle(
                        color: _acentoDurazno,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              // Carrusel de 3 pasos
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pasos.length,
                  onPageChanged: (index) => ref
                      .read(onboardingRepartidorProvider.notifier)
                      .cambiarPagina(index),
                  itemBuilder: (context, index) {
                    final paso = _pasos[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          paso.icono,
                          size: 88,
                          color: _acentoDurazno,
                        ),
                        const SizedBox(height: 28),
                        Text(
                          paso.titulo,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            paso.descripcion,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _textoSecundario,
                              fontSize: 15.5,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Indicador de puntos
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pasos.length, (index) {
                  final activo = index == paginaActual;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: activo ? 22 : 8,
                    decoration: BoxDecoration(
                      color: activo
                          ? _acentoDurazno
                          : Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Botón inferior ("Siguiente" / "Empezar")
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => _siguiente(paginaActual),
                  style: FilledButton.styleFrom(
                    backgroundColor: _acentoDurazno,
                    foregroundColor: _textoBoton,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    esUltimo ? 'Empezar' : 'Siguiente',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}