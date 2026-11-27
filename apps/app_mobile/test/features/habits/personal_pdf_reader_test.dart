import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/features/habits/data/personal_reading_library.dart';
import 'package:gym_tracker/features/habits/presentation/personal_pdf_reader_page.dart';

class _Library extends PersonalReadingLibraryRepository{
  int page=0;
  @override
  Future<PersonalReadingDocument?> checkpoint(String id,{required int page,required int totalPages,required ReadingSession session})async{
    this.page=page;return null;
  }
}
void main(){
  testWidgets('native page navigation checkpoints the page immediately',(tester)async{
    const channel=MethodChannel('stk_haven/pdf_reader');
    final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel,(call)async{
      final page=(call.arguments as Map)['page'] as int;
      return {'currentPage':page,'totalPages':3,'bytes':base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII=')};
    });
    addTearDown(()=>messenger.setMockMethodCallHandler(channel,null));
    final library=_Library();
    final doc=PersonalReadingDocument(id:'book',title:'Libro',originalFileName:'a.pdf',localPath:'/local/a.pdf',importedAt:DateTime(2026));
    await tester.pumpWidget(ProviderScope(child:MaterialApp(home:PersonalPdfReaderPage(document:doc,repository:library))));
    await tester.pumpAndSettle();
    expect(library.page,1);
    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.pumpAndSettle();
    expect(library.page,2);
    expect(find.text('2 / 3'),findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(),isNull);
  });
}
