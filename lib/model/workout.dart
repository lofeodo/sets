class Workout 
{
  final String name;
  const Workout({required this.name});

  Map<String, dynamic> toJson() => {'name': name};

  factory Workout.fromJson(Map<String, dynamic> json)
  {
    return Workout(name: json['name'] as String);
  }
}