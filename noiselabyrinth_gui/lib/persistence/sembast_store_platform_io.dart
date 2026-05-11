import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

Future<Database> openDatabase() async {
  final directory = await getApplicationSupportDirectory();
  final databasePath = '${directory.path}/noiselabyrinth.db';
  return databaseFactoryIo.openDatabase(databasePath);
}
