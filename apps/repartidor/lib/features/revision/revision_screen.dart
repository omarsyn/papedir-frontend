import 'package:core/core.dart' show authProvider, dioProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsivo.dart';
import '../documentos/documentos_screen.dart';

/// Motivo por el que soporte regresó la solicitud (`motivoRechazo` de
/// GET /auth/me). null si solo está esperando revisión.
final motivoRechazoProvider = FutureProvider.autoDispose<String?>((ref) async {
  final r = await ref
      .read(dioProvider)
      .get<Map<String, dynamic>>('/auth/me');
  final m = r.data?['motivoRechazo'];
  return m is String && m.trim().isNotEmpty ? m : null;
});

/// "Tu cuenta está en revisión": muestra qué debe corregir (si soporte la
/// regresó) y deja subir los documentos que faltan.
class RevisionScreen extends ConsumerWidget {
  const RevisionScreen({super.key});

  Future<void> _revisarDeNuevo(WidgetRef ref) async {
    ref.invalidate(motivoRechazoProvider);
    ref.invalidate(documentosProvider);
    // Si ya la aprobaron, el router lleva solo al mapa.
    await ref.read(authProvider.notifier).checkSession();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motivo = ref.watch(motivoRechazoProvider).valueOrNull;
    final esquema = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuenta en revisión'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: AnchoMaximo(
        child: RefreshIndicator(
          onRefresh: () => _revisarDeNuevo(ref),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Icon(
                motivo == null ? Icons.hourglass_top : Icons.edit_note,
                size: 64,
                color: motivo == null ? esquema.primary : esquema.error,
              ),
              const SizedBox(height: 12),
              Text(
                motivo == null
                    ? 'Estamos revisando tu solicitud'
                    : 'Tu solicitud necesita cambios',
                textAlign: TextAlign.center,
                style: texto.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                motivo == null
                    ? 'Soporte revisa tus datos y documentos. Te avisaremos '
                          'con una notificación cuando tu cuenta esté aprobada.'
                    : 'Corrige lo que te pide soporte y vuelve a enviar tus '
                          'documentos.',
                textAlign: TextAlign.center,
              ),
              if (motivo != null) ...[
                const SizedBox(height: 16),
                Card(
                  color: esquema.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: esquema.onErrorContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            motivo,
                            style: TextStyle(color: esquema.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text('Tus documentos', style: texto.titleMedium),
              const SizedBox(height: 8),
              const ListaDocumentos(),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _revisarDeNuevo(ref),
                icon: const Icon(Icons.refresh),
                label: const Text('Revisar estado de mi cuenta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
