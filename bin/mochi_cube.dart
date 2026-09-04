import "dart:io";

import "package:args/command_runner.dart";
import "package:mochi_cube/cli.dart";

Future<void> main(List<String> arguments) async {
  try {
    await runCli(arguments);
  } on UsageException catch (error) {
    stderr.writeln(error);
    exit(64); // what a command line tool returns for bad usage
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exit(1);
  }
}
