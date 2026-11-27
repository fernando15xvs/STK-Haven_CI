import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
  test('three dedicated tabs and no duplicated Bible licensing card',(){
    final hub=File('lib/features/habits/presentation/study_habits_mobile_page.dart').readAsStringSync();
    for(final label in ['Hábitos','Lectura','Enfoque','Nuevo hábito','Libro físico','Diario privado','Objetivo semanal flexible']){
      expect(hub,contains(label));
    }
    expect(hub,isNot(contains('Biblia más fácil de entender')));
    expect(hub,isNot(contains('_documents.take(5)')));
    expect(hub,contains('PremiumCard'));
    final bible=File('lib/features/faith/presentation/pages/bible_reader_page.dart').readAsStringSync();
    expect(bible,contains('StudyHabitsPage(faithOnly:true)'));
  });
  test('both native readers and protected journal channels are wired',(){
    final android=File('android/app/src/main/kotlin/com/Fernando_S_ac/gym_tracker/MainActivity.kt').readAsStringSync();
    final ios=File('ios/Runner/AppDelegate.swift').readAsStringSync();
    for(final native in [android,ios]){
      expect(native,contains('stk_haven/pdf_reader'));
      expect(native,contains('renderPage'));
      expect(native,contains('stk_haven/private_journal'));
    }
    expect(android,contains('AndroidKeyStore'));
    expect(android,contains('noBackupFilesDir'));
    expect(ios,contains('completeFileProtection'));
    expect(ios,contains('isExcludedFromBackup'));
  });
}
