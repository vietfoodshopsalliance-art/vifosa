class Env {
  static const apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:8080', // Android emulator → localhost
  );
  static const trackingBaseUrl = String.fromEnvironment(
    'TRACK_URL',
    defaultValue: 'https://vifosa.vercel.app',
  );
}
