enum PlotAxis {
  date,
  weight,
  reps,
  sets,
}

extension PlotAxisLabel on PlotAxis {
  String get label {
    switch (this) {
      case PlotAxis.date:
        return 'Date';
      case PlotAxis.weight:
        return 'Weight';
      case PlotAxis.reps:
        return 'Reps';
      case PlotAxis.sets:
        return 'Sets';
    }
  }
}