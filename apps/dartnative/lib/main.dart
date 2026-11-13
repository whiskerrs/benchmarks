import 'package:dartnative/dartnative.dart';

import 'dartnative_plugin_registrant.dart';
import 'shell.dart';

void main() {
  // Platform bindings and plugin FFI symbols; must stay the first line.
  DartNativePluginRegistrant.registerAll();
  SystemChrome.defaultStyle = const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  );
  runApp(const AppShell());
}
