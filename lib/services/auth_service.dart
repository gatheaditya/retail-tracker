import 'package:http/http.dart' as http;
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

// Platform-specific imports
import 'package:google_sign_in/google_sign_in.dart' show GoogleSignIn, GoogleSignInAccount, SignInOption;

class AuthService {
  static final AuthService instance = AuthService._();
  static const _spreadsheetsScope = 'https://www.googleapis.com/auth/spreadsheets';
  static const _driveFileScope = 'https://www.googleapis.com/auth/drive.file';
  // Use serverClientId (Android OAuth Client ID) for Android
  static const _serverClientId = '85810032500-tob5c8a84l6a03m6tfbopg2t99s8b8ck.apps.googleusercontent.com';

  late final GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentUser;

  AuthService._() {
    _initializeGoogleSignIn();
  }

  void _initializeGoogleSignIn() {
    if (kIsWeb) {
      developer.log('Web platform detected - Google Sign In disabled', name: 'AuthService');
      _googleSignIn = null;
    } else {
      developer.log('Mobile platform detected - initializing Google Sign In', name: 'AuthService');
      try {
        _googleSignIn = GoogleSignIn(
          serverClientId: _serverClientId,
          scopes: [_spreadsheetsScope, _driveFileScope],
          signInOption: SignInOption.standard,
        );
      } catch (e) {
        developer.log('Failed to initialize GoogleSignIn: $e', name: 'AuthService', level: 1000);
        _googleSignIn = null;
      }
    }
  }

  /// Attempt silent sign-in without user interaction
  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      developer.log('🔐 SILENT SIGN-IN: Starting...', name: 'AuthService');

      if (kIsWeb) {
        developer.log('Web: silent sign-in not supported', name: 'AuthService');
        return _currentUser;
      }

      if (_googleSignIn == null) {
        return null;
      }

