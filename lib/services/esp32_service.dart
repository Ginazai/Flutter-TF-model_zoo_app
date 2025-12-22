import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

class ESP32Service {
  final String baseUrl;

  ESP32Service({this.baseUrl = 'http://192.168.4.1'});

  Future<bool> testConnection() async {
    await Logger.log('ESP32: testConnection - starting');
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/status'))
          .timeout(Duration(seconds: 15));
      final ok = response.statusCode == 200;
      await Logger.log('ESP32: testConnection - finished status=${response.statusCode}');
      return ok;
    } catch (e) {
      await Logger.log('ESP32: testConnection - error: $e');
      return false;
    }
  }

  Future<Uint8List?> captureImage() async {
    await Logger.log('ESP32: capture - starting');
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/capture'))
          .timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        await Logger.log('ESP32: capture - finished (${response.bodyBytes.length} bytes)');
        return response.bodyBytes;
      }
      await Logger.log('ESP32: capture - failed status=${response.statusCode}');
      return null;
    } catch (e) {
      await Logger.log('ESP32: capture - error: $e');
      print('Error capturando imagen: $e');
      return null;
    }
  }
}