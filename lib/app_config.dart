class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://carwash-backend-2yz2.onrender.com',
  );

  const AppConfig._();
}
