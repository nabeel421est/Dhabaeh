import 'dart:js_interop';

@JS('window.location.assign')
external void _assign(JSString url);

@JS('window.history.replaceState')
external void _replace(JSAny? state, JSString title, JSString url);

@JS('window.location.pathname')
external JSString get _path;

@JS('window.location.hash')
external JSString get _hash;

/// Leave the app for [url] in the same tab (used for the payment page).
void pageGo(String url) => _assign(url.toJS);

/// Drop ?query from the address bar once it has been handled.
void pageCleanQuery() =>
    _replace(null, ''.toJS, '${_path.toDart}${_hash.toDart}'.toJS);
