import "cubie_cube.dart";
import "enums.dart";

// Moves on the cubie level, gives permutation and orientation after the moves U, R, F, D, L, B respectively from a clean cube
// This will be used to compute move tables and the composition rules

// final List<CCorner> _corner = [
//   CCorner(Corner.upRightFront, 0),
//   CCorner(Corner.upFrontLeft, 0),
//   CCorner(Corner.upLeftBack, 0),
//   CCorner(Corner.upBackRight, 0),
//   CCorner(Corner.downFrontRight, 0),
//   CCorner(Corner.downLeftFront, 0),
//   CCorner(Corner.downBackLeft, 0),
//   CCorner(Corner.downRightBack, 0),
// ];
// final List<CEdge> _edge = [
//   CEdge(Edge.upRight, 0),
//   CEdge(Edge.upFront, 0),
//   CEdge(Edge.upLeft, 0),
//   CEdge(Edge.upBack, 0),
//   CEdge(Edge.downRight, 0),
//   CEdge(Edge.downFront, 0),
//   CEdge(Edge.downLeft, 0),
//   CEdge(Edge.downBack, 0),
//   CEdge(Edge.frontRight, 0),
//   CEdge(Edge.frontLeft, 0),
//   CEdge(Edge.backLeft, 0),
//   CEdge(Edge.backRight, 0),
// ];

final List<CCorner> _cornerU = [
  CCorner(Corner.upBackRight, 0),
  CCorner(Corner.upRightFront, 0),
  CCorner(Corner.upFrontLeft, 0),
  CCorner(Corner.upLeftBack, 0),
  CCorner(Corner.downFrontRight, 0),
  CCorner(Corner.downLeftFront, 0),
  CCorner(Corner.downBackLeft, 0),
  CCorner(Corner.downRightBack, 0),
];
final List<CEdge> _edgeU = [
  CEdge(Edge.upBack, 0),
  CEdge(Edge.upRight, 0),
  CEdge(Edge.upFront, 0),
  CEdge(Edge.upLeft, 0),
  CEdge(Edge.downRight, 0),
  CEdge(Edge.downFront, 0),
  CEdge(Edge.downLeft, 0),
  CEdge(Edge.downBack, 0),
  CEdge(Edge.frontRight, 0),
  CEdge(Edge.frontLeft, 0),
  CEdge(Edge.backLeft, 0),
  CEdge(Edge.backRight, 0),
];

final List<CCorner> _cornerR = [
  CCorner(Corner.downFrontRight, 2),
  CCorner(Corner.upFrontLeft, 0),
  CCorner(Corner.upLeftBack, 0),
  CCorner(Corner.upRightFront, 1),
  CCorner(Corner.downRightBack, 1),
  CCorner(Corner.downLeftFront, 0),
  CCorner(Corner.downBackLeft, 0),
  CCorner(Corner.upBackRight, 2),
];
final List<CEdge> _edgeR = [
  CEdge(Edge.frontRight, 0),
  CEdge(Edge.upFront, 0),
  CEdge(Edge.upLeft, 0),
  CEdge(Edge.upBack, 0),
  CEdge(Edge.backRight, 0),
  CEdge(Edge.downFront, 0),
  CEdge(Edge.downLeft, 0),
  CEdge(Edge.downBack, 0),
  CEdge(Edge.downRight, 0),
  CEdge(Edge.frontLeft, 0),
  CEdge(Edge.backLeft, 0),
  CEdge(Edge.upRight, 0),
];

