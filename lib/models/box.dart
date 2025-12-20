class BoxModel {
  final String box_id;
  final String name;

  BoxModel({
    required this.box_id,
    required this.name,
  });

  factory BoxModel.fromJson(Map<String, dynamic> json) {
    return BoxModel(
      box_id: json['box_id']?.toString() ?? '', // change keys to match API
      name: json['name'] ?? '',
    );
  }
}
