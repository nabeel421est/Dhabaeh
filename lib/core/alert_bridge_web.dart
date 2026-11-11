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
