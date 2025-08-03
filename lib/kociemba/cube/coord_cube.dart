import "cubie_cube.dart";
import "../tables.dart";

class CoordCube {
  int twist;
  int flip;
  int udslice;
  int edge4;
  int edge8;
  int corner;

  CoordCube({
    this.twist = 0,
    this.flip = 0,
    this.udslice = 0,
    this.edge4 = 0,
    this.edge8 = 0,
    this.corner = 0,
  });

  factory CoordCube.fromCubieCube(CubieCube cube) {
    return CoordCube(
      twist: cube.twist,
      flip: cube.flip,
      udslice: cube.udslice,
      edge4: cube.edge4,
      edge8: cube.edge8,
      corner: cube.corner,
    );
  }

  /// Update all coordinates after applying move [mv] using the move tables
  ///
  /// [mv] representing one of 18 non-identity face turns,
  /// calculating as 3 * i + j where i = 0, 1, 2, 3, 4, 5 for U, R, F, D, L, B respectively,
  /// and j = 0, 1, 2 for quarter turn clockwise, half turn and quarter turn anticlockwise respectively
  void move(int mv) {
    twist = Table().twistMove[twist][mv];
    flip = Table().flipMove[flip][mv];
    udslice = Table().udsliceMove[udslice][mv];
    edge4 = Table().edge4Move[edge4][mv];
    edge8 = Table().edge8Move[edge8][mv];
    corner = Table().cornerMove[corner][mv];
  }
}
