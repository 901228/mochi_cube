import "cubie_cube.dart";
import "enums.dart";

// Moves on the cubie level, gives permutation and orientation after the moves U, R, F, D, L, B respectively from a clean cube
// This will be used to compute move tables and the composition rules

// final List<CCorner> _corner = [
//   CCorner(ECorner.upRightFront, 0),
//   CCorner(ECorner.upFrontLeft, 0),
//   CCorner(ECorner.upLeftBack, 0),
//   CCorner(ECorner.upBackRight, 0),
//   CCorner(ECorner.downFrontRight, 0),
//   CCorner(ECorner.downLeftFront, 0),
//   CCorner(ECorner.downBackLeft, 0),
//   CCorner(ECorner.downRightBack, 0),
// ];
// final List<CEdge> _edge = [
//   CEdge(EEdge.upRight, 0),
//   CEdge(EEdge.upFront, 0),
//   CEdge(EEdge.upLeft, 0),
//   CEdge(EEdge.upBack, 0),
//   CEdge(EEdge.downRight, 0),
//   CEdge(EEdge.downFront, 0),
//   CEdge(EEdge.downLeft, 0),
//   CEdge(EEdge.downBack, 0),
//   CEdge(EEdge.frontRight, 0),
//   CEdge(EEdge.frontLeft, 0),
//   CEdge(EEdge.backLeft, 0),
//   CEdge(EEdge.backRight, 0),
// ];

final List<CCorner> _cornerU = [
  CCorner(ECorner.upBackRight, 0),
  CCorner(ECorner.upRightFront, 0),
  CCorner(ECorner.upFrontLeft, 0),
  CCorner(ECorner.upLeftBack, 0),
  CCorner(ECorner.downFrontRight, 0),
  CCorner(ECorner.downLeftFront, 0),
  CCorner(ECorner.downBackLeft, 0),
  CCorner(ECorner.downRightBack, 0),
];
final List<CEdge> _edgeU = [
  CEdge(EEdge.upBack, 0),
  CEdge(EEdge.upRight, 0),
  CEdge(EEdge.upFront, 0),
  CEdge(EEdge.upLeft, 0),
  CEdge(EEdge.downRight, 0),
  CEdge(EEdge.downFront, 0),
  CEdge(EEdge.downLeft, 0),
  CEdge(EEdge.downBack, 0),
  CEdge(EEdge.frontRight, 0),
  CEdge(EEdge.frontLeft, 0),
  CEdge(EEdge.backLeft, 0),
  CEdge(EEdge.backRight, 0),
];

final List<CCorner> _cornerR = [
  CCorner(ECorner.downFrontRight, 2),
  CCorner(ECorner.upFrontLeft, 0),
  CCorner(ECorner.upLeftBack, 0),
  CCorner(ECorner.upRightFront, 1),
  CCorner(ECorner.downRightBack, 1),
  CCorner(ECorner.downLeftFront, 0),
  CCorner(ECorner.downBackLeft, 0),
  CCorner(ECorner.upBackRight, 2),
];
final List<CEdge> _edgeR = [
  CEdge(EEdge.frontRight, 0),
  CEdge(EEdge.upFront, 0),
  CEdge(EEdge.upLeft, 0),
  CEdge(EEdge.upBack, 0),
  CEdge(EEdge.backRight, 0),
  CEdge(EEdge.downFront, 0),
  CEdge(EEdge.downLeft, 0),
  CEdge(EEdge.downBack, 0),
  CEdge(EEdge.downRight, 0),
  CEdge(EEdge.frontLeft, 0),
  CEdge(EEdge.backLeft, 0),
  CEdge(EEdge.upRight, 0),
];

final List<CCorner> _cornerF = [
  CCorner(ECorner.upFrontLeft, 1),
  CCorner(ECorner.downLeftFront, 2),
  CCorner(ECorner.upLeftBack, 0),
  CCorner(ECorner.upBackRight, 0),
  CCorner(ECorner.upRightFront, 2),
  CCorner(ECorner.downFrontRight, 1),
  CCorner(ECorner.downBackLeft, 0),
  CCorner(ECorner.downRightBack, 0),
];
final List<CEdge> _edgeF = [
  CEdge(EEdge.upRight, 0),
  CEdge(EEdge.frontLeft, 1),
  CEdge(EEdge.upLeft, 0),
  CEdge(EEdge.upBack, 0),
  CEdge(EEdge.downRight, 0),
  CEdge(EEdge.frontRight, 1),
  CEdge(EEdge.downLeft, 0),
  CEdge(EEdge.downBack, 0),
  CEdge(EEdge.upFront, 1),
  CEdge(EEdge.downFront, 1),
  CEdge(EEdge.backLeft, 0),
  CEdge(EEdge.backRight, 0),
];

