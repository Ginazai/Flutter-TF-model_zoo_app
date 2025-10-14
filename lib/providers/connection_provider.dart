import 'package:flutter/foundation.dart';
import '../services/esp32_service.dart';

class ConnectionProvider with ChangeNotifier {
  final ESP32Service _esp32Service;

  bool _isConnected = false;
  String _esp32Ip = '192.168.4.1';

  ConnectionProvider() : _esp32Service = ESP32Service();

  // GETTERS (para que la UI lea)
  bool get isConnected => _isConnected;
  String get esp32Ip => _esp32Ip;
  ESP32Service get esp32Service => _esp32Service;

  // MÉTODOS (acciones que la UI puede llamar)
  Future<void> connect(String ip) async {
    _esp32Ip = ip;
    _isConnected = await _esp32Service.testConnection();
    notifyListeners(); // ⚠️ IMPORTANTE: notifica a la UI
  }

  void disconnect() {
    _isConnected = false;
    notifyListeners();
  }
}