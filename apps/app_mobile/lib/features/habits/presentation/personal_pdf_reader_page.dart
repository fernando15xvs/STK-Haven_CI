import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/personal_reading_library.dart';

class PersonalPdfReaderPage extends StatefulWidget {
  final PersonalReadingDocument document;
  final PersonalReadingLibraryRepository repository;

  const PersonalPdfReaderPage({
    super.key,
    required this.document,
    required this.repository,
  });

  @override
  State<PersonalPdfReaderPage> createState() => _PersonalPdfReaderPageState();
}

class _PersonalPdfReaderPageState extends State<PersonalPdfReaderPage> {
  static const MethodChannel _channel =
      MethodChannel('stk_haven/pdf_reader');

  late PersonalReadingDocument _document;
  bool _opening = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _document = widget.document;
    WidgetsBinding.instance.addPostFrameCallback((_) => _openNativeReader());
  }

  Future<void> _openNativeReader() async {
    if (_opening) return;
    if (!File(_document.localPath).existsSync()) {
      setState(() {
        _error =
            'El PDF ya no está disponible en este dispositivo. '
            'Elimínalo de la biblioteca e impórtalo de nuevo.';
      });
      return;
    }

    setState(() {
      _opening = true;
      _error = null;
    });

    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'openPdf',
        <String, Object?>{
          'path': _document.localPath,
          'title': _document.title,
          'initialPage': _document.currentPage,
        },
      );
      if (result == null) return;

      final currentPage = (result['currentPage'] as num?)?.toInt() ??
          _document.currentPage;
      final totalPages =
          (result['totalPages'] as num?)?.toInt() ?? _document.totalPages;

      await widget.repository.updateProgress(
        _document,
        currentPage: currentPage,
        totalPages: totalPages,
      );
      if (!mounted) return;
      setState(() {
        _document = _document.copyWith(
          currentPage: currentPage,
          totalPages: totalPages,
          lastReadAt: DateTime.now(),
        );
      });
    } on MissingPluginException {
      if (mounted) {
        setState(() {
          _error =
              'El lector PDF integrado está disponible en iPhone. '
              'En esta plataforma conserva el archivo en la biblioteca, '
              'pero todavía no puede abrirse dentro de STK Haven.';
        });
      }
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message ?? 'No se pudo abrir el PDF.';
        });
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _document.progress;
    final pace = _document.suggestedPagesPerDay;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _document.title,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(
              Icons.picture_as_pdf_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              _document.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _document.totalPages <= 0 ? null : progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(99),
            ),
            const SizedBox(height: 10),
            Text(
              _document.totalPages <= 0
                  ? 'Abre el PDF para detectar sus páginas.'
                  : 'Página ' +
                      _document.currentPage.toString() +
                      ' de ' +
                      _document.totalPages.toString() +
                      ' · ' +
                      (progress * 100).round().toString() +
                      '%',
              textAlign: TextAlign.center,
            ),
            if (pace > 0) ...[
              const SizedBox(height: 6),
              Text(
                'Ritmo sugerido: ' +
                    pace.toString() +
                    ' páginas por día para terminar aproximadamente en 2 semanas.',
                textAlign: TextAlign.center,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 20),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _opening ? null : _openNativeReader,
              icon: const Icon(Icons.menu_book_outlined),
              label: Text(_opening ? 'Abriendo…' : 'Abrir PDF'),
            ),
            const SizedBox(height: 12),
            const Text(
              'El archivo permanece local en tu dispositivo. '
              'STK Haven guarda únicamente tu progreso de lectura local.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
