import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

Future<String> _runOCR(Map<String, dynamic> params) async {
  String result = await FlutterTesseractOcr.extractText(
    params['path'],
    language: params['language'],
    args: params['args'],
  );
  return result;
}

class OCRService {
  bool _isInitialized = false;

  Future<bool> initialize() async {
    try {
      print('Tesseract OCR ready');
      _isInitialized = true;
      return true;
    } catch (e) {
      print("Error initializing OCRService: $e");
      return false;
    }
  }

  Future<String> recognizeText(Uint8List imageBytes) async {
    if (!_isInitialized) {
      throw Exception('OCRService not initialized');
    }

    if (imageBytes.isEmpty || imageBytes.length > 10000000) {
      print('ERROR: Image bytes are empty');
      return '';
    }

    String? tempImagePath;

    try {
      print('Processing image: ${imageBytes.length} bytes');

      var image = img.decodeImage(imageBytes);
      if (image == null) {
        print('ERROR: Failed to decode image');
        return '';
      }

      print('Original size: ${image.width}x${image.height}');

      // MINIMAL enhancement: just upscale
      // image = img.copyResize(
      //   image,
      //   width: image.width * 2,
      //   height: image.height * 2,
      //   interpolation: img.Interpolation.cubic,
      // );
      if (image.width > 2000 || image.height > 2000) {
        image = img.copyResize(image, width: 1500);
      }
      print('Upscaled to: ${image.width}x${image.height}');

      final bytes = Uint8List.fromList(img.encodePng(image));
      tempImagePath = await _saveToTempFile(bytes);

      // Try single OCR call with PSM 11 (sparse text)
      // String result = await compute(_runOCR, {
      //   'path': tempImagePath,
      //   'language': 'spa+eng',
      //   'args': {"psm": "11", "oem": "1"},
      // });
      String result = await FlutterTesseractOcr.extractText(
        tempImagePath,
        language: 'spa+eng',
        args: {
          "psm": "11",
          "oem": "1",
        },
      );

      result = result.trim();

      if (result.isEmpty) {
        print('No text found');
      } else {
        print('Found: $result');
      }

      return result;
    } catch (e) {
      print("Error: $e");
      return '';
    } finally {
      if (tempImagePath != null) {
        try {
          await File(tempImagePath).delete();
        } catch (_) {}
      }
    }
  }

  Future<String> _saveToTempFile(Uint8List bytes) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/ocr_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<void> dispose() async {
    _isInitialized = false;
  }
}