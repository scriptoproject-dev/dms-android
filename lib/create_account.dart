import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/input_validators/email_validator.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/models/department.dart';
import 'package:qr_scanner_app/models/site_data.dart';
import 'package:qr_scanner_app/models/user_register_request.dart';
import 'package:qr_scanner_app/models/user_register_response.dart';
import 'package:qr_scanner_app/routes.dart';
import 'package:qr_scanner_app/styles.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  CreateAccountScreenState createState() => CreateAccountScreenState();
}

class CreateAccountScreenState extends State<CreateAccountScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  bool _obscurePasscode = true;
  bool _obscureConfirmPasscode = true;
  bool _isFormSubmitted = false;
  bool _showDepartmentError = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passcodeController = TextEditingController();
  final TextEditingController _confirmPasscodeController =
      TextEditingController();

  String? _selectedGender;
  String? _selectedInstitution;
  String? _selectedDepartment;
  String? _selectedDesignation;
  String? _selectedDepartmentId;
  String? _selectedOsPreference;

  final List<String> _genders = ["Male", "Female", "Others"];
  final List<String> _osPreferences = ["ios", "android"];
  final List<String> _designations = [
    "Post Graduate",
    "Senior Resident",
    "Assistant / Associate Professor",
    "Professor"
  ];

  final Map<String, String> _designationBackendValues = {
    "Post Graduate": "post_graduate",
    "Senior Resident": "senior_resident",
    "Assistant / Associate Professor": "asst_professor",
    "Professor": "professor"
  };

  List<SiteData> _institutions = [];
  bool loadingInstitutions = true;

  @override
  void initState() {
    super.initState();
    // _fetchInstitutions();
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  Future<UserRegisterResponse?> registerUser(
      RegisterRequest registerRequest) async {
    final baseUrl = Strings.baseUrl;
    try {
      final updatedRequest = RegisterRequest(
          name: registerRequest.name,
          email: registerRequest.email,
          age: registerRequest.age,
          gender: registerRequest.gender,
          phoneNumber: registerRequest.phoneNumber,
          passcode: registerRequest.passcode,
          departmentId:
              _selectedDepartmentId ?? "", // Pass the updated departmentId
          // designation: registerRequest.designation,
          designation: _designationBackendValues[_selectedDesignation] ?? "",
          siteId: _institutions
              .firstWhere((inst) => inst.name == _selectedInstitution)
              .siteId,
          // siteId: registerRequest.siteId,
          role: registerRequest.role,
          osPreference: registerRequest.osPreference);

      final response = await ApiClient(baseUrl: baseUrl)
          .post('users/register', body: updatedRequest.toJson());
      if (response.statusCode == 201) {
        debugPrint("register user success- ${response.body}");
        final jsonResponse = json.decode(response.body);
        return UserRegisterResponse.fromJson(jsonResponse['data']);
      } else if (response.statusCode == 400 &&
          response.body.contains("Phone number already exists")) {
        _showToast("Phone number already exists");
      } else if (response.statusCode == 400 &&
          response.body.contains("Email already exists")) {
        _showToast("Email already exists");
      } else if (response.statusCode == 400 &&
          response.body.contains(
              "This phone number is already registered. Please use a different phone number.")) {
        _showToast("Phone number already exists");
      } else if (response.statusCode == 400 &&
          response.body.contains(
              "This email is already registered. Please use a different email.")) {
        _showToast("Email already exists");
      } else {
        debugPrint(
            'Registration failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error during registration: $e');
      return null;
    }
    return null;
  }

  Future<void> _fetchInstitutions() async {
    final String baseUrl = Strings.baseUrl;
    const String endpoint = "sites?status=active"; // Replace with your endpoint

    final Uri url = Uri.parse('$baseUrl$endpoint');

    try {
      // Direct HTTP GET request
      final response = await http.get(url);

      // Debugging: Print the API response
      debugPrint('API Response sites: ${response.body}');

      if (response.statusCode == 200) {
        // Parse the response if it's successful
        final Map<String, dynamic> jsonData = json.decode(response.body);
        debugPrint("institution jsonData--$jsonData");

        // Check if 'data' is present and is a List
        if (jsonData['data'] != null && jsonData['data'] is List) {
          if (jsonData['data'] is List) {
            setState(() {
              _institutions = (jsonData['data'] as List)
                  .map((data) => SiteData.fromJson(data))
                  .toList();
              loadingInstitutions = false;
            });
            debugPrint("Institutions: $_institutions");
          } else {
            debugPrint('Data is not a list: ${jsonData['data']}');
            _showToast('Data is not in the expected format.');
          }
        } else {
          debugPrint('Data field is null.');
          _showToast('No institutions found.');
        }
      } else {
        // Handle non-200 responses
        debugPrint('Error: ${response.statusCode}, ${response.body}');
        _showToast(
            'Failed to fetch institutions. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      // Handle exceptions
      debugPrint('Exception occurred institution: $e');
      _showToast('An error occurred while fetching institutions: $e');
    }
  }

  void _showBottomSheet(List<String> items, String title, String? selectedItem,
      Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Transparent background for modal
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true, // Allows the modal to resize based on content
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white, // White background for content
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 180, // Set a fixed height for the list
                child: Scrollbar(
                  thumbVisibility: true, // Always show the scrollbar
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return RadioListTile<String>(
                        value: items[index],
                        groupValue: selectedItem,
                        onChanged: (value) {
                          onSelect(value!);
                          Navigator.pop(
                              context); // Close the sheet on selection
                        },
                        title: Text(items[index]),
                        controlAffinity: ListTileControlAffinity
                            .trailing, // Align radio button to the right
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<Department>> fetchDepartments(String siteId) async {
    final String baseUrl = Strings.baseUrl;
    final String endpoint =
        "departments/$siteId"; // Use the API path for departments

    final Uri url = Uri.parse('$baseUrl$endpoint?status=active');

    try {
      final response = await http.get(url);
      debugPrint('API Response for departmet: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        if (jsonData['data'] != null && jsonData['data'] is List) {
          return (jsonData['data'] as List)
              .map((data) => Department.fromJson(data))
              .toList();
        } else {
          debugPrint('No departments found in response.');
          return [];
        }
      } else {
        debugPrint(
            'Error fetching departments: ${response.statusCode}, ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Exception occurred while fetching departments: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            autovalidateMode: _isFormSubmitted
                ? AutovalidateMode
                    .onUserInteraction // Only show errors after submission
                : AutovalidateMode
                    .disabled, // Auto-validation on user interaction
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  Strings.createAccountTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 24),

                // Name TextField
                TextFormField(
                  controller: _nameController,
                  decoration: CustomStyles.textFieldDecoration.copyWith(
                    labelText: Strings.nameHint,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp('[a-zA-Z ]')), // Allow alphabets and spaces
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                  autovalidateMode: AutovalidateMode
                      .onUserInteraction, // Trigger validation on user interaction
                  onChanged: (value) {
                    setState(() {
                      // Trigger a rebuild to remove the validation error as soon as the user starts typing
                    });
                  },
                ),
                const SizedBox(height: 24),

                // Age TextField
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: CustomStyles.textFieldDecoration.copyWith(
                    labelText: Strings.ageHint,
                  ),
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(3), // Limit to 3 digits
                    FilteringTextInputFormatter.digitsOnly, // Allow only digits
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Age is required';
                    }
                    if (int.tryParse(value) == null || int.parse(value) <= 0) {
                      return 'Please enter a valid age';
                    }
                    return null;
                  },
                  autovalidateMode: AutovalidateMode
                      .onUserInteraction, // Trigger validation on user interaction
                  onChanged: (value) {
                    setState(() {
                      // Trigger a rebuild to remove the validation error as soon as the user starts typing
                    });
                  },
                ),
                const SizedBox(height: 24),

                // Gender Dropdown
                GestureDetector(
                  onTap: () async {
                    FocusScope.of(context).unfocus();
                    _showBottomSheet(
                      _genders,
                      "Select Gender",
                      _selectedGender,
                      (value) {
                        setState(() => _selectedGender = value);
                        FocusScope.of(context)
                            .requestFocus(FocusNode()); // Prevent focus change
                      },
                    );
                  },
                  child: InputDecorator(
                    decoration: CustomStyles.textFieldDecoration.copyWith(
                      labelText: _selectedGender == null ? null : "Gender",
                      hintText: _selectedGender ?? Strings.genderHint,
                      suffixIcon: Image.asset(
                        'assets/images/dropdown.png',
                        width: 24,
                        height: 24,
                      ),
                      errorText: _isFormSubmitted && _selectedGender == null
                          ? 'Please select a gender'
                          : null,
                    ),
                    child: Text(
                      _selectedGender ?? "Gender",
                      style: TextStyle(
                        color: _selectedGender == null ? gray : Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Institution Dropdown

                GestureDetector(
                  onTap: () async {
                    debugPrint(
                        "Fetching institutions before showing bottom sheet...");

                    await _fetchInstitutions(); // Fetch institutions dynamically when tapped

                    if (_institutions.isEmpty) {
                      _showToast("No active institutions available.");
                      return;
                    }

                    debugPrint(
                        "Selected Institution Before Bottom Sheet: $_selectedInstitution");

                    _showBottomSheet(
                      _institutions.map((e) => e.name).toList(),
                      "Select Institution",
                      _selectedInstitution,
                      (value) {
                        setState(() {
                          _selectedInstitution = value;
                          _selectedDepartment = null; // Reset department
                          _showDepartmentError =
                              false; // Remove the error message
                          FocusScope.of(context).requestFocus(FocusNode());
                        });
                        debugPrint(
                            "Selected Institution: $_selectedInstitution");
                      },
                    );
                  },
                  child: InputDecorator(
                    decoration: CustomStyles.textFieldDecoration.copyWith(
                      labelText: _selectedInstitution == null
                          ? null
                          : "Institution Name",
                      hintText: _selectedInstitution ?? "Institution Name",
                      suffixIcon: Image.asset(
                        'assets/images/dropdown.png',
                        width: 24,
                        height: 24,
                      ),
                      errorText:
                          _isFormSubmitted && _selectedInstitution == null
                              ? 'Please select an institution'
                              : null,
                    ),
                    child: Text(
                      _selectedInstitution ?? "Institution Name",
                      style: TextStyle(
                        color:
                            _selectedInstitution == null ? gray : Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Inside the GestureDetector for the department dropdown
                // Inside the GestureDetector for the department dropdown
                // Inside the GestureDetector for the department dropdown
                GestureDetector(
                  onTap: () async {
                    if (_selectedInstitution == null) {
                      setState(() {
                        _selectedDepartment = null; // Reset department
                        _showDepartmentError = true;
                      });
                      // ScaffoldMessenger.of(context).showSnackBar(
                      //   const SnackBar(
                      //     content: Text('Please select an institution first.'),
                      //   ),
                      // );
                    } else {
                      setState(() {
                        _showDepartmentError = false;
                      });

                      // Fetch departments based on selected institution
                      final siteId = _institutions
                          .firstWhere(
                              (inst) => inst.name == _selectedInstitution)
                          .siteId; // Assuming the institution has a siteId field
                      List<Department> departments =
                          await fetchDepartments(siteId);

                      if (departments.isEmpty) {
                        setState(() {
                          _selectedDepartment = null; // Reset department
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'No departments found for this institution.')),
                        );
                      } else {
                        // Show department options if departments are fetched successfully
                        _showBottomSheet(
                          departments.map((e) => e.name).toList(),
                          "Select Department",
                          _selectedDepartment,
                          (value) {
                            setState(() {
                              // Set the selected department name
                              _selectedDepartment = value;
                              // Get the department ID corresponding to the selected name
                              final selectedDepartment = departments
                                  .firstWhere((dept) => dept.name == value);
                              // Store the department ID
                              _selectedDepartmentId =
                                  selectedDepartment.departmentId;
                            });
                            FocusScope.of(context).requestFocus(
                                FocusNode()); // Prevent focus change
                          },
                        );
                      }
                    }
                  },
                  child: Column(
                    children: [
                      InputDecorator(
                        decoration: CustomStyles.textFieldDecoration.copyWith(
                          labelText:
                              _selectedDepartment == null ? null : "Department",
                          hintText: _selectedDepartment ?? "Department",
                          suffixIcon: Image.asset(
                            'assets/images/dropdown.png',
                            width: 24,
                            height: 24,
                          ),
                          errorText: _showDepartmentError
                              ? 'Please select an institution first.'
                              : _isFormSubmitted && _selectedDepartment == null
                                  ? 'Please select a department'
                                  : null,
                          // errorStyle:
                          //     TextStyle(fontSize: 12, color: Colors.red),
                        ),
                        child: Text(
                          _selectedDepartment ?? "Department",
                          style: TextStyle(
                            color: _selectedDepartment == null
                                ? gray
                                : Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Designation Dropdown
                GestureDetector(
                  onTap: () => _showBottomSheet(
                    _designations,
                    "Select Designation",
                    _selectedDesignation,
                    (value) {
                      setState(() => _selectedDesignation = value);
                      FocusScope.of(context)
                          .requestFocus(FocusNode()); // Prevent focus change
                    },
                  ),
                  child: InputDecorator(
                    decoration: CustomStyles.textFieldDecoration.copyWith(
                      labelText:
                          _selectedDesignation == null ? null : "Designation",
                      hintText: _selectedDesignation ?? "Designation",
                      suffixIcon: Image.asset(
                        'assets/images/dropdown.png',
                        width: 24,
                        height: 24,
                      ),
                      errorText:
                          _isFormSubmitted && _selectedDesignation == null
                              ? 'Please select a designation'
                              : null,
                    ),
                    child: Text(
                      _selectedDesignation ?? "Designation",
                      style: TextStyle(
                        color:
                            _selectedDesignation == null ? gray : Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: CustomStyles.textFieldDecoration.copyWith(
                    labelText: Strings.emailHint,
                  ),
                  validator: (value) {
                    return validateEmail(value);
                  },
                  autovalidateMode: AutovalidateMode
                      .onUserInteraction, // Trigger validation on user interaction
                  onChanged: (value) {
                    setState(() {
                      // Trigger a rebuild to remove the validation error as soon as the user starts typing
                    });
                  },
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: CustomStyles.textFieldDecoration.copyWith(
                    labelText: Strings.phoneHint,
                  ),
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(10), // Limit to 10 digits
                    FilteringTextInputFormatter.digitsOnly, // Allow only digits
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Phone number is required';
                    }
                    if (!RegExp(r'^[0-9]{10}$').hasMatch(value)) {
                      return 'Please enter a valid phone number';
                    }
                    return null;
                  },
                  autovalidateMode: AutovalidateMode
                      .onUserInteraction, // Trigger validation on user interaction
                  onChanged: (value) {
                    setState(() {
                      // Trigger a rebuild to remove the validation error as soon as the user starts typing
                    });
                  },
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => _showBottomSheet(
                    _osPreferences,
                    "Select OS preference",
                    _selectedOsPreference,
                    (value) {
                      setState(() => _selectedOsPreference = value);
                      FocusScope.of(context)
                          .requestFocus(FocusNode()); // Prevent focus change
                    },
                  ),
                  child: InputDecorator(
                    decoration: CustomStyles.textFieldDecoration.copyWith(
                      labelText: _selectedOsPreference == null
                          ? null
                          : "OS preference",
                      hintText:
                          _selectedOsPreference ?? Strings.ospreferenceHint,
                      suffixIcon: Image.asset(
                        'assets/images/dropdown.png',
                        width: 24,
                        height: 24,
                      ),
                      errorText:
                          _isFormSubmitted && _selectedOsPreference == null
                              ? 'Please select an OS preference'
                              : null,
                    ),
                    child: Text(
                      _selectedOsPreference ?? "OS preference",
                      style: TextStyle(
                        color:
                            _selectedOsPreference == null ? gray : Colors.black,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                // Passcode TextFormField
                TextFormField(
                  controller: _passcodeController,
                  keyboardType: TextInputType.number,
                  obscureText: _obscurePasscode,
                  decoration: CustomStyles.textFieldDecoration.copyWith(
                    labelText: Strings.passcodeHintCreate,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePasscode
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: gray,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePasscode = !_obscurePasscode;
                        });
                      },
                    ),
                  ),
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(4), // Limit to 10 digits
                    FilteringTextInputFormatter.digitsOnly, // Allow only digits
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Passcode is required';
                    }
                    if (value.length < 4) {
                      return 'Passcode must be at least 4 characters';
                    }
                    return null;
                  },
                  autovalidateMode: AutovalidateMode
                      .onUserInteraction, // Trigger validation on user interaction
                  onChanged: (value) {
                    setState(() {
                      // Trigger a rebuild to remove the validation error as soon as the user starts typing
                    });
                  },
                ),
                const SizedBox(height: 24),

                // Confirm Passcode TextField with Eye Icon
                TextFormField(
                  controller: _confirmPasscodeController,
                  obscureText: _obscureConfirmPasscode,
                  keyboardType: TextInputType.number,
                  decoration: CustomStyles.textFieldDecoration.copyWith(
                    labelText: Strings.confirmPasscodeHint,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPasscode
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: gray,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPasscode = !_obscureConfirmPasscode;
                        });
                      },
                    ),
                  ),
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(4), // Limit to 10 digits
                    FilteringTextInputFormatter.digitsOnly, // Allow only digits
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirm Passcode is required';
                    }
                    if (value != _passcodeController.text) {
                      return 'Passcodes do not match';
                    }
                    if (value.length < 4) {
                      return 'Passcode must be at least 4 characters';
                    }
                    return null;
                  },
                  autovalidateMode: AutovalidateMode
                      .onUserInteraction, // Trigger validation on user interaction
                  onChanged: (value) {
                    setState(() {
                      // Trigger a rebuild to remove the validation error as soon as the user starts typing
                    });
                  },
                ),

                const SizedBox(height: 40),

                // Create Account Button
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          FocusScope.of(context).unfocus();
                          setState(() {
                            // Trigger validation on button press
                            // _isFormValid = true;
                            _isFormSubmitted = true;
                            _isLoading = true;
                          });
                          // Validate the form
                          if (!_formKey.currentState!.validate()) {
                            setState(() => _isLoading = false);
                            return; // If validation fails, do not proceed
                          }

                          // Check passcode confirmation
                          if (_passcodeController.text !=
                              _confirmPasscodeController.text) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Passcodes do not match!')),
                            );
                            setState(() => _isLoading = false);
                            return;
                          }

                          //Nayan Added tis for validation and enable the button
                          if (_selectedInstitution == null ||
                              _selectedDepartment == null ||
                              _selectedDesignation == null ||
                              _selectedGender == null ||
                              _selectedOsPreference == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Please fill all required fields.')),
                            );
                            setState(() => _isLoading = false);
                            return;
                          }

                          debugPrint('_institutions: $_institutions');
                          print(_institutions.map((e) => e.name).toList());

                          final site = _institutions.firstWhere(
                            (inst) => inst.name == _selectedInstitution,
                            orElse: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Selected institution not found.')),
                              );
                              // fallback to first entry (or throw), adjust as you like:
                              return _institutions.first;
                            },
                          );

                          //nayan

                          final registerRequest = RegisterRequest(
                            name: _nameController.text.trim(),
                            email: _emailController.text.trim(),
                            age: _ageController.text.trim(),
                            gender: _selectedGender ?? "",
                            osPreference: _selectedOsPreference ?? "",
                            phoneNumber: _phoneController.text.trim(),
                            passcode: _passcodeController.text.trim(),
                            departmentId: _selectedDepartment ?? "",
                            designation: _selectedDesignation ?? "",
                            siteId: _institutions
                                .firstWhere(
                                    (inst) => inst.name == _selectedInstitution)
                                .siteId,
                          );

                          // Call API
                          final user = await registerUser(registerRequest);

                          setState(() {
                            _isLoading = false; //Re-enable the button
                          });

                          if (user != null) {
                            debugPrint('User Registered: ${user.name}');
                            Navigator.pushNamed(
                                context, Routes.signupConfirmation);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Registration failed. Please try again.')),
                            );
                          }
                        },
                  style: CustomStyles.elevatedButtonStyle,
                  child: const Text(
                    Strings.createAccountButton,
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
                const SizedBox(height: 24),

                // Already have an account? Login Text with Underline
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, Routes.login);
                    },
                    child: const Text.rich(
                      TextSpan(
                        text: Strings.alreadyHaveAccount,
                        children: [
                          TextSpan(
                            text: Strings.loginText,
                            style: TextStyle(
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.bold,
                                decorationColor: primaryColor,
                                color: primaryColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
