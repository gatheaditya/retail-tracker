import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../services/auth_service.dart';
import '../services/sheets_service.dart';
import '../services/sync_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      developer.log('Starting sign-in flow', name: 'AuthScreen');

      // Step 1: Sign in with Google
      developer.log('Step 1: Signing in...', name: 'AuthScreen');
      final account = await AuthService.instance.signIn();
      if (account == null) {
        throw Exception('Sign-in was cancelled');
      }

      developer.log('Signed in as ${account.email}', name: 'AuthScreen');

      // Step 2: Get authenticated client
      developer.log('Step 2: Getting authenticated client...', name: 'AuthScreen');
      final authClient = await AuthService.instance.getAuthenticatedClient();
      developer.log('Got authenticated client', name: 'AuthScreen');

      // Step 3: Get or create spreadsheet
      developer.log('Step 3: Getting/creating spreadsheet...', name: 'AuthScreen');
      final spreadsheetId = await SheetsService.instance.getOrCreateSpreadsheet(authClient);
      developer.log('Using spreadsheet: $spreadsheetId', name: 'AuthScreen');

      // Step 4: Initialize sync service
      developer.log('Step 4: Initializing sync service...', name: 'AuthScreen');
      await SyncService.instance.initialize(spreadsheetId, authClient);

      // Step 5: Pull data from Sheets
      developer.log('Step 5: Pulling data from Sheets...', name: 'AuthScreen');
      await SyncService.instance.pullFromSheets();
      developer.log('Data pulled from Sheets', name: 'AuthScreen');

      // Step 6: Start connectivity watcher
      developer.log('Step 6: Starting connectivity watcher...', name: 'AuthScreen');
      SyncService.instance.startConnectivityWatcher();

      if (mounted) {
        // Step 7: Navigate to HomeScreen
        developer.log('Step 7: Navigating to HomeScreen...', name: 'AuthScreen');
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e, stackTrace) {
      developer.log('Sign-in error: $e\n$stackTrace', name: 'AuthScreen', level: 1000);
      if (mounted) {
        setState(() {
          _errorMessage = 'Sign-in failed: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background spices image (bottom-right)
          Positioned(
            bottom: -40,
            right: -30,
            child: Opacity(
              opacity: 0.15,
              child: Image.asset(
                'assets/spices.png',
                height: 350,
              ),
            ),
          ),
          // Leaf accent (top-left)
          Positioned(
            top: -20,
            left: -30,
            child: Opacity(
              opacity: 0.12,
              child: Image.asset(
                'assets/leaf-1.png',
                height: 160,
              ),
            ),
          ),
          // Leaf accent (top-right)
          Positioned(
            top: 60,
            right: -20,
            child: Opacity(
              opacity: 0.10,
              child: Transform.flip(
                flipX: true,
                child: Image.asset(
                  'assets/leaf-2.png',
                  height: 120,
                ),
              ),
            ),
          ),
          // Main content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Logo / Icon
                  Image.asset(
                    'assets/gagan_logo.png',
                    width: 180,
                    height: 80,
                  ),
                  const SizedBox(height: 32),
                  // App Title
                  Text(
                    'Gagan Foods',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  // App Subtitle
                  Text(
                    'Manage your orders efficiently',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 48),
                  // Loading or Sign-in button
                  if (_isLoading) ...[
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 16),
                    Text(
                      'Signing in...',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      onPressed: _handleSignIn,
                      icon: const Icon(Icons.login),
                      label: const Text('Sign in with Google'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Error message
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 32),
                  // Info text
                  Text(
                    'Sign in with your Google account to sync your orders across devices',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
