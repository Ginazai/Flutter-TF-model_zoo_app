import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ESP32Service {
  final String baseUrl;

  ESP32Service({this.baseUrl = 'http://192.168.4.1'});

  // Verificar conexión
  Future<bool> testConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/status'))
          .timeout(Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Capturar imagen
  Future<Uint8List?> captureImage() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/capture'))
          .timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      print('Error capturando imagen: $e');
      return null;
    }
  }
}