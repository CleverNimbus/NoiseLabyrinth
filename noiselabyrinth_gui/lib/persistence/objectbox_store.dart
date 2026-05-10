import 'package:noiselabyrinth_gui/objectbox.g.dart';
import 'package:path_provider/path_provider.dart';

class ObjectBoxStore {
  ObjectBoxStore._(this.store);

  final Store store;

  static Future<ObjectBoxStore> create() async {
    final directory = await getApplicationSupportDirectory();
    final store = await openStore(directory: '${directory.path}/objectbox');
    return ObjectBoxStore._(store);
  }

  void close() {
    store.close();
  }
}
