class Strings {
  // Login Screen Strings
  static const String loginTitle = 'Login';
  static const String mobileNumberHint = 'Email ID / Phone Number';
  static const String passcodeHint = 'Passcode (4 Digits)';
  static const String forgotPassword = 'Forgot Passcode (4 Digits)?';
  static const String loginButton = 'Login';
  static const String editProfileButton = 'Edit Profile';
  static const String createAccountPrompt = "Don't have an account? ";
  static const String createAccount = 'Create your Account';

  // SignUp Confirmation Screen Strings
  static const String confirmationMessage =
      'Your information is successfully submitted!';
  static const String emailUpdateMessage =
      "Your account will be created once it's confirmed by the site admin. You'll receive an email shortly with updates.";
  static const String closeButton = 'Close';

  // Create Account Screen Strings
  static const String createAccountTitle = 'Create your Account';
  static const String nameHint = 'Name';
  static const String ageHint = 'Age';
  static const String genderHint = 'Gender';
  static const String ospreferenceHint = 'OS Preferece';
  static const String designationHint = 'Designation';
  static const String departmentHint = 'Department';
  static const String emailHint = 'Email ID';
  static const String phoneHint = 'Phone Number';
  static const String passcodeHintCreate = 'Passcode (4 Digit)';
  static const String confirmPasscodeHint = 'Confirm Passcode (4 Digit)';
  static const String createAccountButton = 'Create Account';
  static const String alreadyHaveAccount = "Already have an account? ";
  static const String loginText = 'Login';

  // Existing Strings...

  // Profile Screen Strings
  static const String profileTitle = 'Profile';
  static const String profileName = 'Dr. Rohit Sharma';
  static const String profileRank = 'Rank: 8';
  static const String profilePoints = '725 points';
  static const String nameHints = 'Rohit Sharma';
  static const String designationHints = 'Cardiologist';
  static const String departmentHints = 'Cardiology';
  static const String emailHints = 'rohitsharma@email.com';
  static const String phoneHints = '9985412447';
  static const String updatePasswordButton = 'Update Passcode';
  static const String updateProfileButton = 'Update Profile';
  static const String logoutButton = 'Logout';

  static const String changePasswordTitle = "Change Passcode";
  static const String oldPasswordHint = "Old Passcode (4 Digit)";
  static const String newPasswordHint = "New Passcode (4 Digit)";
  static const String confirmPasswordHint = "Confirm New Passcode (4 Digit)";

  // Feedback Screen Strings
  static const String feedbackTitle = "Feedback";
  static const String messageLabel = "Message";
  static const String enterMessageHint = "Enter Feedback";
  static const String submitButton = "Send Feedback";

  // Logout Confirmation Popup Strings
  static const String logoutConfirmationTitle = "Logout Confirmation";
  static const String logoutConfirmationMessage =
      "Are you sure you want to logout from the app?";
  static const String noButton = "No";
  static const String yesButton = "Yes";

  static const String updateProfile = "Update Profile";

  static String changePasswordButton = "Change Password";

  // Condition List Screen Strings
  static const String noConditionsMessage = "No data available.";
  static const String compliancePopupTitle = "Compliance Confirmation";
  static const String compliancePopupMessage =
      "Would you consider prescribing based on the app's suggestion?";
  static const String noButtonLabel = "No";
  static const String yesButtonLabel = "Yes";
  static const String reasonPopupTitle = "Please provide a reason";
  static const String reasonOption1 =
      "Not aligned with current antimicrobial stewardship guidelines";
  static const String reasonOption2 =
      "Medicine not currently available or approved";
  static const String reasonOption3 = "High cost or budget constraints";
  static const String reasonOption4 =
      "Lack of necessary resources or infrastructure";
  static const String reasonOption5 = "Other";
  static const String reasonPlaceholder = "Reason";
  static const String closeButtonLabel = "Close";
  static const String submitButtonLabel = "Submit";
  static const String messageFieldLabel = "Enter your message";

  // static String baseUrl = 'http://10.10.2.184:8001/api/';
  // static String baseUrl = 'http://10.10.2.170:8000/api/';

  // Staging
  static String baseUrl = 'http://10.144.210.217:8000/api/';
  // static String baseUrl = 'http://52.66.245.19:8000/';

  static const String keycloakUrl = 'http://10.10.5.55:3000/';

  //Nomnom
  // static String baseUrl = 'https://amsp-be.nomnom.net.in/api/';
  // static const String keycloakUrl = 'https://keycloak-amsp.nomnom.net.in/';

  // St Johns
  // static String baseUrl = 'https://backend-icmr.stjohns.in/api/';
  // static const String keycloakUrl = 'https://frontend-icmr.stjohns.in/';

  static const String clientId = 'frontend';
  static const String realm = 'AMSP';
  static const String grantType = 'password';

  static const String oneSignalId = "22843b18-42cb-4bb2-b52b-7fd1c37293b5";

  /// 🔹 Helper to detect environment based on baseUrl
  static String get environment {
    if (baseUrl.contains("10.10.5.55")) {
      return "staging";
    }
    return "production";
  }
}
