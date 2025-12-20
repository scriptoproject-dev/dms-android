class UserLoginResponse {
  late AuthData? authData;
  late String? userId;
  late String? name;
  late String? siteId;
  late String? siteName;
  late String? role;
  late bool temporaryPasscode;

  UserLoginResponse(
      {required this.authData,
      this.userId,
      this.siteId,
      this.name,
      required this.temporaryPasscode});

  UserLoginResponse.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('auth_data')) {
      authData = AuthData.fromJson(json['auth_data']);
    } else {
      authData = null; // Set to null if not present
    }
    userId = json['user_id'];
    name = json['name'];
    siteId = json['site_id'];
    siteName = json['site_name'];
    role = json['role'];
    temporaryPasscode = json['temporary_passcode'];
  }

  Map<String, dynamic> toJson() {
    return {
      'auth_data': authData?.toJson(),
      'user_id': userId,
      'name': name,
      'site_id': siteId,
      'site_name': siteName,
      'role': role,
      'temporary_passcode': temporaryPasscode,
    };
  }
}

class AuthData {
  late String? accessToken;
  late int expiresIn;
  late int refreshExpiresIn;
  late String? refreshToken;
  late String tokenType;
  late int notBeforePolicy;
  late String sessionState;
  late String scope;

  AuthData({
    required this.accessToken,
    required this.expiresIn,
    required this.refreshExpiresIn,
    required this.refreshToken,
    required this.tokenType,
    required this.notBeforePolicy,
    required this.sessionState,
    required this.scope,
  });

  AuthData.fromJson(Map<String, dynamic> json) {
    accessToken = json['access_token'] as String?;
    expiresIn =
        int.tryParse(json['expires_in'].toString()) ?? 0; // Safely parse to int
    refreshExpiresIn = int.tryParse(json['refresh_expires_in'].toString()) ??
        0; // Safely parse to int
    refreshToken = json['refresh_token'] as String?;
    tokenType = json['token_type'];
    notBeforePolicy = int.tryParse(json['not-before-policy'].toString()) ??
        0; // Safely parse to int
    sessionState = json['session_state'];
    scope = json['scope'];
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'expires_in': expiresIn,
      'refresh_expires_in': refreshExpiresIn,
      'refresh_token': refreshToken,
      'token_type': tokenType,
      'not-before-policy': notBeforePolicy,
      'session_state': sessionState,
      'scope': scope,
    };
  }
}
