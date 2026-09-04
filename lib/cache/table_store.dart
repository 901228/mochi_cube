/// Keeping built tables between runs, where the platform has somewhere to keep
/// them.
///
/// This is the version for platforms that have no filesystem — the web — and it
/// is also the one the analyzer reads, so it is the declaration the rest of the
/// package is written against. [table_store_io.dart] is the real one, chosen by
/// a conditional import wherever `dart:io` exists.
///
/// Nothing here fails when there is nowhere to cache: the tables are built in
/// memory as usual and simply not kept, which costs a rebuild on each start
/// rather than a missing feature.
library;

import "dart:typed_data";

/// Where the tables are cached, or null when they are not cached at all.
String? get tableDirectory => null;

/// The bytes last written under [name], or null if there are none to be had.
Uint8List? readTableBytes(String name) => null;

/// Keep [bytes] under [name] for next time, where there is a next time.
void writeTableBytes(String name, Uint8List bytes) {}

/// Where [name] would be kept, for logging. Just the name where nothing is kept.
String tablePath(String name) => name;
