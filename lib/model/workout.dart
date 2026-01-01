class Workout 
{
  final String name;
  final List<String> exercises;

  const Workout({
    required this.name,
    required this.exercises,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'exercises': exercises,
    };

  factory Workout.fromJson(Map<String, dynamic> json)
  {
    final exercisesRaw = json['exercises'];
    return Workout(
      name: json['name'] as String,
      exercises: (exercisesRaw is List)
        ? exercisesRaw.whereType<String>().toList()
        : <String>[],
    );
  }
}