import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import 'services/auth_service.dart';
import 'services/sheets_service.dart';
import 'services/sync_service.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'utils/excel_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  developer.log('═══════════════════════════════════════', name: 'main');
  developer.log('🚀 APP STARTUP', name: 'main');
  developer.log('═══════════════════════════════════════', name: 'main');

  // Initialize database factory (web only)
  developer.log('Initializing database factory...', name: 'main');
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }
  developer.log('✅ Database factory initialized', name: 'main');

  // Seed data from bundled Excel if database is empty
  print('[main] Checking if data seeding is needed...');
  try {
    // Seed Products
    final seededProducts = await ExcelHelper.seedProductsFromAsset();
    if (seededProducts > 0) {
      print('[main] Seeded $seededProducts products from Excel');
    }

    // Seed Clients
    final seededClients = await ExcelHelper.seedClientsFromAsset();
    if (seededClients > 0) {
      print('[main] Seeded $seededClients clients from Excel');
    }
  } catch (e, stackTrace) {
    print('[main] Seeding error (non-fatal): $e');
    print('[main] Stack trace: $stackTrace');
  }

  // Try silent sign-in with timeout
  developer.log('Attempting silent sign-in...', name: 'main');
  bool isSignedIn = false;
  try {
    final account = await AuthService.instance.signInSilently().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        developer.log('⏱️  Silent sign-in timed out', name: 'main', level: 1000);
        return null;
      },
    );
    isSignedIn = account != null;
    developer.log('Silent sign-in result: ${account?.email ?? "not signed in"}', name: 'main');
  } catch (e, stackTrace) {
    developer.log('❌ Silent sign-in error: $e', name: 'main', level: 1000);
    developer.log('Stack: $stackTrace', name: 'main', level: 1000);
    isSignedIn = false;
  }

  developer.log('isSignedIn: $isSignedIn', name: 'main');
  developer.log('Running app with isSignedIn=$isSignedIn...', name: 'main');
  developer.log('═══════════════════════════════════════', name: 'main');

  runApp(OrderApp(isSignedIn: isSignedIn));
}

class OrderApp extends StatefulWidget {
  final bool isSignedIn;

  const OrderApp({super.key, required this.isSignedIn});

  @override
  State<OrderApp> createState() => _OrderAppState();
}

class _OrderAppState extends State<OrderApp> {
  @override
  void initState() {
    super.initState();
    if (widget.isSignedIn) {
      // Initialize in background without blocking UI
      _initializeApp();
    }
  }

  /// Initialize app for already-signed-in users
  Future<void> _initializeApp() async {
    try {
      developer.log('Initializing app for signed-in user', name: 'OrderApp');

      // Get authenticated client
      developer.log('Getting authenticated client...', name: 'OrderApp');
      final authClient = await AuthService.instance.getAuthenticatedClient();
      developer.log('Got authenticated client', name: 'OrderApp');

      // Get or create spreadsheet
      developer.log('Getting or create spreadsheet...', name: 'OrderApp');
      final spreadsheetId = await SheetsService.instance.getOrCreateSpreadsheet(authClient);
      developer.log('Using spreadsheet: $spreadsheetId', name: 'OrderApp');

      // Initialize sync service
      developer.log('Initializing sync service...', name: 'OrderApp');
      await SyncService.instance.initialize(spreadsheetId, authClient);

      // Perform bi-directional sync
      developer.log('Syncing data...', name: 'OrderApp');
      
      // 1. Push any local data that isn't in Sheets yet
      await SyncService.instance.pushToSheets();
      
      // 2. Pull data from Sheets (now safer as it won't overwrite local changes)
      await SyncService.instance.pullFromSheets();
      
      developer.log('Data sync complete', name: 'OrderApp');

      // Start connectivity watcher
      SyncService.instance.startConnectivityWatcher();
      developer.log('App initialization complete!', name: 'OrderApp');
    } catch (e) {
      developer.log('Error initializing app: $e', name: 'OrderApp', level: 1000);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'retailTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: widget.isSignedIn
          ? const HomeScreen()
          : const AuthScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/auth': (context) => const AuthScreen(),
      },
    );
  }

  @override
  void dispose() {
    SyncService.instance.stopConnectivityWatcher();
    super.dispose();
  }
}
