import 'package:flutter/material.dart';

import 'plot_spec.dart';
import 'plot_data.dart';
import 'plot_2d_view.dart';
import 'plot_3d_view.dart';

class PlotView extends StatelessWidget {
  final PlotSpec spec;
  final PlotData data;

  const PlotView({
    super.key,
    required this.spec,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    if (spec.is2D) {
      return Plot2DView(
        spec: spec,
        data: data,
      );
    } else {
      return Plot3DView(
        spec: spec,
        data: data,
      );
    }
  }
}