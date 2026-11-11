import 'dart:js_interop';

/// window.dhAlert from web/alert.js.
@JS('dhAlert')
external _DhAlert? get _dh;

extension type _DhAlert._(JSObject _) implements JSObject {
  external void play();
  external void stop();
  external JSString permission();
  external void ask();
  external void notify(JSString title, JSString body);
  external JSPromise<JSString> pushStatus();
  external JSPromise<JSString> pushCurrent();
  external JSPromise<JSString> pushSubscribe(JSString key);
}

void alertPlay() {
  try {
    _dh?.play();
  } catch (_) {}
}

void alertStop() {
  try {
    _dh?.stop();
  } catch (_) {}
}

String alertPermission() {
  try {
    return _dh?.permission().toDart ?? 'unsupported';
  } catch (_) {
    return 'unsupported';
  }
}

void alertAsk() {
  try {
    _dh?.ask();
  } catch (_) {}
}

void alertNotify(String title, String body) {
  try {
    _dh?.notify(title.toJS, body.toJS);
  } catch (_) {}
}

Future<String> pushStatus() async {
  try {
    final d = _dh;
    if (d == null) return 'unsupported';
    return (await d.pushStatus().toDart).toDart;
  } catch (_) {
    return 'unsupported';
  }
}

Future<String> pushCurrent() async {
  try {
    final d = _dh;
    if (d == null) return '';
    return (await d.pushCurrent().toDart).toDart;
  } catch (_) {
    return '';
  }
}

/// Call straight from a tap (the browser asks for permission).
Future<String> pushSubscribe(String key) async {
  try {
    final d = _dh;
    if (d == null) return 'error:unsupported';
    return (await d.pushSubscribe(key.toJS).toDart).toDart;
  } catch (e) {
    return 'error:$e';
  }
}
