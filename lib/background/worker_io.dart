/// A scrambler running on an isolate of its own, where there are isolates.
///
/// The counterpart of [worker_stub.dart], chosen by a conditional import wherever `dart:io`
/// exists. One worker lives from the first scramble asked of it, so the tables a puzzle needs are
/// built or unpacked once, there, and the thread that draws the screen is never held for them.
///
/// The tables are plain static fields, which an isolate does not share, so they belong to the
/// worker and the scramble is made there too; only its notation comes back, and the caller turns
/// that into a [Scramble] again. The worker has no way to reach the files a host bundles, such as a
/// Flutter asset, so it asks the main isolate's [useTableBytesLoader] for them.
library;

import "dart:async";
import "dart:isolate";
import "dart:typed_data";

import "../logger.dart";
import "../scramblers.dart" show allScramblers;
import "../table_storage.dart" show suppliedTableBytes, useTableBytesLoader;

_Worker? _worker;

/// The notation of a scramble of the puzzle filed as [id], made on the worker.
Future<String>? scrambleInBackground(String id) => (_worker ??= _Worker())._scramble(id);

/// Stop the worker, and with it the tables it holds. The next scramble starts another.
///
/// A program that scrambles in the background has to call this before it can exit: the worker's
/// ports keep the process alive.
Future<void> closeWorker() async {
  final worker = _worker;
  _worker = null;
  await worker?._close();
}

/// The main isolate's end of the worker.
final class _Worker {
  _Worker() {
    _toWorker = _start();
  }

  final ReceivePort _inbox = ReceivePort();
  final ReceivePort _exit = ReceivePort();
  final Map<int, Completer<String>> _pending = {};
  late final Future<SendPort> _toWorker;
  Isolate? _isolate;
  int _requests = 0;
  bool _stopped = false;

  Future<SendPort> _start() async {
    final started = Completer<SendPort>();
    _inbox.listen((message) {
      switch (message) {
        case SendPort port:
          started.complete(port);
        case [final int request, final String notation]:
          _pending.remove(request)?.complete(notation);
        case [final int request, null, final String error]:
          _pending.remove(request)?.completeError(StateError(error));
        case ["bytes", final int ask, final String name]:
          unawaited(_supply(ask, name));
      }
    });
    _exit.listen((_) => _stop("The background scrambler stopped"));

    _isolate = await Isolate.spawn(_serve, _inbox.sendPort, onExit: _exit.sendPort);
    return started.future;
  }

  Future<String> _scramble(String id) async {
    if (_stopped) throw StateError("The background scrambler has stopped");
    final SendPort port;
    try {
      port = await _toWorker;
    } catch (_) {
      _stop("The background scrambler did not start");
      rethrow;
    }

    final done = Completer<String>();
    final request = _requests++;
    _pending[request] = done;
    port.send(["scramble", request, id]);
    return done.future;
  }

  /// Answer the worker's request for a table file, with null where the host has none.
  Future<void> _supply(int ask, String name) async {
    Uint8List? bytes;
    try {
      bytes = await suppliedTableBytes(name);
    } catch (e) {
      Logging().warning("Cannot load $name for the background scrambler: $e");
    }
    (await _toWorker).send([
      ask,
      bytes == null ? null : TransferableTypedData.fromList([bytes]),
    ]);
  }

  /// Give up on everything waiting, and let the next scramble start a worker of its own.
  void _stop(String reason) {
    if (_stopped) return;
    _stopped = true;
    if (identical(_worker, this)) _worker = null;
    for (final done in _pending.values) {
      done.completeError(StateError(reason));
    }
    _pending.clear();
    _inbox.close();
    _exit.close();
  }

  Future<void> _close() async {
    try {
      await _toWorker;
    } catch (_) {
      // It never started, so there is nothing to kill.
    }
    _isolate?.kill(priority: Isolate.immediate);
    _stop("The background scrambler was closed");
  }
}

/// The worker's end, run on the isolate [Isolate.spawn] makes.
void _serve(SendPort toMain) {
  final inbox = ReceivePort();
  final asked = <int, Completer<Uint8List?>>{};
  final given = <String>{};
  var asks = 0;

  useTableBytesLoader((name) {
    // A file is handed over once, as it is on the main isolate: the tables are built from it and
    // it is not kept. Asking again would move ten megabytes for nothing.
    if (!given.add(name)) return Future.value();

    final reply = Completer<Uint8List?>();
    final ask = asks++;
    asked[ask] = reply;
    toMain.send(["bytes", ask, name]);
    return reply.future;
  });

  // Listening rather than awaiting each message, so a scramble waiting for its tables does not
  // stop the reply that brings them being heard.
  inbox.listen((message) {
    switch (message) {
      case ["scramble", final int request, final String id]:
        unawaited(_scramble(toMain, request, id));
      case [final int ask, final TransferableTypedData? bytes]:
        asked.remove(ask)?.complete(bytes?.materialize().asUint8List());
    }
  });
  toMain.send(inbox.sendPort);
}

Future<void> _scramble(SendPort toMain, int request, String id) async {
  try {
    final scramble = await allScramblers[id]!.next();
    toMain.send([request, scramble.notation]);
  } catch (e) {
    toMain.send([request, null, "$e"]);
  }
}
