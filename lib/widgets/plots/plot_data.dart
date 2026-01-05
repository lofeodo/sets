class PlotPoint2D {
  final double x;
  final double y;

  const PlotPoint2D(this.x, this.y);
}

class PlotPoint3D {
  final double x;
  final double y;
  final double z;

  const PlotPoint3D(this.x, this.y, this.z);
}

class PlotData {
  final List<PlotPoint2D>? points2D;
  final List<PlotPoint3D>? points3D;

  const PlotData._({
    this.points2D,
    this.points3D,
  });

  factory PlotData.twoD(List<PlotPoint2D> points) {
    return PlotData._(points2D: points);
  }

  factory PlotData.threeD(List<PlotPoint3D> points) {
    return PlotData._(points3D: points);
  }
}