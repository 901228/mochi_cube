import "../logger.dart";
import "../table_storage.dart";
import "coordinates.dart";
import "cube.dart";

/// The distance table for the Skewb.
///
/// 3149280 states, which one breadth-first search covers, so the exact number
/// of turns to solve is known for every one of them and solving is a walk
/// downhill rather than a search. God's number is 11.
///
/// A state is its corners and its centres, each numbered by [SkewbPart], and
/// the two move on their own. Every pair is reachable, which is what makes the
/// count `8748 * 360`.
class SkewbTables {
  factory SkewbTables() => _instance;
  static final SkewbTables _instance = SkewbTables._internal();

  static int get nCorners => SkewbPart.corners.length;
  static int get nCentres => SkewbPart.centres.length;
  static int get nStates => nCorners * nCentres;

  /// The cache file. Bump the version whenever [SkewbPart]'s numbering or the
  /// builder below changes: the file is indexed by both and checks neither.
  static TableFile get _cache => const TableFile(
    name: TableFiles.skewb,
    magic: [0x53, 0x4B, 0x45, 0x57], // "SKEW"
    version: 1,
  );

  SkewbTables._internal() {
    final cached = _cache.read([(nStates + 1) ~/ 2]);
    if (cached != null) {
      distance = PruningTable(cached[0], nCentres, nStates);
      Logging().info("Loaded the skewb tables from ${_cache.location}");
      return;
    }

    distance = fillPruningTable(
      length: nStates,
      stride: nCentres,
      moveCount: skewbMoves.count,
      successor: successor,
    );
    _cache.write([distance.data]);
  }

  /// Turns needed to solve, for every state. Exact, not a bound.
  late final PruningTable distance;

  /// The state of [cube], as an index.
  int stateOf(SkewbCube cube) =>
      SkewbPart.corners.indexOf(cube.facelets)! * nCentres + SkewbPart.centres.indexOf(cube.facelets)!;

  /// The state reached from [index] by [move].
  int successor(int index, int move) =>
      SkewbPart.corners.move[(index ~/ nCentres, move)] * nCentres +
      SkewbPart.centres.move[(index % nCentres, move)];

  /// Turns needed to solve [cube]. Exact, not a bound.
  int distanceOf(SkewbCube cube) => distance.at(stateOf(cube));

  int get lengthInBytes => distance.lengthInBytes;
}
