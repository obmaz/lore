import 'dart:js_interop';

const browserFullscreenAvailable = true;

@JS('loreToggleFullscreen')
external JSPromise<JSString> _toggleFullscreen();

Future<String> toggleBrowserFullscreen() async =>
    (await _toggleFullscreen().toDart).toDart;