final List<CCorner> _cornerF = [
  CCorner(Corner.upFrontLeft, 1),
  CCorner(Corner.downLeftFront, 2),
  CCorner(Corner.upLeftBack, 0),
  CCorner(Corner.upBackRight, 0),
  CCorner(Corner.upRightFront, 2),
  CCorner(Corner.downFrontRight, 1),
  CCorner(Corner.downBackLeft, 0),
  CCorner(Corner.downRightBack, 0),
];
final List<CEdge> _edgeF = [
  CEdge(Edge.upRight, 0),
  CEdge(Edge.frontLeft, 1),
  CEdge(Edge.upLeft, 0),
  CEdge(Edge.upBack, 0),
  CEdge(Edge.downRight, 0),
  CEdge(Edge.frontRight, 1),
  CEdge(Edge.downLeft, 0),
  CEdge(Edge.downBack, 0),
  CEdge(Edge.upFront, 1),
  CEdge(Edge.downFront, 1),
  CEdge(Edge.backLeft, 0),
  CEdge(Edge.backRight, 0),
];

final List<CCorner> _cornerD = [
  CCorner(Corner.upRightFront, 0),
  CCorner(Corner.upFrontLeft, 0),
  CCorner(Corner.upLeftBack, 0),
  CCorner(Corner.upBackRight, 0),
  CCorner(Corner.downLeftFront, 0),
  CCorner(Corner.downBackLeft, 0),
  CCorner(Corner.downRightBack, 0),
  CCorner(Corner.downFrontRight, 0),
];
final List<CEdge> _edgeD = [
  CEdge(Edge.upRight, 0),
  CEdge(Edge.upFront, 0),
  CEdge(Edge.upLeft, 0),
  CEdge(Edge.upBack, 0),
  CEdge(Edge.downFront, 0),
  CEdge(Edge.downLeft, 0),
  CEdge(Edge.downBack, 0),
  CEdge(Edge.downRight, 0),
  CEdge(Edge.frontRight, 0),
  CEdge(Edge.frontLeft, 0),
  CEdge(Edge.backLeft, 0),
  CEdge(Edge.backRight, 0),
];

final List<CCorner> _cornerL = [
  CCorner(Corner.upRightFront, 0),
  CCorner(Corner.upLeftBack, 1),
  CCorner(Corner.downBackLeft, 2),
  CCorner(Corner.upBackRight, 0),
  CCorner(Corner.downFrontRight, 0),
  CCorner(Corner.upFrontLeft, 2),
  CCorner(Corner.downLeftFront, 1),
  CCorner(Corner.downRightBack, 0),
];
final List<CEdge> _edgeL = [
  CEdge(Edge.upRight, 0),
  CEdge(Edge.upFront, 0),
  CEdge(Edge.backLeft, 0),
  CEdge(Edge.upBack, 0),
  CEdge(Edge.downRight, 0),
  CEdge(Edge.downFront, 0),
  CEdge(Edge.frontLeft, 0),
  CEdge(Edge.downBack, 0),
  CEdge(Edge.frontRight, 0),
  CEdge(Edge.upLeft, 0),
  CEdge(Edge.downLeft, 0),
  CEdge(Edge.backRight, 0),
];

final List<CCorner> _cornerB = [
  CCorner(Corner.upRightFront, 0),
  CCorner(Corner.upFrontLeft, 0),
  CCorner(Corner.upBackRight, 1),
  CCorner(Corner.downRightBack, 2),
  CCorner(Corner.downFrontRight, 0),
  CCorner(Corner.downLeftFront, 0),
  CCorner(Corner.upLeftBack, 2),
  CCorner(Corner.downBackLeft, 1),
];
final List<CEdge> _edgeB = [
  CEdge(Edge.upRight, 0),
  CEdge(Edge.upFront, 0),
  CEdge(Edge.upLeft, 0),
  CEdge(Edge.backRight, 1),
  CEdge(Edge.downRight, 0),
  CEdge(Edge.downFront, 0),
  CEdge(Edge.downLeft, 0),
  CEdge(Edge.backLeft, 1),
  CEdge(Edge.frontRight, 0),
  CEdge(Edge.frontLeft, 0),
  CEdge(Edge.upBack, 1),
  CEdge(Edge.downBack, 1),
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
