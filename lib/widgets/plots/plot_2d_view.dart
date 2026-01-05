import 'package:flutter/material.dart';

import 'plot_spec.dart';
import 'plot_data.dart';
import 'plot_axis.dart';

class Plot2DView extends StatelessWidget {
  final PlotSpec spec;
  final PlotData data;

  const Plot2DView({
    super.key,
    required this.spec,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    // Real rendering comes later
    return Center(
      child: Text(
        '2D Plot\n'
        '${spec.exercise}\n'
        'X: ${spec.xAxis.label}, Y: ${spec.yAxis.label}\n'
        'Points: ${data.points2D?.length ?? 0}',
        textAlign: TextAlign.center,
      ),
    );
  }
}