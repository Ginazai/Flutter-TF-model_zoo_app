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

  Future<String> recognizeText(Uint8List imageBytes, {String? groundTruth}) async {
    await Logger.log('OCR: recognizeText - starting');
    if (groundTruth != null) {
      await Logger.log('OCR: Ground Truth = "$groundTruth"');
    }

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
        await Logger.log('OCR: finished - no text found');
        print('No text found');
      } else {
        await Logger.log('OCR: finished - result: "$result"');
        print('Found: $result');
      }

      // Calcular métricas de precisión si hay ground truth
      if (groundTruth != null) {
        await _logOCRMetrics(result, groundTruth);
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

  Future<void> _logOCRMetrics(String predicted, String groundTruth) async {
    // Normalizar textos para comparación
    String normalizedPredicted = predicted.toLowerCase().trim();
    String normalizedGroundTruth = groundTruth.toLowerCase().trim();

    // Exactitud (exact match)
    bool exactMatch = normalizedPredicted == normalizedGroundTruth;
    await Logger.log('OCR: METRICS - Exact Match: $exactMatch');

    // Character Error Rate (CER)
    int cer = _levenshteinDistance(normalizedPredicted, normalizedGroundTruth);
    double cerRate = groundTruth.isEmpty ? 0.0 : cer / groundTruth.length;
    await Logger.log('OCR: METRICS - Character Error Rate (CER): ${(cerRate * 100).toStringAsFixed(2)}% | Edit Distance: $cer');

    // Word Error Rate (WER)
    List<String> predictedWords = normalizedPredicted.split(RegExp(r'\s+'));
    List<String> groundTruthWords = normalizedGroundTruth.split(RegExp(r'\s+'));
    int wer = _levenshteinDistance(
      predictedWords.join(' '),
      groundTruthWords.join(' '),
    );
    double werRate = groundTruthWords.isEmpty ? 0.0 : wer / groundTruthWords.length;
    await Logger.log('OCR: METRICS - Word Error Rate (WER): ${(werRate * 100).toStringAsFixed(2)}%');

    // Precisión a nivel de caracter
    int correctChars = 0;
    int totalChars = groundTruth.length;
    for (int i = 0; i < normalizedPredicted.length && i < normalizedGroundTruth.length; i++) {
      if (normalizedPredicted[i] == normalizedGroundTruth[i]) {
        correctChars++;
      }
    }
    double charAccuracy = totalChars == 0 ? 0.0 : correctChars / totalChars;
    await Logger.log('OCR: METRICS - Character Accuracy: ${(charAccuracy * 100).toStringAsFixed(2)}% | Correct: $correctChars/$totalChars');

    // Similitud (basada en palabras coincidentes)
    Set<String> predictedSet = predictedWords.toSet();
    Set<String> groundTruthSet = groundTruthWords.toSet();
    int commonWords = predictedSet.intersection(groundTruthSet).length;
    double wordSimilarity = groundTruthWords.isEmpty ? 0.0 : commonWords / groundTruthWords.length;
    await Logger.log('OCR: METRICS - Word Similarity: ${(wordSimilarity * 100).toStringAsFixed(2)}% | Common Words: $commonWords/${groundTruthWords.length}');

    // Longitud
    await Logger.log('OCR: METRICS - Length - Predicted: ${predicted.length} | Ground Truth: ${groundTruth.length} | Diff: ${(predicted.length - groundTruth.length).abs()}');

    // Resumen de precisión
    double overallAccuracy = (charAccuracy + wordSimilarity) / 2;
    await Logger.log('OCR: METRICS - Overall Accuracy Score: ${(overallAccuracy * 100).toStringAsFixed(2)}%');

    if (exactMatch) {
      await Logger.log('OCR: METRICS - PERFECT MATCH ✓');
    } else if (overallAccuracy > 0.8) {
      await Logger.log('OCR: METRICS - HIGH ACCURACY ✓');
    } else if (overallAccuracy > 0.5) {
      await Logger.log('OCR: METRICS - MODERATE ACCURACY ~');
    } else {
      await Logger.log('OCR: METRICS - LOW ACCURACY ✗');
    }
  }

  // Algoritmo de Levenshtein para calcular distancia de edición
  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<List<int>> matrix = List.generate(
      s1.length + 1,
          (i) => List.filled(s2.length + 1, 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        int cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s1.length][s2.length];
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