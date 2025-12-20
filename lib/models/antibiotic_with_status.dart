import 'package:qr_scanner_app/models/antibiotic.dart';

class AntibioticWithStatus {
  final Antibiotic antibiotic;
  final bool bookmarked;
  final String connection;

  AntibioticWithStatus({
    required this.antibiotic,
    required this.bookmarked,
    required this.connection,
  });

  // Factory constructor to create an instance from JSON
  factory AntibioticWithStatus.fromJson(Map<String, dynamic> json) {
    // Check if 'antibiotic' is null
    if (json['antibiotic'] == null) {
      throw Exception("Antibiotic data is null");
    }

    return AntibioticWithStatus(
      antibiotic: Antibiotic.fromJson(json['antibiotic'] as Map<String,
          dynamic>), // Assuming 'antibiotic' is the key in your JSON
      bookmarked: json['bookmarked'] as bool,
      connection: json['connection'] as String,
    );
  }

  // Implementing the copyWith method
  AntibioticWithStatus copyWith({
    Antibiotic? antibiotic,
    bool? bookmarked,
    String? connection,
  }) {
    return AntibioticWithStatus(
      antibiotic: antibiotic ?? this.antibiotic,
      bookmarked: bookmarked ?? this.bookmarked,
      connection: connection ?? this.connection,
    );
  }

  // Overriding the toString method
  @override
  String toString() {
    return 'AntibioticWithStatus(antibiotic: ${antibiotic.toString()}, bookmarked: $bookmarked, connection: $connection)';
  }
}
