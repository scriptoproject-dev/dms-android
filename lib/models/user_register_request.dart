class RegisterRequest {
  final String name;
  final String email;
  final String age;
  final String gender;
  final String phoneNumber;
  final String passcode;
  final String departmentId;
  final String designation;
  final String siteId;
  final String role;
  final String osPreference;

  RegisterRequest(
      {required this.name,
      required this.email,
      this.age = "",
      this.gender = "",
      required this.phoneNumber,
      required this.passcode,
      required this.departmentId,
      required this.designation,
      required this.siteId,
      this.role = "CL",
      required this.osPreference});

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "email": email,
      "age": age,
      "gender": gender,
      "phone_number": phoneNumber,
      "passcode": passcode,
      "department_id": departmentId,
      "designation": designation,
      "site_id": siteId,
      "role": role,
      "os_preference": osPreference,
    };
  }
}
