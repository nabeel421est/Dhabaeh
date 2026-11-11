// Non-web builds: no browser sound bridge yet.
void alertPlay() {}
void alertStop() {}
String alertPermission() => 'unsupported';
void alertAsk() {}
void alertNotify(String title, String body) {}
Future<String> pushStatus() async => 'unsupported';
Future<String> pushCurrent() async => '';
Future<String> pushSubscribe(String key) async => 'error:unsupported';
