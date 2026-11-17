import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:gym_tracker/core/theme/app_colors.dart';

/// In-app, readable viewer for the FULL published plain-text/Markdown
/// document. This never loads a draft or treats a failed load as acceptance.
class StkLegalDocumentPage extends StatefulWidget {
  const StkLegalDocumentPage({
    super.key,
    required this.title,
    required this.httpsUrl,
  });

  final String title;
  final String httpsUrl;

  @override
  State<StkLegalDocumentPage> createState() => _StkLegalDocumentPageState();
}

class _StkLegalDocumentPageState extends State<StkLegalDocumentPage> {
  late Future<String> _document;

  @override
  void initState() {
    super.initState();
    _document = _fetch();
  }

  Future<String> _fetch() async {
    final uri = Uri.tryParse(widget.httpsUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('Se requiere una URL HTTPS publicada.');
    }
    final response = await http.get(uri).timeout(
      const Duration(seconds: 12),
    );
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (response.statusCode != 200 ||
        !(contentType.contains('text/plain') ||
          contentType.contains('text/markdown') ||
          contentType.contains('application/octet-stream'))) {
      throw const FormatException(
        'El documento debe estar publicado como texto legible.',
      );
    }
    if (response.body.trim().isEmpty || response.bodyBytes.length > 256000) {
      throw const FormatException('El documento no está disponible.');
    }
    return response.body;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: _document,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 32),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'No se pudo cargar el documento completo.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton(
                        onPressed: () => setState(() => _document = _fetch()),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return SelectionArea(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  Text(widget.title, style: AppTypography.headlineLarge),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    snapshot.data!,
                    style: AppTypography.bodyMedium.copyWith(
                      color: colors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
