import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
  test('one optional editor handles metadata and playlist selection',(){
    final page=File('lib/features/motivation/presentation/motivation_page.dart')
      .readAsStringSync();
    expect(page,contains('class _MotivationImportOptions'));
    expect(page,contains('Future<_MotivationImportOptions?> _importOptions('));
    expect(page,contains("ValueKey('motivation_import_title')"));
    expect(page,contains('options.title.trim()'));
    expect(page,contains('library.changeMode(track.id,options.mode)'));
    expect(page,contains('library.toggleFavorite(track.id)'));
    expect(page,contains('library.togglePlaylistTrack(id,track.id)'));
    // The cover picker now passes the optional in-app crop callback.
    expect(page,contains('if(options.chooseArtwork){'));
    expect(page,contains('await library.chooseArtwork('));
    expect(page,contains('requestFocus:(filePath)=>MotivationCoverCropSheet.show('));
    expect(page,contains('Importar directamente'));
    expect(page,contains('Omitir archivo'));
    expect(page,contains('Guardar cambios'));
  });

  test('import succeeds before optional customization and never autoplays',(){
    final page=File('lib/features/motivation/presentation/motivation_page.dart')
      .readAsStringSync();
    final importAt=page.indexOf('library.importFromPicker(mode:importMode)');
    final customizeAt=page.indexOf('await _importOptions(track)');
    expect(importAt,greaterThan(0));
    expect(customizeAt,greaterThan(importAt));
    final block=page.substring(importAt,customizeAt);
    expect(block,isNot(contains('player.playQueue(')));
  });
}
