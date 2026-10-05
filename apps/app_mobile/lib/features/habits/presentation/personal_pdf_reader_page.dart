import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

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
  late final PdfControllerPinch _controller;
  Timer? _persistDebounce;
  int _currentPage = 1;
  int _totalPages = 0;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.document.currentPage < 1
        ? 1
        : widget.document.currentPage;
    _totalPages = widget.document.totalPages;
    _controller = PdfControllerPinch(
      document: PdfDocument.openFile(widget.document.localPath),
      initialPage: _currentPage,
    );
  }

  @override
  void dispose() {
    _persistDebounce?.cancel();
    _persistNow();
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    if (!mounted) return;
    setState(() => _currentPage = page);
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 500), _persistNow);
  }

  void _onDocumentLoaded(PdfDocument document) {
    if (!mounted) return;
    setState(() {
      _totalPages = document.pagesCount;
      _error = null;
    });
    _persistNow();
  }

  Future<void> _persistNow() {
    return widget.repository.updateProgress(
      widget.document,
      currentPage: _currentPage,
      totalPages: _totalPages,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileExists = File(widget.document.localPath).existsSync();
    final progress = _totalPages <= 0
        ? 0.0
        : (_currentPage / _totalPages).clamp(0.0, 1.0).toDouble();
    final remaining = _totalPages <= 0
        ? 0
        : (_totalPages - _currentPage).clamp(0, _totalPages);
    final pace = remaining == 0 ? 0 : (remaining / 14).ceil();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.document.title,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: !fileExists
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'El PDF ya no está disponible en este dispositivo. '
                  'Puedes eliminarlo de la biblioteca e importarlo de nuevo.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No se pudo abrir este PDF.\n$_error',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : PdfViewPinch(
                          controller: _controller,
                          onPageChanged: _onPageChanged,
                          onDocumentLoaded: _onDocumentLoaded,
                          onDocumentError: (error) {
                            if (mounted) setState(() => _error = error);
                          },
                          scrollDirection: Axis.vertical,
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LinearProgressIndicator(
                          value: _totalPages <= 0 ? null : progress,
                          minHeight: 5,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              _totalPages <= 0
                                  ? 'Página $_currentPage'
                                  : 'Página $_currentPage de $_totalPages',
                            ),
                            const Spacer(),
                            if (pace > 0)
                              Text(
                                '$pace pág/día · meta 2 semanas',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
