import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gym_tracker/features/onboarding/presentation/widgets/stk_legal_document_page.dart';

void main() {
  const published = 'STK Haven. Condiciones completas de prueba.\n'
      'Privacidad: sólo procesamiento solicitado.';
  final digest = sha256.convert(utf8.encode(published)).toString();
  const url = 'https://example.org/legal-v1.txt';

  MockClient client({
    String body = published,
    int status = 200,
    String contentType = 'text/plain; charset=utf-8',
  }) => MockClient((request) async {
    expect(request.url.toString(), url);
    return http.Response(body, status, headers: {
      'content-type': contentType,
    });
  });

  test('exact bytes over HTTPS match the approved SHA256', () async {
    final loaded = await StkPublishedLegalDocument.load(
      httpsUrl: url,
      expectedSha256: digest.toUpperCase(),
      client: client(),
    );
    expect(loaded, published);
  });

  test('different text with the same configured version must fail closed',
      () async {
    await expectLater(
      StkPublishedLegalDocument.load(
        httpsUrl: url,
        expectedSha256: digest,
        client: client(body: 'Texto alterado en producción'),
      ),
      throwsFormatException,
    );
  });

  test('HTTP, malformed hash, untrusted HTML and errors cannot be read',
      () async {
    await expectLater(
      StkPublishedLegalDocument.load(
        httpsUrl: 'http://example.org/legal-v1.txt',
        expectedSha256: digest,
        client: client(),
      ),
      throwsFormatException,
    );
    await expectLater(
      StkPublishedLegalDocument.load(
        httpsUrl: url,
        expectedSha256: 'not-a-sha',
        client: client(),
      ),
      throwsFormatException,
    );
    await expectLater(
      StkPublishedLegalDocument.load(
        httpsUrl: url,
        expectedSha256: digest,
        client: client(contentType: 'text/html'),
      ),
      throwsFormatException,
    );
    await expectLater(
      StkPublishedLegalDocument.load(
        httpsUrl: url,
        expectedSha256: digest,
        client: client(status: 503),
      ),
      throwsFormatException,
    );
    await expectLater(
      StkPublishedLegalDocument.load(
        httpsUrl: url,
        expectedSha256: digest,
        client: client(body: ''),
      ),
      throwsFormatException,
    );
  });

  test('invalid UTF-8 is rejected even if byte digest matches', () async {
    final badBytes = <int>[0xc3, 0x28];
    final invalid = MockClient((_) async => http.Response.bytes(
      badBytes, 200, headers: {'content-type': 'text/plain'},
    ));
    await expectLater(
      StkPublishedLegalDocument.load(
        httpsUrl: url,
        expectedSha256: sha256.convert(badBytes).toString(),
        client: invalid,
      ),
      throwsFormatException,
    );
  });

  testWidgets('only a verified full document can return acknowledgement',
      (tester) async {
    final fake = client();
    addTearDown(fake.close);
    bool? accepted;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () async {
              accepted = await Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (_) => StkLegalDocumentPage(
                    title: 'Política de Privacidad',
                    httpsUrl: url,
                    expectedSha256: digest,
                    client: fake,
                  ),
                ),
              );
            },
            child: const Text('Abrir'),
          ),
        ),
      )),
    ));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Condiciones completas'), findsOneWidget);
    final confirm = find.byKey(const ValueKey('stk_verified_legal_read'));
    expect(confirm, findsOneWidget);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(accepted, isTrue);
  });

  testWidgets('changed content never exposes the acknowledgement button',
      (tester) async {
    final fake = client(body: 'OTRO TEXTO');
    addTearDown(fake.close);
    await tester.pumpWidget(MaterialApp(
      home: StkLegalDocumentPage(
        title: 'Términos',
        httpsUrl: url,
        expectedSha256: digest,
        client: fake,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stk_verified_legal_read')), findsNothing);
    expect(find.textContaining('No se pudo verificar'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