final List<CCorner> _cornerD = [
  CCorner(ECorner.upRightFront, 0),
  CCorner(ECorner.upFrontLeft, 0),
  CCorner(ECorner.upLeftBack, 0),
  CCorner(ECorner.upBackRight, 0),
  CCorner(ECorner.downLeftFront, 0),
  CCorner(ECorner.downBackLeft, 0),
  CCorner(ECorner.downRightBack, 0),
  CCorner(ECorner.downFrontRight, 0),
];
final List<CEdge> _edgeD = [
  CEdge(EEdge.upRight, 0),
  CEdge(EEdge.upFront, 0),
  CEdge(EEdge.upLeft, 0),
  CEdge(EEdge.upBack, 0),
  CEdge(EEdge.downFront, 0),
  CEdge(EEdge.downLeft, 0),
  CEdge(EEdge.downBack, 0),
  CEdge(EEdge.downRight, 0),
  CEdge(EEdge.frontRight, 0),
  CEdge(EEdge.frontLeft, 0),
  CEdge(EEdge.backLeft, 0),
  CEdge(EEdge.backRight, 0),
];

final List<CCorner> _cornerL = [
  CCorner(ECorner.upRightFront, 0),
  CCorner(ECorner.upLeftBack, 1),
  CCorner(ECorner.downBackLeft, 2),
  CCorner(ECorner.upBackRight, 0),
  CCorner(ECorner.downFrontRight, 0),
  CCorner(ECorner.upFrontLeft, 2),
  CCorner(ECorner.downLeftFront, 1),
  CCorner(ECorner.downRightBack, 0),
];
final List<CEdge> _edgeL = [
  CEdge(EEdge.upRight, 0),
  CEdge(EEdge.upFront, 0),
  CEdge(EEdge.backLeft, 0),
  CEdge(EEdge.upBack, 0),
  CEdge(EEdge.downRight, 0),
  CEdge(EEdge.downFront, 0),
  CEdge(EEdge.frontLeft, 0),
  CEdge(EEdge.downBack, 0),
  CEdge(EEdge.frontRight, 0),
  CEdge(EEdge.upLeft, 0),
  CEdge(EEdge.downLeft, 0),
  CEdge(EEdge.backRight, 0),
];

final List<CCorner> _cornerB = [
  CCorner(ECorner.upRightFront, 0),
  CCorner(ECorner.upFrontLeft, 0),
  CCorner(ECorner.upBackRight, 1),
  CCorner(ECorner.downRightBack, 2),
  CCorner(ECorner.downFrontRight, 0),
  CCorner(ECorner.downLeftFront, 0),
  CCorner(ECorner.upLeftBack, 2),
  CCorner(ECorner.downBackLeft, 1),
];
final List<CEdge> _edgeB = [
  CEdge(EEdge.upRight, 0),
  CEdge(EEdge.upFront, 0),
  CEdge(EEdge.upLeft, 0),
  CEdge(EEdge.backRight, 1),
  CEdge(EEdge.downRight, 0),
  CEdge(EEdge.downFront, 0),
  CEdge(EEdge.downLeft, 0),
  CEdge(EEdge.backLeft, 1),
  CEdge(EEdge.frontRight, 0),
  CEdge(EEdge.frontLeft, 0),
  CEdge(EEdge.upBack, 1),
  CEdge(EEdge.downBack, 1),
];

final List<(List<CCorner>, List<CEdge>)> _cornerEdges = [
  (_cornerU, _edgeU),
  (_cornerR, _edgeR),
  (_cornerF, _edgeF),
  (_cornerD, _edgeD),
  (_cornerL, _edgeL),
  (_cornerB, _edgeB),
];

// we store the six possible clockwise 1/4 turn moves in the following array
final moveCube = _cornerEdges
    .map((record) => CubieCube(cornerState: record.$1, edgeState: record.$2))
    .toList(growable: false);
