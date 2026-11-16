import '../data/motivation_library.dart';

/// Determines explicit skip navigation in actual playback order.
class MotivationQueueNavigation {
  const MotivationQueueNavigation._();

  /// Repeating one track automatically does not mean that a manual "Next"
  /// tap should replay that same track. Shuffle order comes from just_audio's
  /// effectiveIndices and is never guessed from the stored library order.
  static int? nextIndex({
    required MotivationRepeat repeat,
    required int? currentIndex,
    required List<int> effectiveIndices,
  }) {
    if(repeat==MotivationRepeat.stop ||
       currentIndex==null || effectiveIndices.length<2)return null;
    final currentPosition=effectiveIndices.indexOf(currentIndex);
    if(currentPosition<0)return null;
    final nextPosition=currentPosition+1;
    if(nextPosition<effectiveIndices.length){
      return effectiveIndices[nextPosition];
    }
    // Repeat list wraps, even when the shuffled order ends in another index.
    return repeat==MotivationRepeat.all?effectiveIndices.first:null;
  }
}
