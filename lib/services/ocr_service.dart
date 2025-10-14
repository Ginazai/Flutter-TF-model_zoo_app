import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

class OCRService {
  TextRecognizer? _textRecognizer;
  bool _isInitialized = false;

  Future<bool> initialize() async {
    try {
      // Initialize Google ML Kit Text Recognizer
      _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

      print('✅ ML Kit Text Recognizer initialized successfully');
      _isInitialized = true;
      return true;
    } catch (e) {
      print("❌ Error initializing OCRService: $e");
      return false;
    }
  }

  Future<String> recognizeText(Uint8List imageBytes) async {
    if (!_isInitialized) {
      throw Exception('OCRService not initialized');
    }

    if (imageBytes.isEmpty) {
      print('ERROR: Image bytes are empty');
      return '';
    }

    try {
      print('Processing JPEG image: ${imageBytes.length} bytes');

      // Decode JPEG to get image data
      var image = img.decodeImage(imageBytes);
      if (image == null) {
        print('ERROR: Failed to decode JPEG image');
        return '';
      }

      print('Original image size: ${image.width}x${image.height}');

      // Enhance image: increase contrast and upscale if needed
      image = _enhanceImage(image);
      print('Enhanced image size: ${image.width}x${image.height}');

      // Try OCR with different rotations
      String result = await _recognizeWithRotation(image, InputImageRotation.rotation0deg);

      if (result.isEmpty) {
        print('No text found at 0°, trying 90°...');
        result = await _recognizeWithRotation(image, InputImageRotation.rotation90deg);
      }

      if (result.isEmpty) {
        print('No text found at 90°, trying 180°...');
        result = await _recognizeWithRotation(image, InputImageRotation.rotation180deg);
      }

      if (result.isEmpty) {
        print('No text found at 180°, trying 270°...');
        result = await _recognizeWithRotation(image, InputImageRotation.rotation270deg);
      }

      print('Found text: ${result.isNotEmpty ? result : "No text detected"}');
      return result;
    } catch (e) {
      print("Error recognizing text: $e");
      return '';
    }
  }

  String _extractTextWithConfidence(RecognizedText recognizedText) {
    try {
      final StringBuffer result = StringBuffer();
      double totalConfidence = 0.0;
      int blockCount = 0;

      // Process text blocks
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          for (TextElement element in line.elements) {
            // ML Kit returns confidence as a value (usually available from the API)
            result.write(element.text);
            totalConfidence += 1.0;
          }
          result.write('\n');
        }
        blockCount++;
      }

      print('Extracted from $blockCount text blocks');
      return result.toString().trim();
    } catch (e) {
      print('Error extracting text: $e');
      return '';
    }
  }

  img.Image _enhanceImage(img.Image image) {
    try {
      // Upscale small images for better OCR
      if (image.width < 1000) {
        image = img.copyResize(image, width: image.width * 2, height: image.height * 2);
        print('Upscaled image to ${image.width}x${image.height}');
      }

      // Increase contrast
      image = img.contrast(image, contrast: 1.5);

      // Increase brightness slightly
      image = img.adjustColor(image, brightness: 1.1);

      return image;
    } catch (e) {
      print('Error enhancing image: $e');
      return image;
    }
  }

  Future<String> _recognizeWithRotation(
      img.Image image,
      InputImageRotation rotation,
      ) async {
    try {
      // Convert to BGRA8888 format
      final rawBytes = Uint8List(image.width * image.height * 4);
      int index = 0;

      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          rawBytes[index++] = pixel.b.toInt();
          rawBytes[index++] = pixel.g.toInt();
          rawBytes[index++] = pixel.r.toInt();
          rawBytes[index++] = pixel.a.toInt() ?? 255;
        }
      }

      // Create InputImage with specified rotation
      final inputImage = InputImage.fromBytes(
        bytes: rawBytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.width * 4,
        ),
      );

      // Perform text recognition
      final recognizedText = await _textRecognizer!.processImage(inputImage);

      return _extractTextWithConfidence(recognizedText);
    } catch (e) {
      print('Error in recognition with rotation: $e');
      return '';
    }
  }

  Future<void> dispose() async {
    try {
      await _textRecognizer?.close();
      _isInitialized = false;
      print('OCRService disposed');
    } catch (e) {
      print("Error disposing OCRService: $e");
    }
  }
}