/// The cubes from 5x5x5 up.
///
/// Scrambled the way the WCA scrambles them, by random turns rather than a
/// random state: nothing here solves them, since a random state would need a
/// solver much larger than the turns.
library;

export "cube/algorithm.dart" show Algorithm, MoveSet;
export "cube/layout.dart" show Point, PuzzleLayout, cubeNetLayout;
export "nxn/cube.dart" show NxNCube, nxnFaceNames, nxnFaceletPosition, nxnMoves;
export "nxn/scramble.dart" show NxNTurns, randomNxNScramble, randomTurnCounts;
