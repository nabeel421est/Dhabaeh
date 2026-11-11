import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'common.dart' show mimeOf;

import 'bg_remove_stub.dart' if (dart.library.js_interop) 'bg_remove_web.dart'
    as impl;

/// Removes the photo background on the device (no server, no key).
/// Returns a transparent PNG, or null when it is not available or fails.
/// The first run downloads the model (~88 MB), later runs use the browser cache.
Future<Uint8List?> removeImageBackground(Uint8List bytes, String mime) =>
    impl.removeImageBackground(bytes, mime);

/// Same photo with its background removed, named `…-cut.png` so the app shows
/// it fitted (not cropped). Null when removal is unavailable or fails.
Future<PlatformFile?> cutoutFile(PlatformFile f) async {
  if (f.bytes == null) return null;
  final out = await removeImageBackground(f.bytes!, mimeOf(f.name));
  if (out == null) return null;
  final base = f.name.contains('.')
      ? f.name.substring(0, f.name.lastIndexOf('.'))
      : f.name;
  return PlatformFile(name: '$base-cut.png', size: out.length, bytes: out);
}
