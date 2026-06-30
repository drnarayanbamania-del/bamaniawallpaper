import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

// Import local folders placeholders
// In a real application, you would create files in features/ and core/ and import them here.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Note: Firebase setup requires google-services.json for Android 
  // and GoogleService-Info.plist for iOS.
  // We wrap it in a try-catch to allow running/analyzing without configuration crashes.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase Initialization Warning: $e");
    debugPrint("Please add Firebase configuration files to run on a device.");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const EventHubApp(),
    ),
  );
}

class EventHubApp extends StatelessWidget {
  const EventHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EventHub',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/organizer': (context) => const OrganizerDashboard(),
        '/admin': (context) => const AdminPanel(),
      },
    );
  }
}

// ── Role definitions as per PRD ───────────────────────────
enum UserRole {
  user,
  organizer,
  admin,
  superAdmin,
}

// ── Dummy Auth Provider ──────────────────────────────────
class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  UserRole _role = UserRole.user;
  String _userName = 'Guest';

  bool get isAuthenticated => _isAuthenticated;
  UserRole get role => _role;
  String get userName => _userName;

  void login(String name, UserRole role) {
    _isAuthenticated = true;
    _role = role;
    _userName = name;
    notifyListeners();
  }

  void logout() {
    _isAuthenticated = false;
    _role = UserRole.user;
    _userName = 'Guest';
    notifyListeners();
  }
}

// ── Authentication Wrapper Screen ─────────────────────────
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }
    
    switch (auth.role) {
      case UserRole.admin:
      case UserRole.superAdmin:
        return const AdminPanel();
      case UserRole.organizer:
        return const OrganizerDashboard();
      case UserRole.user:
      default:
        return const HomeScreen();
    }
  }
}

// ── Dummy Login Screen ────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  UserRole _selectedRole = UserRole.user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.event_seat, size: 80, color: Colors.deepPurple),
              const SizedBox(height: 16),
              const Text(
                'EventHub',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
              const SizedBox(height: 8),
              const Text(
                'Manage and Book Events Seamlessly',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<UserRole>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Select Role',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.security),
                ),
                items: UserRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role.toString().split('.').last.toUpperCase()),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedRole = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  final name = _nameController.text.isEmpty ? 'User' : _nameController.text;
                  Provider.of<AuthProvider>(context, listen: false).login(name, _selectedRole);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dummy Home / Discover Screen ─────────────────────────
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome, ${auth.userName}!', style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            const Text('Role: USER', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening Ticket Booking...')),
                );
              },
              icon: const Icon(Icons.confirmation_num),
              label: const Text('Book Tickets Now'),
            )
          ],
        ),
      ),
    );
  }
}

// ── Dummy Organizer Dashboard ─────────────────────────────
class OrganizerDashboard extends StatelessWidget {
  const OrganizerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organizer Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Organizer Portal: ${auth.userName}', style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            const Text('Role: ORGANIZER', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening Scanner Camera...')),
                );
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR Code Check-In'),
            )
          ],
        ),
      ),
    );
  }
}

// ── Dummy Admin Panel ─────────────────────────────────────
class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Operations Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Admin Console: ${auth.userName}', style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text('Role: ${auth.role.toString().split('.').last.toUpperCase()}', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generating System Audit Log...')),
                );
              },
              icon: const Icon(Icons.assessment),
              label: const Text('View Analytics & System Reports'),
            )
          ],
        ),
      ),
    );
  }
}
