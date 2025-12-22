import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';

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
      await Logger.log('OCR: initialize - starting');
      print('Tesseract OCR ready');
      _isInitialized = true;
      await Logger.log('OCR: initialize - finished');
      return true;
    } catch (e) {
      await Logger.log('OCR: initialize - error: $e');
      return false;
    }
  }

  Future<String> recognizeText(Uint8List imageBytes) async {
    await Logger.log('OCR: recognizeText - starting');
    if (!_isInitialized) {
      throw Exception('OCRService not initialized');
    }

    if (imageBytes.isEmpty || imageBytes.length > 10000000) {
      await Logger.log('OCR: recognizeText - invalid image bytes (${imageBytes.length})');
      return '';
    }

    String? tempImagePath;

    try {
      await Logger.log('OCR: processing image - ${imageBytes.length} bytes');

      var image = img.decodeImage(imageBytes);
      if (image == null) {
        await Logger.log('OCR: processing image - failed to decode');
        return '';
      }

      await Logger.log('OCR: original size: ${image.width}x${image.height}');

      if (image.width > 2000 || image.height > 2000) {
        image = img.copyResize(image, width: 1500);
        await Logger.log('OCR: resized to: ${image.width}x${image.height}');
      } else {
        await Logger.log('OCR: upscaled to: ${image.width}x${image.height}');
      }

      final bytes = Uint8List.fromList(img.encodePng(image));
      tempImagePath = await _saveToTempFile(bytes);
      await Logger.log('OCR: saved temp image at $tempImagePath');

      await Logger.log('OCR: running tesseract (psm=11,oem=1)');
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
        await Logger.log('OCR: finished - no text found (confidence: unknown)');
        print('No text found');
      } else {
        await Logger.log('OCR: finished - result: "$result" (confidence: unknown)');
        print('Found: $result');
      }

      return result;
    } catch (e) {
      await Logger.log('OCR: error: $e');
      return '';
    } finally {
      if (tempImagePath != null) {
        try {
          await File(tempImagePath).delete();
          await Logger.log('OCR: cleaned temp file $tempImagePath');
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
    await Logger.log('OCR: dispose');
  }
}