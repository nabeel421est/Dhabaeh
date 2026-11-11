import 'dart:js_interop';
import 'dart:typed_data';

@JS('dhRemoveBgLazy')
external JSPromise<JSUint8Array> _remove(JSUint8Array bytes, JSString mime);

Future<Uint8List?> removeImageBackground(Uint8List bytes, String mime) async {
  try {
    final r = await _remove(bytes.toJS, mime.toJS).toDart;
    return r.toDart;
  } catch (_) {
    return null;
  }
}
