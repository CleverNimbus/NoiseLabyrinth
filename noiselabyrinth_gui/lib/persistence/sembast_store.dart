import 'package:sembast/sembast.dart';

import 'sembast_store_platform.dart' as platform;

/// Manages Sembast database initialization and access.
class SembastStore {
  SembastStore._(this.database);

  final Database database;

  static Future<SembastStore> create() async {
    final database = await platform.openDatabase();
    return SembastStore._(database);
  }

  Future<void> close() async {
    await database.close();
  }
}
