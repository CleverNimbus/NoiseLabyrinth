import 'package:sembast/sembast.dart';

import 'sembast_store_platform_stub.dart'
    if (dart.library.io) 'sembast_store_platform_io.dart'
    if (dart.library.js_interop) 'sembast_store_platform_web.dart'
    as impl;

Future<Database> openDatabase() => impl.openDatabase();
