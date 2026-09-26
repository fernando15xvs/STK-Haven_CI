import 'package:core/features/faith/application/faith_feature_policy.dart';
import 'package:core/features/faith/data/bible_public_domain_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FaithFeaturePolicy', () {
    test('faith off blocks Bible loading and daily content', () {
      expect(
        FaithFeaturePolicy.shouldLoadBible(faithEnabled: false),
        isFalse,
      );
      expect(
        FaithFeaturePolicy.shouldShowDailyVerse(
          faithEnabled: false,
          showDailyVerse: true,
        ),
        isFalse,
      );
      expect(
        FaithFeaturePolicy.shouldScheduleDailyVerseNotification(
          faithEnabled: false,
          notificationEnabled: true,
        ),
        isFalse,
      );
    });

    test('subpreferences only become effective after faith opt-in', () {
      expect(
        FaithFeaturePolicy.shouldShowDailyVerse(
          faithEnabled: true,
          showDailyVerse: true,
        ),
        isTrue,
      );
      expect(
        FaithFeaturePolicy.shouldScheduleDailyVerseNotification(
          faithEnabled: true,
          notificationEnabled: true,
        ),
        isTrue,
      );
    });
  });

  group('BiblePublicDomainSource', () {
    test('parses versioned RV1909 row and strips markup', () {
      final row = BiblePublicDomainSource.parseEntry({
        'title': 'Juan 1:1',
        'content':
            '<p><sup>1</sup>&nbsp;EN el principio era el Verbo.</p>',
      });

      expect(row, isNotNull);
      expect(row!.book, 'Juan');
      expect(row.chapter, 1);
      expect(row.verse, 1);
      expect(row.text, 'EN el principio era el Verbo.');
    });

    test('declares pinned public-domain source metadata', () {
      expect(BiblePublicDomainSource.translationName, 'Reina-Valera 1909');
      expect(BiblePublicDomainSource.sourceTag, 'v2026-09-18');
      expect(BiblePublicDomainSource.licenseName, contains('Public Domain'));
    });
  });
}
