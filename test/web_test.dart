import "dart:convert";
import "dart:io";

import "package:path/path.dart" as path;
import "package:test/test.dart";

import "web/check.dart" show marker;

/// The package has to work on the web, and nothing else here would notice if it
/// stopped.
///
/// A Dart `int` is 64 bits on the VM and a double on the web, where the bitwise
/// operators truncate to 32 as well — so arithmetic that is exact in one place
/// is silently wrong or refused in the other. `dart:io` is not there either.
/// Both of those broke this package once and neither showed up in any other
/// test, because every other test runs on the VM.
void main() {
  final dart = Platform.resolvedExecutable;
  final source = path.join("test", "web", "check.dart");

  late Directory output;
  setUpAll(() => output = Directory.systemTemp.createTempSync("mochi_cube_web"));
  tearDownAll(() => output.deleteSync(recursive: true));

  /// The result lines of a run, in order, with anything else dropped.
  List<String> results(String out) => out.split("\n").where((line) => line.startsWith(marker)).toList();

  test("compiles to JavaScript and answers exactly as the VM does", () {
    final compiled = path.join(output.path, "check.js");
    final compile = Process.runSync(dart, ["compile", "js", "-O1", "-o", compiled, source]);
    expect(compile.exitCode, 0, reason: "${compile.stdout}\n${compile.stderr}");

    final onVm = Process.runSync(dart, ["run", source]);
    expect(onVm.exitCode, 0, reason: "${onVm.stdout}\n${onVm.stderr}");
    expect(results(onVm.stdout as String), isNotEmpty);

    if (!_hasNode) {
      markTestSkipped("node is not installed, so only the compile was checked");
      return;
    }

    // node defines no `self`, and dart2js reaches for it to schedule a timer,
    // so without this an `await` never resumes and the program prints nothing
    // at all. A browser needs no such help.
    final onNode = Process.runSync("node", [
      "-e",
      "globalThis.self = globalThis; require(${jsonEncode(compiled)});",
    ]);
    expect(onNode.exitCode, 0, reason: "${onNode.stdout}\n${onNode.stderr}");
    expect(results(onNode.stdout as String), results(onVm.stdout as String));
  }, timeout: const Timeout(Duration(minutes: 3)));
}

/// Whether there is a JavaScript engine here to run the compiled output with.
final bool _hasNode = () {
  try {
    return Process.runSync("node", ["--version"]).exitCode == 0;
  } on ProcessException {
    return false;
  }
}();
