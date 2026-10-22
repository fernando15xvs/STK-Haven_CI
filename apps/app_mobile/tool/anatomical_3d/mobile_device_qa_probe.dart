// Opt-in, on-device anatomical GPU QA. NOT production telemetry.
// Flutter FrameTiming describes Flutter UI/raster work, NOT native GLES/Metal
// GPU completion, actual platform-view presentation, or display refresh FPS.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Ring-buffered Flutter frame durations and observed process RSS snapshots.
/// Recording stops at a bounded sample count even during lengthy QA sessions.
class GlbDeviceQaAccumulator {
  GlbDeviceQaAccumulator({this.capacity=240})
      : assert(capacity>0&&capacity<=1200);

  final int capacity;
  final List<int> _totalUs=<int>[];
  final List<int> _buildUs=<int>[];
  final List<int> _rasterUs=<int>[];
  int sampleCount=0;
  int lastRssBytes=0,maxObservedRssBytes=0;
  int observedRssSamples=0;

  void addFrame({required int totalUs,required int buildUs,
      required int rasterUs}) {
    if(totalUs<0||buildUs<0||rasterUs<0) {
      throw const FormatException('Invalid Flutter frame duration');
    }
    void append(List<int> items,int value) {
      if(items.length==capacity)items.removeAt(0);
      items.add(value);
    }
    append(_totalUs,totalUs);
    append(_buildUs,buildUs);
    append(_rasterUs,rasterUs);
    sampleCount++;
  }

  void observeRss(int bytes) {
    if(bytes<0)throw const FormatException('Invalid process resident size');
    lastRssBytes=bytes;
    maxObservedRssBytes=math.max(maxObservedRssBytes,bytes);
    observedRssSamples++;
  }

  int _percentile(List<int> values,double fraction) {
    if(values.isEmpty)return 0;
    final sorted=List<int>.of(values)..sort();
    return sorted[((sorted.length-1)*fraction).ceil()];
  }

  Map<String,Object> summary() {
    return <String,Object>{
      'flutterFramesObserved':sampleCount,
      'flutterFrameSamplesRetained':_totalUs.length,
      'flutterTotalP50Us':_percentile(_totalUs,.50),
      'flutterTotalP95Us':_percentile(_totalUs,.95),
      'flutterBuildP95Us':_percentile(_buildUs,.95),
      'flutterRasterP95Us':_percentile(_rasterUs,.95),
      'flutterTotalOver16667Us':_totalUs.where((x)=>x>16667).length,
      'flutterTotalOver33333Us':_totalUs.where((x)=>x>33333).length,
      'lastProcessRssBytes':lastRssBytes,
      'maxObservedProcessRssBytes':maxObservedRssBytes,
      'residentMemoryObservations':observedRssSamples,
      'memoryMetric':'ProcessInfo.currentRss sample; not allocation peak',
      'frameMetric':'Flutter FrameTiming; native platform view GPU not timed',
    };
  }

  void reset() {
    _totalUs.clear();_buildUs.clear();_rasterUs.clear();
    sampleCount=0;lastRssBytes=0;maxObservedRssBytes=0;
    observedRssSamples=0;
  }
}

/// Attaches to the Flutter scheduler ONLY when the hidden native reviewer
/// opts in. No timers, network requests, storage, or production analytics.
class GlbDeviceQaSession extends ChangeNotifier {
  GlbDeviceQaSession({GlbDeviceQaAccumulator? accumulator})
      : data=accumulator??GlbDeviceQaAccumulator();

  final GlbDeviceQaAccumulator data;
  bool _running=false;
  bool get isRunning=>_running;

  void start() {
    if(_running)return;
    _running=true;
    SchedulerBinding.instance.addTimingsCallback(_recordFrames);
    sampleMemory();
  }

  void stop() {
    if(!_running)return;
    SchedulerBinding.instance.removeTimingsCallback(_recordFrames);
    _running=false;
    notifyListeners();
  }

  void _recordFrames(List<FrameTiming> frames) {
    if(!_running)return;
    for(final timing in frames) {
      data.addFrame(
        totalUs:timing.totalSpan.inMicroseconds,
        buildUs:timing.buildDuration.inMicroseconds,
        rasterUs:timing.rasterDuration.inMicroseconds,
      );
    }
    // Sampling resident size per callback is deliberate (not per vertex,
    // not per frame); notification triggers no hot GPU-path processing.
    if(data.sampleCount%30==0) {
      sampleMemory();
    }
  }

  void sampleMemory() {
    if(!_running)return;
    try {
      if(Platform.isAndroid||Platform.isIOS) {
        data.observeRss(ProcessInfo.currentRss);
      }
    } catch (_) {
      // Unavailable/unsupported PSS must not crash the visual reviewer.
    }
    notifyListeners();
  }

  String exportJson({required String sceneId,required String scenario,
      required Map<String,Object> gpuChannelCounters}) {
    final mobile=Platform.isAndroid||Platform.isIOS;
    return const JsonEncoder.withIndent('  ').convert({
      'schema':'stk_mobile_anatomy_qa_v9_7',
      'recordedUtc':DateTime.now().toUtc().toIso8601String(),
      'platform':Platform.operatingSystem,
      'mobileRuntime':mobile,
      'sourceScene':sceneId,
      'scenario':scenario,
      'approved':false,
      'enabled':false,
      'flutterFrameAndProcessMemory':data.summary(),
      'nativeMethodChannel':gpuChannelCounters,
      'notMeasured':[
        'GPU presentation FPS or Android EGL swap completion',
        'isolated platform-view rendering time',
        'thermal throttling, battery drain and sustainable session duration',
        'anatomical accuracy and exercise contact constraints',
      ],
      'requiresPhysicalDeviceReview':true,
    });
  }

  @override
  void dispose() {
    if(_running)SchedulerBinding.instance.removeTimingsCallback(_recordFrames);
    _running=false;
    super.dispose();
  }
}