      final account = await _googleSignIn!.signInSilently();
      if (account != null) {
        _currentUser = account;
        developer.log('✅ SILENT SIGN-IN SUCCESS: ${account.email}', name: 'AuthService');
        developer.log('  → ID: ${account.id}', name: 'AuthService');
      } else {
        developer.log('⚠️  SILENT SIGN-IN: No account returned (not signed in)', name: 'AuthService');
      }
      return account;
    } catch (e) {
      developer.log('❌ SILENT SIGN-IN FAILED: $e', name: 'AuthService', level: 1000);
      return null;
    }
  }

  /// Interactive sign-in with user confirmation
  Future<GoogleSignInAccount?> signIn() async {
    try {
      developer.log('═══════════════════════════════════════', name: 'AuthService');
      developer.log('🔐 SIGN-IN FLOW STARTED', name: 'AuthService');
      developer.log('═══════════════════════════════════════', name: 'AuthService');

      if (kIsWeb) {
        developer.log('⚠️  Web: Interactive Google Sign In not implemented', name: 'AuthService');
        developer.log('═══════════════════════════════════════', name: 'AuthService');
        throw Exception('Google Sign In not available on web platform');
      }

      if (_googleSignIn == null) {
        throw Exception('Google Sign In not initialized');
      }

      developer.log('Step 1️⃣: Checking current user state...', name: 'AuthService');
      developer.log('  → Current user: ${_currentUser?.email ?? "null"}', name: 'AuthService');

      developer.log('Step 2️⃣: Disconnecting from previous session...', name: 'AuthService');
      try {
        await _googleSignIn!.disconnect();
        developer.log('  ✅ Disconnected successfully', name: 'AuthService');
      } catch (e) {
        developer.log('  ⚠️  Disconnect warning: $e', name: 'AuthService');
      }

      developer.log('Step 3️⃣: Verifying disconnection...', name: 'AuthService');
      developer.log('  → Current user after disconnect: null', name: 'AuthService');

      developer.log('Initiating OAuth popup...', name: 'AuthService');
      final account = await _googleSignIn!.signIn();

      if (account != null) {
        _currentUser = account;
        developer.log('✅ SIGN-IN SUCCESS', name: 'AuthService');
        developer.log('  → Email: ${account.email}', name: 'AuthService');
        developer.log('  → ID: ${account.id}', name: 'AuthService');
        developer.log('═══════════════════════════════════════', name: 'AuthService');
        return account;
      } else {
        developer.log('⚠️  SIGN-IN CANCELLED: User did not complete sign-in', name: 'AuthService');
        developer.log('═══════════════════════════════════════', name: 'AuthService');
        return null;
      }
    } catch (e, stackTrace) {
      developer.log('❌ EXCEPTION IN SIGN-IN:', name: 'AuthService', level: 1000);
      developer.log('  Error: $e', name: 'AuthService', level: 1000);
      developer.log('  Stack: $stackTrace', name: 'AuthService', level: 1000);
      developer.log('═══════════════════════════════════════', name: 'AuthService', level: 1000);
      rethrow;
    }
  }

  /// Sign out and disconnect account
  Future<void> signOut() async {
    try {
      developer.log('Signing out', name: 'AuthService');
      if (!kIsWeb && _googleSignIn != null) {
        await _googleSignIn!.signOut();
      }
      _currentUser = null;
      developer.log('Sign-out successful', name: 'AuthService');
    } catch (e) {
      developer.log('Sign-out failed: $e', name: 'AuthService', level: 1000);
      rethrow;
    }
  }

  /// Get authenticated HTTP client for API calls
  Future<http.Client> getAuthenticatedClient() async {
    developer.log('🔑 GET AUTH CLIENT: Starting...', name: 'AuthService');

    if (kIsWeb) {
      throw Exception('Authentication not available on web platform');
    }

    final account = _currentUser ?? await signInSilently();
    if (account == null) {
      developer.log('❌ GET AUTH CLIENT: No account available', name: 'AuthService', level: 1000);
      throw Exception('User not signed in');
    }

    developer.log('  → Account: ${account.email}', name: 'AuthService');

    try {
      developer.log('  → Getting authentication...', name: 'AuthService');
      final auth = await account.authentication;

      developer.log('  → Authentication object received:', name: 'AuthService');
      developer.log('    - idToken: ${auth.idToken != null ? "✅ present" : "❌ null"}', name: 'AuthService');
      developer.log('    - accessToken: ${auth.accessToken != null ? "✅ present" : "❌ null"}', name: 'AuthService');

      if (auth.accessToken == null) {
        developer.log('  ⚠️  Access token is null, attempting re-authentication...', name: 'AuthService');

        if (_googleSignIn != null) {
          developer.log('  → Requesting scopes again...', name: 'AuthService');
          try {
            final scopesGranted = await _googleSignIn!.requestScopes([_spreadsheetsScope, _driveFileScope]);
            developer.log('    - Scopes granted: $scopesGranted', name: 'AuthService');

            if (!scopesGranted) {
              throw Exception('Failed to request scopes');
            }
          } catch (e) {
            developer.log('    - Scopes request error: $e', name: 'AuthService');
          }
        }

        final freshAccount = _currentUser;
        developer.log('    - Current user after scopes: ${freshAccount?.email ?? "null"}', name: 'AuthService');

        if (freshAccount == null) {
          throw Exception('No user after requesting scopes');
        }

        developer.log('  → Getting new authentication...', name: 'AuthService');
        final newAuth = await freshAccount.authentication;
        developer.log('    - New accessToken: ${newAuth.accessToken != null ? "✅ present" : "❌ null"}', name: 'AuthService');

        if (newAuth.accessToken == null) {
          throw Exception('Still no access token after re-auth');
        }

        developer.log('✅ GET AUTH CLIENT: Got token after re-auth', name: 'AuthService');
        return GoogleHttpClient(accessToken: newAuth.accessToken!);
      }

      developer.log('✅ GET AUTH CLIENT: Got token successfully', name: 'AuthService');
      return GoogleHttpClient(accessToken: auth.accessToken!);
    } catch (e, stackTrace) {
      developer.log('❌ GET AUTH CLIENT ERROR: $e', name: 'AuthService', level: 1000);
      developer.log('  Stack: $stackTrace', name: 'AuthService', level: 1000);
      rethrow;
    }
  }

  /// Get current signed-in account
  GoogleSignInAccount? get currentUser => _currentUser;

  /// Check if user is currently signed in
  bool get isSignedIn => _currentUser != null;
}

/// Custom HTTP client that injects Google auth headers
class GoogleHttpClient extends http.BaseClient {
  final String accessToken;
  final http.Client _inner = http.Client();

  GoogleHttpClient({required this.accessToken});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['authorization'] = 'Bearer $accessToken';
    return _inner.send(request);
  }
}
