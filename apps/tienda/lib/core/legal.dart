import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'providers.dart';

/// Versión vigente de los términos y ligas (GET /legal, público).
class InfoLegal {
  const InfoLegal({
    required this.version,
    required this.terminosUrl,
    required this.privacidadUrl,
  });

  final String version;
  final String terminosUrl;
  final String privacidadUrl;

  factory InfoLegal.fromJson(Map<String, dynamic> j) => InfoLegal(
    version: '${j['version'] ?? ''}',
    terminosUrl: '${j['terminosUrl'] ?? ''}',
    privacidadUrl: '${j['avisoPrivacidadUrl'] ?? ''}',
  );
}

final legalProvider = FutureProvider<InfoLegal>((ref) async {
  final r = await ref.read(dioProvider).get<Map<String, dynamic>>('/legal');
  return InfoLegal.fromJson(r.data ?? const {});
});

Future<void> abrirLiga(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  final ok =
      uri != null &&
      url.isNotEmpty &&
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No se pudo abrir la liga')));
  }
}

/// "Acepto los Términos de uso y el Aviso de privacidad", con ligas.
class TextoLegal extends ConsumerWidget {
  const TextoLegal({super.key, this.prefijo = 'Acepto los '});

  final String prefijo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final legal = ref.watch(legalProvider).valueOrNull;
    final estilo = Theme.of(context).textTheme.bodyMedium;
    final color = Theme.of(context).colorScheme.primary;

    Widget liga(String texto, String? url) => GestureDetector(
      onTap: url == null ? null : () => abrirLiga(context, url),
      child: Text(
        texto,
        style: estilo?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: color,
        ),
      ),
    );

    return Text.rich(
      TextSpan(
        style: estilo,
        children: [
          TextSpan(text: prefijo),
          WidgetSpan(child: liga('Términos de uso', legal?.terminosUrl)),
          const TextSpan(text: ' y el '),
          WidgetSpan(child: liga('Aviso de privacidad', legal?.privacidadUrl)),
        ],
      ),
    );
  }
}
