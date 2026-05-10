//
// Generated file. Do not edit.
// This file is generated from template in file `flutter_tools/lib/src/flutter_plugins.dart`.
//

// @dart = 3.11

import 'dart:io'; // flutter_ignore: dart_io_import.
import 'package:flutter_lame/flutter_lame.dart' as flutter_lame;
import 'package:flutter_lame/flutter_lame.dart' as flutter_lame;

@pragma('vm:entry-point')
class _PluginRegistrant {

  @pragma('vm:entry-point')
  static void register() {
    if (Platform.isAndroid) {
    } else if (Platform.isIOS) {
      try {
        flutter_lame.FlutterLamePluginDarwin.registerWith();
      } catch (err) {
        print(
          '`flutter_lame` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

    } else if (Platform.isLinux) {
    } else if (Platform.isMacOS) {
      try {
        flutter_lame.FlutterLamePluginDarwin.registerWith();
      } catch (err) {
        print(
          '`flutter_lame` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

    } else if (Platform.isWindows) {
    }
  }
}
