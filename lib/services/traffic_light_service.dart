import 'dart:typed_data';
import 'dart:math' as math;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../models/traffic_light_model.dart';
import '../utils/logger.dart';
import 'dart:typed_data';

extension Reshape on Uint8List {
  List reshape(List<int> shape) {
    return this;
  }
}

class TrafficLightService {
  Interpreter? _interpreter;
  bool _isInitialized = false;
  List<int> _inputShape = [];
  List<List<int>> _outputShapes = [];
  bool _inferenceRunning = false;
  
  int? _classifierOutputIndex;
  int? _regressionOutputIndex;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/traffic_light/LYTNet_int8.tflite'
      );
      
      _inputShape = _interpreter!.getInputTensor(0).shape;
      
      // Get all output tensors
      final numOutputs = _interpreter!.getOutputTensors().length;
      _outputShapes = [];
      
      for (int i = 0; i < numOutputs; i++) {
        final outputShape = _interpreter!.getOutputTensor(i).shape;
        _outputShapes.add(outputShape);
        
        // Identify classifier (5 classes) and regression (4 points) outputs
        final lastDim = outputShape.last;
        if (lastDim == 5) {
          _classifierOutputIndex = i;
        } else if (lastDim == 4) {
          _regressionOutputIndex = i;
        }
      }
      
      _isInitialized = true;
      
      await Logger.log(
        'Traffic Light model initialized.\n'
        'inputShape=$_inputShape\n'
        'outputShapes=$_outputShapes\n'
        'classifierIndex=$_classifierOutputIndex\n'
        'regressionIndex=$_regressionOutputIndex'
      );
    } catch (e) {
      await Logger.log('Error initializing traffic light model: $e');
      rethrow;
    }
  }

  Future<TrafficLightResult> detect(Uint8List imageBytes) async {
    if (!_isInitialized) await initialize();
    if (!_isInitialized) {
      await Logger.log('Traffic light model not initialized.');
      throw Exception('Model not initialized');
    }

    if (_inferenceRunning) {
      await Logger.log('Skipping detection - another inference is running.');
      throw Exception('Inference already running');
    }

    _inferenceRunning = true;

    try {
      if (_classifierOutputIndex == null || _regressionOutputIndex == null) {
        final message = 'Model output indices not found. Classifier: $_classifierOutputIndex, Regression: $_regressionOutputIndex';
        await Logger.log(message);
        throw Exception(message);
      }

      final stopwatch = Stopwatch()..start();

      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        await Logger.log('Failed to decode image.');
        throw Exception('Invalid image');
      }

      // Get expected input dimensions
      final inputHeight = _inputShape[1];
      final inputWidth = _inputShape[2];
      final inputChannels = _inputShape[3];

      await Logger.log('Resizing image to ${inputWidth}x${inputHeight}');

      // Resize image to match model input (768x576 from Python script)
      final resized = img.copyResize(
        image,
        width: inputWidth,
        height: inputHeight,
      );

      // Prepare input tensor
      final input = _prepareInput(resized, inputHeight, inputWidth, inputChannels);

      // Prepare output buffers
      final outputs = _prepareOutputs();

      await Logger.log('Running inference...');

      // Run inference
      if (_outputShapes.length == 2 && _classifierOutputIndex != null && _regressionOutputIndex != null) {
        try {
          // Create output buffers as nested lists to match expected format
          var outputsMap = <int, Object>{};
          outputsMap[0] = List<List<int>>.generate(1, (_) => List<int>.filled(4, 0));
          outputsMap[1] = List<List<int>>.generate(1, (_) => List<int>.filled(5, 0));

          await Logger.log('Output buffers created');
          await Logger.log('About to call interpreter.runForMultipleInputs...');

          // Use runForMultipleInputs directly
          _interpreter!.runForMultipleInputs([input], outputsMap);

          await Logger.log('interpreter.runForMultipleInputs completed successfully');

          // Extract the actual data from the output map
          outputs[0] = outputsMap[0] as List<List<int>>;
          outputs[1] = outputsMap[1] as List<List<int>>;

          await Logger.log('Inference completed, outputs updated');
        } catch (e, stackTrace) {
          await Logger.log('Error during inference: $e');
          await Logger.log('Stack trace: $stackTrace');
          rethrow;
        }
      } else {
        throw Exception('Invalid output configuration');
      }

      stopwatch.stop();
      await Logger.log('Inference completed in ${stopwatch.elapsedMilliseconds}ms');

      try {
        // Extract and process outputs
        await Logger.log('Extracting outputs... classifier index: $_classifierOutputIndex, regression index: $_regressionOutputIndex');

        final classifierOutput = outputs[_classifierOutputIndex!]![0] as List;
        await Logger.log('Classifier output extracted: ${classifierOutput.length} values');

        final regressionOutput = outputs[_regressionOutputIndex!]![0] as List;
        await Logger.log('Regression output extracted: ${regressionOutput.length} values');

        // Dequantize outputs
        final logits = _dequantizeOutput(
            classifierOutput,
            _classifierOutputIndex!
        );
        final directions = _dequantizeOutput(
            regressionOutput,
            _regressionOutputIndex!
        );

        // Apply softmax to get probabilities
        final probabilities = _softmax(logits);

        // Get predicted class
        int predictedClass = 0;
        double maxProb = probabilities[0];
        for (int i = 1; i < probabilities.length; i++) {
          if (probabilities[i] > maxProb) {
            maxProb = probabilities[i];
            predictedClass = i;
          }
        }

        final confidence = maxProb * 100.0;
        final className = TrafficLightResult.classNames[predictedClass] ?? 'Unknown';

        await Logger.log(
            'Detection result: $className (class $predictedClass) '
                'with ${confidence.toStringAsFixed(1)}% confidence'
        );

        return TrafficLightResult(
          predictedClass: predictedClass,
          className: className,
          confidence: confidence,
          directionPoints: directions,
          allProbabilities: probabilities,
        );
      } catch (e, stackTrace) {
        await Logger.log('Error extracting/processing outputs: $e');
        await Logger.log('Stack trace: $stackTrace');
        rethrow;
      }

    } finally {
      _inferenceRunning = false;
    }
  }

  dynamic _prepareInput(
      img.Image image,
      int height,
      int width,
      int channels,
      ) {
    final inputType = _interpreter!.getInputTensor(0).type;

    // Check if quantized by comparing the string representation
    final isQuantized = inputType.toString().toLowerCase().contains('uint8') ||
        inputType.toString().toLowerCase().contains('int8');

    Logger.log('Input type: $inputType, isQuantized: $isQuantized');

    if (isQuantized) {
      Logger.log('Preparing uint8 input...');

      // Manually extract each pixel value to guarantee int type
      final input = <List<List<List<int>>>>[];
      final batch = <List<List<int>>>[];

      for (int y = 0; y < height; y++) {
        final row = <List<int>>[];
        for (int x = 0; x < width; x++) {
          final pixel = image.getPixel(x, y);

          final r = pixel.r.truncate();
          final g = pixel.g.truncate();
          final b = pixel.b.truncate();

          final pixelList = <int>[r, g, b];
          row.add(pixelList);
        }
        batch.add(row);
      }
      input.add(batch);

      return input;
    } else {
      Logger.log('Preparing float32 input...');

      return List.generate(
        1,
            (_) => List.generate(
          height,
              (y) => List.generate(
            width,
                (x) {
              final pixel = image.getPixel(x, y);
              return [
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0,
              ];
            },
          ),
        ),
      );
    }
  }

  Map<int, List<List<dynamic>>> _prepareOutputs() {
    Map<int, List<List<dynamic>>> outputs = {};

    for (int i = 0; i < _outputShapes.length; i++) {
      final shape = _outputShapes[i];
      final outputType = _interpreter!.getOutputTensor(i).type;

      // Check output type by string representation
      final isQuantizedOutput = outputType.toString().toLowerCase().contains('uint8') ||
          outputType.toString().toLowerCase().contains('int8');

      Logger.log('Output $i: shape=$shape, type=$outputType, isQuantized=$isQuantizedOutput');

      if (isQuantizedOutput) {
        // Quantized output
        outputs[i] = List.generate(
          shape[0],
              (_) => List.filled(shape[1], 0),
        );
      } else {
        // Float output
        outputs[i] = List.generate(
          shape[0],
              (_) => List.filled(shape[1], 0.0),
        );
      }
    }

    return outputs;
  }

  List<double> _dequantizeOutput(List values, int outputIndex) {
    final outputTensor = _interpreter!.getOutputTensor(outputIndex);
    final outputType = outputTensor.type;

    final isQuantized = outputType.toString().toLowerCase().contains('uint8') ||
        outputType.toString().toLowerCase().contains('int8');

    if (isQuantized) {
      // Dequantize: (value - zeroPoint) * scale
      final params = outputTensor.params;
      final scale = params.scale;
      final zeroPoint = params.zeroPoint;

      Logger.log('Dequantizing output $outputIndex: scale=$scale, zeroPoint=$zeroPoint');

      return values.map((v) {
        final intVal = v is int ? v : (v as double).toInt();
        return (intVal - zeroPoint) * scale;
      }).toList();
    } else {
      // Already float
      return values.map((v) => (v as num).toDouble()).toList();
    }
  }

  List<double> _softmax(List<double> logits) {
    // Find max for numerical stability
    double maxLogit = logits[0];
    for (int i = 1; i < logits.length; i++) {
      if (logits[i] > maxLogit) maxLogit = logits[i];
    }
    
    // Compute exp(x - max)
    final expValues = logits.map((x) => math.exp(x - maxLogit)).toList();
    
    // Sum of exponentials
    final sumExp = expValues.fold(0.0, (sum, val) => sum + val);
    
    // Normalize
    return expValues.map((val) => val / sumExp).toList();
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    Logger.log('TrafficLightService disposed.');
  }
}
