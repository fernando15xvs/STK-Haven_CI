import '../data/motivation_library.dart';

/// View-only filters. The original library and playlist order never change.
enum MotivationMediaFilter { all, audio, video }

class MotivationLibrarySearch {
  const MotivationLibrarySearch._();

  static String normalize(String value) => value.toLowerCase().trim()
    .replaceAll('á','a').replaceAll('é','e')
    .replaceAll('í','i').replaceAll('ó','o')
    .replaceAll('ú','u').replaceAll('ü','u');

  static List<MotivationTrack> filter(
    Iterable<MotivationTrack> original, {
    String query = '',
    MotivationMediaFilter media = MotivationMediaFilter.all,
  }) {
    final term=normalize(query);
    return [
      for(final track in original)
        if((media==MotivationMediaFilter.all ||
            (media==MotivationMediaFilter.video)==track.isVideo) &&
           (term.isEmpty ||
            normalize(track.title).contains(term) ||
            normalize(track.mode.label).contains(term)))
          track,
    ];
  }
}
