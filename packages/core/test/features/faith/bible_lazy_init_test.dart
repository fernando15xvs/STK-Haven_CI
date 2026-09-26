import 'package:core/features/faith/application/bible_init_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Faith OFF performs zero Bible initialization calls', () async {
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        faithModuleEnabledProvider.overrideWithValue(false),
        bibleDatabaseInitializerProvider.overrideWithValue((onStatus) async {
          calls++;
          return true;
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(bibleInitProvider.notifier).initialize();

    expect(calls, 0);
    expect(container.read(bibleInitProvider).status, BibleDbStatus.idle);
  });

  test('Faith ON initializes Bible on demand', () async {
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        faithModuleEnabledProvider.overrideWithValue(true),
        bibleDatabaseInitializerProvider.overrideWithValue((onStatus) async {
          calls++;
          onStatus('loading');
          return true;
        }),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(bibleInitProvider).status, BibleDbStatus.idle);

    await container.read(bibleInitProvider.notifier).initialize();

    expect(calls, 1);
    expect(container.read(bibleInitProvider).status, BibleDbStatus.ready);
  });

  test('failed lazy load is surfaced without retry loop', () async {
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        faithModuleEnabledProvider.overrideWithValue(true),
        bibleDatabaseInitializerProvider.overrideWithValue((onStatus) async {
          calls++;
          return false;
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(bibleInitProvider.notifier).initialize();

    expect(calls, 1);
    expect(container.read(bibleInitProvider).status, BibleDbStatus.error);
  });
}
