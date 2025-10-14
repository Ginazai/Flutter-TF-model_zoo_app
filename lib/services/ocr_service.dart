import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class OCRService {
  static const String DETECTOR_PATH = 'assets/models/ocr/EasyOCR_EasyOCRDetector_float.tflite';
  static const String RECOGNIZER_PATH = 'assets/models/ocr/EasyOCR_EasyOCRRecognizer_float.tflite';

  // EasyOCR standard input sizes
  static const int DETECTOR_INPUT_SIZE = 640;
  static const int RECOGNIZER_HEIGHT = 64;
  static const int RECOGNIZER_WIDTH = 256;

  Interpreter? _detector;
  Interpreter? _recognizer;
  bool _isInitialized = false;

  // Character set for EasyOCR English
  static const String CHARS = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!"#\$%&\'()*+,-./:;<=>?@[\\]^_`{|}~ ';

  Future<bool> initialize() async {
    try {
      // Load detection model
      final detectorOptions = InterpreterOptions()..threads = 4;
      _detector = await Interpreter.fromAsset(DETECTOR_PATH, options: detectorOptions);

      // Load recognition model
      final recognizerOptions = InterpreterOptions()..threads = 4;
      _recognizer = await Interpreter.fromAsset(RECOGNIZER_PATH, options: recognizerOptions);

      print('OCR Models loaded successfully');
      print('Detector input shape: ${_detector!.getInputTensor(0).shape}');
      print('Detector output shape: ${_detector!.getOutputTensor(0).shape}');
      print('Recognizer input shape: ${_recognizer!.getInputTensor(0).shape}');
      print('Recognizer output shape: ${_recognizer!.getOutputTensor(0).shape}');

      _isInitialized = true;
      return true;
    } catch (e) {
      print("Error inicializando OCRService: $e");
      return false;
    }
  }

  Future<String> recognizeText(Uint8List imageBytes) async {
    if (!_isInitialized) {
      throw Exception('OCRService no está inicializado');
    }

    if (imageBytes.isEmpty) {
      print('ERROR: Image bytes are empty');
      return '';
    }

    try {
      print('Processing image: ${imageBytes.length} bytes');

      // 1. Prepare image
      final image = await _preprocessImage(imageBytes);
      if (image.isEmpty) {
        print('ERROR: Preprocessed image is empty');
        return '';
      }

      // 2. Text detection
      final detections = await _detectText(image);
      print('Found ${detections.length} text regions');

      if (detections.isEmpty) {
        return '';
      }

      // 3. Text recognition
      final StringBuffer result = StringBuffer();

      for (var detection in detections) {
        final String recognizedText = await _recognizeTextInRegion(image, detection);
        if (recognizedText.isNotEmpty) {
          result.writeln(recognizedText);
        }
      }

      return result.toString().trim();
    } catch (e) {
      print("Error al reconocer texto: $e");
      return '';
    }
  }

  Future<List<List<List<List<double>>>>> _preprocessImage(Uint8List bytes) async {
    try {
      // Decode image
      img.Image? image = img.decodeImage(bytes);
      if (image == null) {
        print('ERROR: Failed to decode image');
        return [[[[]]]];
      }

      print('Original image size: ${image.width}x${image.height}');

      // Resize to detector input size: 800x608
      img.Image resized = img.copyResize(
        image,
        width: 800,
        height: 608,
      );

      // Convert to NCHW format [1, 3, 608, 800] - channels first!
      List<List<List<List<double>>>> input = List.generate(
        1,
            (_) => List.generate(
          3, // Channels (R, G, B)
              (c) => List.generate(
            608, // Height
                (y) => List.generate(
              800, // Width
                  (x) {
                img.Pixel pixel = resized.getPixel(x, y);
                // Normalize to [0, 1] and assign channel
                if (c == 0) return pixel.r / 255.0; // Red
                if (c == 1) return pixel.g / 255.0; // Green
                return pixel.b / 255.0; // Blue
              },
            ),
          ),
        ),
      );

      print('Input tensor shape: [1, 3, 608, 800]');
      return input;
    } catch (e) {
      print('Error in _preprocessImage: $e');
      return [[[[]]]];
    }
  }

  Future<List<Map<String, dynamic>>> _detectText(List<List<List<List<double>>>> image) async {
    try {
      // Get output shape
      final outputShape = _detector!.getOutputTensor(0).shape;
      print('Detection output shape: $outputShape');

      // Prepare output buffer
      var outputBuffer = List.generate(
        outputShape[0],
            (_) => List.generate(
          outputShape[1],
              (_) => List.generate(
            outputShape[2],
                (_) => List.filled(outputShape[3], 0.0),
          ),
        ),
      );

      // Run inference
      _detector!.run(image, outputBuffer);

      // Process detections
      return _processDetections(outputBuffer);
    } catch (e) {
      print("Error en detección: $e");
      return [];
    }
  }

  List<Map<String, dynamic>> _processDetections(List<dynamic> output) {
    try {
      List<Map<String, dynamic>> detections = [];

      // EasyOCR detector typically outputs a heatmap
      // We need to find connected regions above a threshold
      const double confidenceThreshold = 0.5;

      // Simplified: Find regions with high confidence
      // In production, you'd implement proper connected component analysis
      for (int y = 0; y < output[0].length; y += 10) {
        for (int x = 0; x < output[0][0].length; x += 10) {
          double confidence = output[0][y][x][0];

          if (confidence > confidenceThreshold) {
            detections.add({
              'x': x,
              'y': y,
              'width': 50,  // Approximate width
              'height': 20, // Approximate height
              'confidence': confidence,
            });
          }
        }
      }

      // Apply non-maximum suppression
      detections = _nonMaxSuppression(detections);

      print('Filtered detections: ${detections.length}');
      return detections;
    } catch (e) {
      print('Error in _processDetections: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> _nonMaxSuppression(List<Map<String, dynamic>> boxes) {
    if (boxes.isEmpty) return [];

    // Sort by confidence
    boxes.sort((a, b) => (b['confidence'] as double).compareTo(a['confidence'] as double));

    List<Map<String, dynamic>> selected = [];
    List<bool> suppressed = List.filled(boxes.length, false);

    for (int i = 0; i < boxes.length; i++) {
      if (suppressed[i]) continue;

      selected.add(boxes[i]);

      // Suppress overlapping boxes
      for (int j = i + 1; j < boxes.length; j++) {
        if (_iou(boxes[i], boxes[j]) > 0.3) {
          suppressed[j] = true;
        }
      }
    }

    return selected;
  }

  double _iou(Map<String, dynamic> box1, Map<String, dynamic> box2) {
    // Calculate intersection over union
    int x1 = max(box1['x'] as int, box2['x'] as int);
    int y1 = max(box1['y'] as int, box2['y'] as int);
    int x2 = min((box1['x'] as int) + (box1['width'] as int),
        (box2['x'] as int) + (box2['width'] as int));
    int y2 = min((box1['y'] as int) + (box1['height'] as int),
        (box2['y'] as int) + (box2['height'] as int));

    if (x2 < x1 || y2 < y1) return 0.0;

    int intersection = (x2 - x1) * (y2 - y1);
    int area1 = (box1['width'] as int) * (box1['height'] as int);
    int area2 = (box2['width'] as int) * (box2['height'] as int);
    int union = area1 + area2 - intersection;

    return intersection / union;
  }

  Future<String> _recognizeTextInRegion(
      List<List<List<List<double>>>> image,
      Map<String, dynamic> region,
      ) async {
    try {
      // Crop and prepare region
      final croppedRegion = _cropRegion(image, region);

      if (croppedRegion.isEmpty || croppedRegion[0].isEmpty) {
        return '';
      }

      // Get output shape
      final outputShape = _recognizer!.getOutputTensor(0).shape;

      // Prepare output buffer
      var outputBuffer = List.generate(
        outputShape[0],
            (_) => List.generate(
          outputShape[1],
              (_) => List.filled(outputShape[2], 0.0),
        ),
      );

      // Run inference
      _recognizer!.run(croppedRegion, outputBuffer);

      // Decode text
      return _decodeText(outputBuffer);
    } catch (e) {
      print("Error en reconocimiento: $e");
      return '';
    }
  }

  List<List<List<List<double>>>> _cropRegion(
      List<List<List<List<double>>>> image,
      Map<String, dynamic> region,
      ) {
    try {
      int x = region['x'] as int;
      int y = region['y'] as int;
      int width = region['width'] as int;
      int height = region['height'] as int;

      // Clamp to image bounds
      x = max(0, min(x, image[0].length - 1));
      y = max(0, min(y, image[0][0].length - 1));
      width = min(width, image[0].length - x);
      height = min(height, image[0][0].length - y);

      // Crop region
      List<List<List<double>>> cropped = [];
      for (int dy = 0; dy < height; dy++) {
        List<List<double>> row = [];
        for (int dx = 0; dx < width; dx++) {
          if (y + dy < image[0].length && x + dx < image[0][0].length) {
            row.add(image[0][y + dy][x + dx]);
          }
        }
        if (row.isNotEmpty) {
          cropped.add(row);
        }
      }

      // Resize to recognizer input size
      return _resizeForRecognizer(cropped);
    } catch (e) {
      print('Error in _cropRegion: $e');
      return [[[[]]]];
    }
  }

  List<List<List<List<double>>>> _resizeForRecognizer(List<List<List<double>>> cropped) {
    // Simple nearest-neighbor resize to [1, 64, 256, 3]
    List<List<List<List<double>>>> resized = [[]];

    if (cropped.isEmpty) return resized;

    double yRatio = cropped.length / RECOGNIZER_HEIGHT;
    double xRatio = cropped[0].length / RECOGNIZER_WIDTH;

    resized = List.generate(
      1,
          (_) => List.generate(
        RECOGNIZER_HEIGHT,
            (y) => List.generate(
          RECOGNIZER_WIDTH,
              (x) {
            int srcY = min((y * yRatio).floor(), cropped.length - 1);
            int srcX = min((x * xRatio).floor(), cropped[0].length - 1);
            return cropped[srcY][srcX];
          },
        ),
      ),
    );

    return resized;
  }

  String _decodeText(List<dynamic> recognizerOutput) {
    try {
      // CTC decoding: take argmax at each timestep
      StringBuffer result = StringBuffer();
      int previousChar = -1;

      for (int i = 0; i < recognizerOutput[0].length; i++) {
        List<double> timestep = List<double>.from(recognizerOutput[0][i]);

        // Find character with highest probability
        int maxIdx = 0;
        double maxProb = timestep[0];
        for (int j = 1; j < timestep.length; j++) {
          if (timestep[j] > maxProb) {
            maxProb = timestep[j];
            maxIdx = j;
          }
        }

        // Skip blank (index 0) and repeated characters
        if (maxIdx > 0 && maxIdx != previousChar) {
          if (maxIdx - 1 < CHARS.length) {
            result.write(CHARS[maxIdx - 1]);
          }
        }
        previousChar = maxIdx;
      }

      return result.toString().trim();
    } catch (e) {
      print('Error in _decodeText: $e');
      return '';
    }
  }

  Future<void> dispose() async {
    try {
      _detector?.close();
      _recognizer?.close();
      _isInitialized = false;
    } catch (e) {
      print("Error disposing OCRService: $e");
    }
  }
}