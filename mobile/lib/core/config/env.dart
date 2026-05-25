class Env {
  static const apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: bool.fromEnvironment('dart.vm.product')
        ? 'https://vifosa-backend.onrender.com'
        : 'http://10.0.2.2:8080',
  );
  static const trackingBaseUrl = String.fromEnvironment(
    'TRACK_URL',
    defaultValue: 'https://vifosa.vercel.app',
  );
}
