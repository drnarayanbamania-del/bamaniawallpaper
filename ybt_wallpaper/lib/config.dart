/// YBT Wallpaper — App Configuration
/// All config values live here. No .env file.
/// Switch between dev and prod by changing baseUrl only.
class Config {
  static const String baseUrl = 'http://localhost:3000'; // change for prod (e.g. https://your-domain.com)
  static const String appName = 'Bamania wall paper';
  static const String supportEmail = 'support@yourdomain.com';
  static const int paginationLimit = 20;
  static const String defaultTheme = 'light'; // 'light' or 'dark'
  static const String version = '1.0.0';
}
