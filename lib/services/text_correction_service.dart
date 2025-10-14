import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class TextCorrectionService {
  static const String BERT_MODEL_PATH = 'assets/models/language/mobilebert-v1.tflite';
  static const int MAX_SEQ_LENGTH = 128;
  static const int VOCAB_SIZE = 30522; // Standard BERT vocabulary size

  Interpreter? _interpreter;
  bool _isInitialized = false;
  Map<String, int>? _vocabMap;

  Future<bool> initialize() async {
    try {
      // Load vocabulary
      final String vocabData = await rootBundle.loadString('assets/models/ocr/vocab.txt');
      _vocabMap = _loadVocabulary(vocabData);

      if (_vocabMap == null || _vocabMap!.isEmpty) {
        print('ERROR: Vocabulary map is empty');
        return false;
      }

      print('Vocabulary loaded: ${_vocabMap!.length} tokens');

      // Initialize MobileBERT
      final interpreterOptions = InterpreterOptions()
        ..threads = 4;

      _interpreter = await Interpreter.fromAsset(
        BERT_MODEL_PATH,
        options: interpreterOptions,
      );

      _isInitialized = true;
      return true;
    } catch (e) {
      print('Error inicializando TextCorrectionService: $e');
      return false;
    }
  }

  Future<String> correctText(String rawText) async {
    if (!_isInitialized) {
      throw Exception('TextCorrectionService no está inicializado');
    }

    try {
      // Pre-process input text
      final inputIds = _tokenize(rawText);
      final inputMask = List.filled(MAX_SEQ_LENGTH, 1);
      final segmentIds = List.filled(MAX_SEQ_LENGTH, 0);

      // Prepare input tensors
      final input = [
        [inputIds],
        [inputMask],
        [segmentIds],
      ];

      // Prepare output tensor
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final outputBuffer = List.filled(
        outputShape.reduce((a, b) => a * b),
        0.0,
      ).reshape(outputShape);

      // Run inference
      _interpreter!.run(input, outputBuffer);

      // Post-process output
      return _processOutput(outputBuffer, rawText);
    } catch (e) {
      print('Error en corrección de texto: $e');
      return rawText; // Return original text if processing fails
    }
  }

  Future<String> processSceneDescription(String rawDescription) async {
    if (!_isInitialized) {
      throw Exception('TextCorrectionService no está inicializado');
    }

    try {
      // Template for scene description
      final template = '[CLS] convert this scene description to natural language: $rawDescription [SEP]';

      // Process through BERT
      final correctedText = await correctText(template);

      // Clean up the output
      return _formatSceneDescription(correctedText);
    } catch (e) {
      print('Error procesando descripción de escena: $e');
      return rawDescription;
    }
  }

  Map<String, int> _loadVocabulary(String vocabData) {
    final Map<String, int> vocab = {};
    final lines = vocabData.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final token = lines[i].trim();
      if (token.isNotEmpty) {
        vocab[token] = i;
      }
    }
    return vocab;
  }

  List<int> _tokenize(String text) {
    // Basic tokenization implementation
    final tokens = text.toLowerCase().split(' ');
    final List<int> inputIds = [_vocabMap!['[CLS]'] ?? 101]; // Start token

    for (final token in tokens) {
      // This line crashes if token not in vocab
      int tokenId = _vocabMap![token] ?? (_vocabMap!['[UNK]'] ?? 100);
      inputIds.add(tokenId);
      if (inputIds.length >= MAX_SEQ_LENGTH - 1) break;
    }

    inputIds.add(_vocabMap!['[SEP]'] ?? 102); // End token

    // Pad sequence to MAX_SEQ_LENGTH
    while (inputIds.length < MAX_SEQ_LENGTH) {
      inputIds.add(_vocabMap!['[PAD]'] ?? 0);
    }

    return inputIds;
  }

  String _processOutput(List<dynamic> output, String originalText) {
    try {
      print('Output shape: ${output.length}');
      print('Output type: ${output.runtimeType}');

      if (output.isEmpty || output[0] == null) {
        print('ERROR: Output is empty or null');
        return originalText;
      }

      // Convert logits to text
      final List<double> logits = List<double>.from(output[0]);
      final List<String> tokens = _convertLogitsToTokens(logits);

      // Post-process tokens
      return _assembleText(tokens);
    } catch (e) {
      print('Error procesando salida de BERT: $e');
      print('Stack trace: ${StackTrace.current}');
      return originalText;
    }
  }

  List<String> _convertLogitsToTokens(List<double> logits) {
    // Convert model output logits to tokens
    // Implementation depends on your specific model's output format
    return []; // Placeholder
  }

  String _assembleText(List<String> tokens) {
    // Remove special tokens and join
    return tokens
        .where((token) => !['[CLS]', '[SEP]', '[PAD]'].contains(token))
        .join(' ')
        .trim();
  }

  String _formatSceneDescription(String text) {
    // Remove template artifacts and format
    return text
        .replaceAll('convert this scene description to natural language:', '')
        .replaceAll('[CLS]', '')
        .replaceAll('[SEP]', '')
        .trim();
  }

  Future<void> dispose() async {
    try {
      _interpreter?.close();
      _isInitialized = false;
      _vocabMap = null;
    } catch (e) {
      print('Error disposing TextCorrectionService: $e');
    }
  }
}