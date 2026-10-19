/// The background scrambler for a platform with no isolates, which is the web.
///
/// The counterpart of [worker_io.dart], chosen by a conditional import wherever `dart:io` exists.
/// It never starts anything: [scrambleInBackground] says there is no background, and the caller
/// scrambles where it stands.
library;

/// The notation of a scramble of the puzzle filed as [id], or null where nothing can make it
/// elsewhere.
Future<String>? scrambleInBackground(String id) => null;

/// Stop the background scrambler. There is none to stop.
Future<void> closeWorker() async {}
