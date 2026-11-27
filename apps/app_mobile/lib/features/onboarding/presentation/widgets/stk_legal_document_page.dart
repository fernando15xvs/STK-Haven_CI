import 'package:gym_tracker/core/layout/mobile_content_frame.dart';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:gym_tracker/core/theme/app_colors.dart';

/// Loads a FULL legal document over HTTPS and verifies the exact published
/// bytes against the release-approved SHA-256 before allowing any acceptance.
class StkPublishedLegalDocument {
  const StkPublishedLegalDocument._();

  static final _sha = RegExp(r'^[a-fA-F0-9]{64}$');

  static Future<String> load({
    required String httpsUrl,
    required String expectedSha256,
    http.Client? client,
  }) async {
    final uri = Uri.tryParse(httpsUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
        !_sha.hasMatch(expectedSha256)) {
      throw const FormatException('Documento legal no configurado.');
    }
    final httpClient = client ?? http.Client();
    try {
      // Do not follow redirects: the reviewed HTTPS URL must be the exact
      // publication endpoint, not a potentially downgraded replacement.
      final request = http.Request('GET', uri)..followRedirects = false;
      final streamed = await httpClient.send(request)
          .timeout(const Duration(seconds: 12));
      final response = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 12));
      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      if (response.statusCode != 200 ||
          !(contentType.startsWith('text/plain') ||
            contentType.startsWith('text/markdown') ||
            contentType.startsWith('application/octet-stream'))) {
        throw const FormatException('Documento legal no disponible como texto.');
      }
      if (response.bodyBytes.isEmpty || response.bodyBytes.length > 256000) {
        throw const FormatException(
          'Documento legal vacío o demasiado extenso.',
        );
      }
      final actualHash = sha256.convert(response.bodyBytes).toString();
      if (actualHash != expectedSha256.toLowerCase()) {
        throw const FormatException(
          'El documento publicado no coincide con la versión aprobada.',
        );
      }
      final text = const Utf8Decoder(allowMalformed: false)
          .convert(response.bodyBytes);
      if (text.trim().isEmpty) {
        throw const FormatException('El documento legal no contiene texto.');
      }
      return text;
    } finally {
      if (client == null) httpClient.close();
    }
  }
}

/// The user explicitly marks a successfully verified document as read.
/// Back, offline, a failed download or a mismatched hash never return true.
class StkLegalDocumentPage extends StatefulWidget {
  const StkLegalDocumentPage({
    super.key,
    required this.title,
    required this.httpsUrl,
    required this.expectedSha256,
    this.client,
  });

  final String title;
  final String httpsUrl;
  final String expectedSha256;
  /// Allows a deterministic offline fake in widget tests.
  final http.Client? client;

  @override
  State<StkLegalDocumentPage> createState() => _StkLegalDocumentPageState();
}

class _StkLegalDocumentPageState extends State<StkLegalDocumentPage> {
  late Future<String> _document;

  @override
  void initState() {
    super.initState();
    _document = _load();
  }

  Future<String> _load() => StkPublishedLegalDocument.load(
    httpsUrl: widget.httpsUrl,
    expectedSha256: widget.expectedSha256,
    client: widget.client,
  );

  @override
  void didUpdateWidget(covariant StkLegalDocumentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.httpsUrl != widget.httpsUrl ||
        oldWidget.expectedSha256 != widget.expectedSha256) {
      _document = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(bottom: false, 
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
                        'No se pudo verificar el documento completo.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton(
                        onPressed: () => setState(() => _document = _load()),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return SelectionArea(
              child: ListView(
                padding: SecondaryScreenInsets.scrollPadding(context, const EdgeInsets.all(AppSpacing.xl)),
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
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    key: const ValueKey('stk_verified_legal_read'),
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('He revisado este documento'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
