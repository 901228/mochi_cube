/// Keeping built tables between runs, on a platform that has a filesystem.
///
/// The counterpart of [table_store.dart], chosen by a conditional import
/// wherever `dart:io` exists. Every solver in the package writes its cache into
/// [tableDirectory], so deleting the `.bin` files in it forces a full rebuild.
library;

import "dart:io";
import "dart:typed_data";

import "package:app_dirs/app_dirs.dart";
import "package:path/path.dart" as path;

import "../logger.dart";

/// Where the tables are cached: the platform's app-data directory, or null on
/// iOS and Android, whose apps are given no HOME to find one from.
String? get tableDirectory =>
    Platform.isIOS || Platform.isAndroid ? null : getAppDirs(application: "cube_solver").data;

/// Where [name] is kept, or just its name where there is no [tableDirectory].
String tablePath(String name) => switch (tableDirectory) {
  final directory? => path.join(directory, name),
  null => name,
};

/// The bytes last written under [name], or null if there are none to be had.
Uint8List? readTableBytes(String name) {
  if (tableDirectory == null) {
    return null;
  }
  final file = File(tablePath(name));
  if (!file.existsSync()) {
    return null;
  }
  try {
    return file.readAsBytesSync();
  } on FileSystemException catch (e) {
    Logging().warning("Cannot read $name: $e");
    return null;
  }
}

/// Keep [bytes] under [name] for next time.
///
/// A cache that cannot be written is a slow start, not a failure, so this warns
/// rather than throwing.
void writeTableBytes(String name, Uint8List bytes) {
  if (tableDirectory == null) {
    return;
  }
  final file = File(tablePath(name));
  try {
    final parent = file.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
    file.writeAsBytesSync(bytes, flush: true);
  } on FileSystemException catch (e) {
    Logging().warning("Cannot write $name: $e");
  }
}
