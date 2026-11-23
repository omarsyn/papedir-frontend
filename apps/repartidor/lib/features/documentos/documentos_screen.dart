import 'package:core/core.dart' show dioProvider;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/responsivo.dart';

/// Un documento que pide el rol (GET /documentos) y su estado.
class DocumentoRequerido {
  const DocumentoRequerido({
    required this.tipo,
    required this.nombre,
    required this.requerido,
    this.estado,
    this.motivo,
  });

  final String tipo;
  final String nombre;
  final bool requerido;

  /// pendiente | aprobado | rechazado | null (aún no lo sube).
  final String? estado;
  final String? motivo;

  factory DocumentoRequerido.fromJson(Map<String, dynamic> j) {
    final doc = j['documento'];
    final d = doc is Map ? doc : const {};
    return DocumentoRequerido(
      tipo: '${j['tipo']}',
      nombre: '${j['nombre'] ?? j['tipo']}',
      requerido: j['requerido'] == true,
      estado: d['estado'] as String?,
      motivo: d['motivo'] as String?,
    );
  }
}

/// Lista de documentos del repartidor (INE, licencia...). Admin los edita en
/// la web, así que la lista no está fija en la app.
final documentosProvider =
    FutureProvider.autoDispose<List<DocumentoRequerido>>((ref) async {
      final r = await ref.read(dioProvider).get<List<dynamic>>('/documentos');
      return [
        for (final e in r.data ?? const [])
          if (e is Map)
            DocumentoRequerido.fromJson(Map<String, dynamic>.from(e)),
      ];
    });

/// Tipo de documento que se está subiendo (null = ninguno).
final _subiendoProvider = StateProvider.autoDispose<String?>((_) => null);

/// POST /documentos (multipart: archivo + tipo). JPG/PNG de hasta 5 MB.
Future<void> subirDocumento(
  BuildContext context,
  WidgetRef ref,
  DocumentoRequerido doc,
) async {
  final fuente = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Elegir de la galería'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (fuente == null) return;
  final foto = await ImagePicker().pickImage(
    source: fuente,
    imageQuality: 80,
    maxWidth: 1600,
  );
  if (foto == null) return;

  ref.read(_subiendoProvider.notifier).state = doc.tipo;
  try {
    await ref
        .read(dioProvider)
        .post<void>(
          '/documentos',
          data: FormData.fromMap({
            'tipo': doc.tipo,
            'archivo': await MultipartFile.fromFile(
              foto.path,
              filename: '${doc.tipo}.jpg',
            ),
          }),
        );
    if (context.mounted) {
      ref.invalidate(documentosProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${doc.nombre} enviado. Soporte lo revisará.')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    }
  } finally {
    if (context.mounted) ref.read(_subiendoProvider.notifier).state = null;
  }
}

/// Lista de documentos con su estado y botón para subir o reemplazar.
/// Se usa en la pantalla de revisión y en "Mis documentos".
class ListaDocumentos extends ConsumerWidget {
  const ListaDocumentos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(documentosProvider);
    final subiendo = ref.watch(_subiendoProvider);
    return docs.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => ListTile(
        leading: const Icon(Icons.error_outline),
        title: const Text('No se pudieron cargar tus documentos'),
        subtitle: Text(mensajeDeError(e)),
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(documentosProvider),
        ),
      ),
      data: (lista) => Column(
        children: [
          for (final d in lista)
            Card(
              child: ListTile(
                leading: _IconoEstado(estado: d.estado),
                title: Text(d.requerido ? '${d.nombre} *' : d.nombre),
                subtitle: Text(_textoEstado(d)),
                trailing: subiendo == d.tipo
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : d.estado == 'aprobado'
                    ? null
                    : TextButton(
                        onPressed: subiendo != null
                            ? null
                            : () => subirDocumento(context, ref, d),
                        child: Text(d.estado == null ? 'Subir' : 'Cambiar'),
                      ),
              ),
            ),
          if (lista.any((d) => d.requerido))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '* Obligatorio para aprobar tu cuenta',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  static String _textoEstado(DocumentoRequerido d) => switch (d.estado) {
    'aprobado' => 'Aprobado',
    'pendiente' => 'En revisión',
    'rechazado' =>
      'Rechazado${d.motivo == null ? '' : ': ${d.motivo}'} · vuelve a subirlo',
    _ => 'Falta subirlo',
  };
}

class _IconoEstado extends StatelessWidget {
  const _IconoEstado({required this.estado});

  final String? estado;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return switch (estado) {
      'aprobado' => const Icon(Icons.verified, color: Colors.green),
      'pendiente' => const Icon(Icons.hourglass_top, color: Colors.orange),
      'rechazado' => Icon(Icons.cancel, color: esquema.error),
      _ => Icon(Icons.upload_file, color: esquema.primary),
    };
  }
}

/// "Mis documentos" desde el perfil.
class DocumentosScreen extends ConsumerWidget {
  const DocumentosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis documentos')),
      body: AnchoMaximo(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(documentosProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              Text(
                'Sube una foto clara de cada documento. Soporte los revisa '
                'para aprobar tu cuenta.',
              ),
              SizedBox(height: 12),
              ListaDocumentos(),
            ],
          ),
        ),
      ),
    );
  }
}
