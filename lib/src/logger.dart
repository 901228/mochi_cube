import "package:logger/logger.dart";

class Logging {
  late final Logger logger;

  factory Logging() => _instance;
  static final Logging _instance = Logging._internal();
  Logging._internal() {
    logger = Logger(level: Level.info, printer: PrettyPrinter(colors: true, printEmojis: true));
  }

  void debug(dynamic message) {
    logger.d(message);
  }

  void info(dynamic message) {
    logger.i(message, stackTrace: StackTrace.empty);
  }

  void warning(dynamic message) {
    logger.w(message);
  }

  void error(dynamic message) {
    logger.e(message);
  }

  void fatal(dynamic message) {
    logger.f(message);
  }
}
