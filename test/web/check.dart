import "dart:math";

import "package:mochi_cube/scramblers.dart";

/// What [web_test.dart](../web_test.dart) compiles, runs, and compares.
///
/// Every result line carries [marker] so the comparison can ignore whatever
/// else reached standard output — the table builder logs on the VM, where there
/// is a cache to miss, and does not on the web, where there is not.
///
/// Seeded, so the two runs have something to disagree about. The 3x3x3 solve is
/// the part that matters: its coordinates were bit-packed into a 64 bit
/// register, which the web does not have.
const String marker = "| ";

Future<void> main() async {
  for (final entry in allScramblers.entries) {
    final scramble = await entry.value.next(random: Random(1));
    print("$marker${entry.key} ${scramble.notation}");
    print("$marker${entry.key} ${scramble.state.join(",")}");
  }
}
