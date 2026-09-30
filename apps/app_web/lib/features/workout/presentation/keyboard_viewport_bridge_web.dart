import 'dart:js_interop';

@JS('stkRecoverKeyboardViewport')
external void _stkRecoverKeyboardViewport();

void recoverKeyboardViewport() => _stkRecoverKeyboardViewport();
