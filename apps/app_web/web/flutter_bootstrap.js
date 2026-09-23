{{flutter_js}}
{{flutter_build_config}}

// STK Haven owns service-worker registration in index.html.
// Keep Flutter from registering flutter_service_worker.js so only one worker
// controls the GitHub Pages scope.
_flutter.loader.load();
