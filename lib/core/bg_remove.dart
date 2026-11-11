import 'dart:typed_data';

import 'bg_remove_stub.dart' if (dart.library.js_interop) 'bg_remove_web.dart'
    as impl;

/// Removes the photo background on the device (no server, no key).
/// Returns a transparent PNG, or null when it is not available or fails.
/// The first run downloads the model (~45 MB), later runs use the browser cache.
Future<Uint8List?> removeImageBackground(Uint8List bytes, String mime) =>
    impl.removeImageBackground(bytes, mime);
