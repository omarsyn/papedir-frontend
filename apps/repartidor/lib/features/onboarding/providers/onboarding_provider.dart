import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingState {
  final int paginaActual;
  final bool completadoEnSesion;

  const OnboardingState({
    this.paginaActual = 0,
    this.completadoEnSesion = false,
  });

  OnboardingState copyWith({
    int? paginaActual,
    bool? completadoEnSesion,
  }) {
    return OnboardingState(
      paginaActual: paginaActual ?? this.paginaActual,
      completadoEnSesion: completadoEnSesion ?? this.completadoEnSesion,
    );
  }
}

final onboardingRepartidorProvider =
    NotifierProvider<OnboardingRepartidorNotifier, OnboardingState>(
  OnboardingRepartidorNotifier.new,
);

class OnboardingRepartidorNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    // Cada vez que cambia el usuario autenticado (login o logout), se reinicia
    ref.watch(authProvider.select((s) => s.usuario?.id));
    return const OnboardingState();
  }

  void cambiarPagina(int index) {
    state = state.copyWith(paginaActual: index);
  }

  void completar() {
    state = state.copyWith(completadoEnSesion: true);
  }
}