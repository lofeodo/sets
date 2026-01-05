import 'plot_axis.dart';

class PlotSpec {
  final String exercise;
  final PlotAxis xAxis;
  final PlotAxis yAxis;
  final PlotAxis? zAxis;

  const PlotSpec({
    required this.exercise,
    required this.xAxis,
    required this.yAxis,
    this.zAxis,
  });

  bool get is2D => zAxis == null;
  bool get is3D => zAxis != null;
}