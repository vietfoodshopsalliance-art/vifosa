// lib/core/config/env.dart
// ignore_for_file: do_not_use_environment
// Inject lúc build: flutter run --dart-define=API_URL=https://...
const apiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://vifosa-backend.onrender.com'
);

const trackingBaseUrl = String.fromEnvironment(
  'TRACK_URL',
  defaultValue: 'https://vifosa.vercel.app',
);
