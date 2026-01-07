import 'package:flutter/material.dart';

import 'plot_spec.dart';
import 'plot_data.dart';
import 'plot_axis.dart';

class Plot3DView extends StatelessWidget {
  final PlotSpec spec;
  final PlotData data;

  const Plot3DView({
    super.key,
    required this.spec,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Interactive 3D plots coming soon.'
      ),
    );
  }
}