import 'package:core/core.dart' show Usuario, authProvider, dioProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/responsivo.dart';

/// Versión vigente de los términos y sus ligas (GET /legal, público).
final legalProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  final r = await ref.read(dioProvider).get<Map<String, dynamic>>('/legal');
  return r.data ?? const {};
});

final _aceptandoProvider = StateProvider.autoDispose<bool>((_) => false);

Future<void> _abrir(BuildContext context, Object? url) async {
  final uri = Uri.tryParse('${url ?? ''}');
  final ok =
      uri != null &&
      uri.hasScheme &&
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No se pudo abrir la liga')));
  }
}

/// Se muestra cuando `usuario.terminosPendientes` es true (hay una versión
/// nueva de los términos). Hasta aceptarlos no se entra a la app.
class TerminosPendientesScreen extends ConsumerWidget {
  const TerminosPendientesScreen({super.key});

  Future<void> _aceptar(BuildContext context, WidgetRef ref) async {
    ref.read(_aceptandoProvider.notifier).state = true;
    try {
      final legal = await ref.refresh(legalProvider.future);
      final r = await ref
          .read(dioProvider)
          .post<Map<String, dynamic>>(
            '/usuarios/me/terminos',
            data: {'version': legal['version']},
          );
      final data = r.data;
      if (data != null) {
        ref.read(authProvider.notifier).actualizarUsuario(Usuario.fromJson(data));
      } else {
        await ref.read(authProvider.notifier).checkSession();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
      }
    } finally {
      if (context.mounted) ref.read(_aceptandoProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aceptando = ref.watch(_aceptandoProvider);
    final legal = ref.watch(legalProvider).valueOrNull;
    final texto = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: AnchoMaximo(
          maxAncho: 520,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 32),
              Icon(
                Icons.policy_outlined,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Actualizamos nuestros términos',
                textAlign: TextAlign.center,
                style: texto.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'Para seguir repartiendo con PaPedir revisa y acepta la versión '
                'nueva de los Términos de uso y del Aviso de privacidad.',
                textAlign: TextAlign.center,
                style: texto.bodyLarge,
              ),
              if (legal?['version'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Versión ${legal!['version']}',
                  textAlign: TextAlign.center,
                  style: texto.bodySmall,
                ),
              ],
              const SizedBox(height: 24),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: const Text('Términos de uso'),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: legal == null
                          ? null
                          : () => _abrir(context, legal['terminosUrl']),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('Aviso de privacidad'),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: legal == null
                          ? null
                          : () => _abrir(context, legal['avisoPrivacidadUrl']),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: aceptando ? null : () => _aceptar(context, ref),
                child: aceptando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Acepto'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: aceptando
                    ? null
                    : () => ref.read(authProvider.notifier).logout(),
                child: const Text('No acepto (cerrar sesión)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
