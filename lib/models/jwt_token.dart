class JwtToken {
  final int? exp;
  final int? iat;
  final String? jti;
  final String? iss;
  final String? aud;
  final String? sub;
  final String? typ;
  final String? azp;
  final String? sessionState;
  final String? acr;
  final List<String>? allowedOrigins;
  final RealmAccess? realmAccess;
  final ResourceAccess? resourceAccess;
  final String? scope;
  final String? sid;
  final bool? emailVerified;
  final String? name;
  final String? preferredUsername;
  final String? givenName;
  final String? familyName;
  final String? email;
  final String? role;
  final String? userId;
  final String? siteId;
  final String? firstName;
  final String? lastName;

  JwtToken({
    this.exp,
    this.iat,
    this.jti,
    this.iss,
    this.aud,
    this.sub,
    this.typ,
    this.azp,
    this.sessionState,
    this.acr,
    this.allowedOrigins,
    this.realmAccess,
    this.resourceAccess,
    this.scope,
    this.sid,
    this.emailVerified,
    this.name,
    this.preferredUsername,
    this.givenName,
    this.familyName,
    this.email,
    this.role,
    this.userId,
    this.siteId,
    this.firstName,
    this.lastName,
  });

  factory JwtToken.fromMap(Map<String, dynamic> map) {
    return JwtToken(
      exp: map['exp'],
      iat: map['iat'],
      jti: map['jti'],
      iss: map['iss'],
      aud: map['aud'],
      sub: map['sub'],
      typ: map['typ'],
      azp: map['azp'],
      sessionState: map['session_state'],
      acr: map['acr'],
      allowedOrigins: (map['allowed-origins'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      realmAccess: map['realm_access'] != null
          ? RealmAccess.fromMap(map['realm_access'])
          : null,
      resourceAccess: map['resource_access'] != null
          ? ResourceAccess.fromMap(map['resource_access'])
          : null,
      scope: map['scope'],
      sid: map['sid'],
      emailVerified: map['email_verified'],
      name: map['name'],
      preferredUsername: map['preferred_username'],
      givenName: map['given_name'],
      familyName: map['family_name'],
      email: map['email'],
      role: map['role'],
      userId: map['user_id'],
      siteId: map['site_id'],
      firstName: map['firstName'],
      lastName: map['lastName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'exp': exp,
      'iat': iat,
      'jti': jti,
      'iss': iss,
      'aud': aud,
      'sub': sub,
      'typ': typ,
      'azp': azp,
      'session_state': sessionState,
      'acr': acr,
      'allowed-origins': allowedOrigins,
      'realm_access': realmAccess?.toMap(),
      'resource_access': resourceAccess?.toMap(),
      'scope': scope,
      'sid': sid,
      'email_verified': emailVerified,
      'name': name,
      'preferred_username': preferredUsername,
      'given_name': givenName,
      'family_name': familyName,
      'email': email,
      'role': role,
      'user_id': userId,
      'site_id': siteId,
      'firstName': firstName,
      'lastName': lastName,
    };
  }
}

class RealmAccess {
  final List<String>? roles;

  RealmAccess({this.roles});

  factory RealmAccess.fromMap(Map<String, dynamic> map) {
    return RealmAccess(
      roles: (map['roles'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roles': roles,
    };
  }
}

class ResourceAccess {
  final AccountAccess? account;

  ResourceAccess({this.account});

  factory ResourceAccess.fromMap(Map<String, dynamic> map) {
    return ResourceAccess(
      account:
          map['account'] != null ? AccountAccess.fromMap(map['account']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'account': account?.toMap(),
    };
  }
}

class AccountAccess {
  final List<String>? roles;

  AccountAccess({this.roles});

  factory AccountAccess.fromMap(Map<String, dynamic> map) {
    return AccountAccess(
      roles: (map['roles'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roles': roles,
    };
  }
}
