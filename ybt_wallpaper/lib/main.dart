import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'theme.dart';
import 'api.dart';
import 'ad_helper.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'category_screen.dart';
import 'profile_screen.dart';
import 'favourites_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdHelper.initialize();
  runApp(const YBTWallpaperApp());
}

class YBTWallpaperApp extends StatefulWidget {
  const YBTWallpaperApp({super.key});

  static YBTWallpaperAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<YBTWallpaperAppState>();
  }

  @override
  State<YBTWallpaperApp> createState() => YBTWallpaperAppState();
}

class YBTWallpaperAppState extends State<YBTWallpaperApp>
    with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.light;
  Color _accentColor = const Color(0xFF38BDF8);
  String _accentName = 'skyBlue';

  static const Map<String, Color> accentPresets = {
    'skyBlue': Color(0xFF38BDF8),
    'midnight': Color(0xFF6366F1),
    'forest': Color(0xFF10B981),
    'rose': Color(0xFFF43F5E),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AdHelper.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      AdHelper.pauseTracking();
    } else if (state == AppLifecycleState.resumed) {
      AdHelper.resumeTracking();
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load theme
    final theme = prefs.getString('theme') ?? 'light';
    ThemeMode mode;
    if (theme == 'dark') {
      mode = ThemeMode.dark;
    } else if (theme == 'system') {
      mode = ThemeMode.system;
    } else {
      mode = ThemeMode.light;
    }

    // Load accent
    final accent = prefs.getString('accent') ?? 'skyBlue';
    final color = accentPresets[accent] ?? const Color(0xFF38BDF8);

    setState(() {
      _themeMode = mode;
      _accentName = accent;
      _accentColor = color;
    });
  }

  void updateThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    String val = 'light';
    if (mode == ThemeMode.dark) val = 'dark';
    if (mode == ThemeMode.system) val = 'system';
    
    await prefs.setString('theme', val);
    setState(() {
      _themeMode = mode;
    });
  }

  void updateAccentColor(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final color = accentPresets[name] ?? const Color(0xFF38BDF8);
    await prefs.setString('accent', name);
    setState(() {
      _accentName = name;
      _accentColor = color;
    });
  }

  void toggleTheme() async {
    if (_themeMode == ThemeMode.dark) {
      updateThemeMode(ThemeMode.light);
    } else {
      updateThemeMode(ThemeMode.dark);
    }
  }

  bool get isDark => _themeMode == ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;
  String get accentName => _accentName;
  Color get accentColor => _accentColor;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Config.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(_accentColor),
      darkTheme: AppTheme.darkTheme(_accentColor),
      themeMode: _themeMode,
      home: const SplashScreen(),
    );
  }
}

// ── Splash Screen ─────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    Future.delayed(const Duration(seconds: 2), _checkAuth);
  }

  Future<void> _checkAuth() async {
    if (!mounted) return;

    final hasToken = await Api.hasToken();
    if (!mounted) return;

    if (hasToken) {
      try {
        await Api.getMe();
        if (!mounted) return;
        _navigateTo(const MainScreen());
      } catch (_) {
        if (!mounted) return;
        _navigateTo(const AuthScreen());
      }
    } else {
      _navigateTo(const AuthScreen());
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: primaryColor,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.wallpaper_rounded,
                      size: 44,
                      color: primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                Config.appName,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Beautiful wallpapers',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Main Screen with Bottom Nav ───────────────────
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    CategoryScreen(),
    FavouritesScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Set up 401 handler
    Api.onUnauthorized = () {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: _screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          if (i != _currentIndex) {
            HapticFeedback.lightImpact();
            setState(() => _currentIndex = i);
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category_rounded),
            label: 'Category',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_rounded),
            label: 'Favourites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
