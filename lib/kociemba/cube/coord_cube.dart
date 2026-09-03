import "cubie_cube.dart";

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

}
