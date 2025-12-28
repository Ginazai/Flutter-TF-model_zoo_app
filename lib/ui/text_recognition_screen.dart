import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../providers/ocr_provider.dart';
import 'dart:typed_data';

class TextRecognitionScreen extends StatefulWidget {
  @override
  _TextRecognitionScreenState createState() => _TextRecognitionScreenState();
}

class _TextRecognitionScreenState extends State<TextRecognitionScreen> {
  Uint8List? _lastCapturedImage;

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConnectionProvider, OCRProvider>(
      builder: (context, connectionProvider, ocrProvider, child) {
        return Scaffold(
          appBar: AppBar(
            leading: BackButton(color: Colors.white),
            title: Text('Reconocimiento de Texto'),
            backgroundColor: Colors.purple,
          ),
          body: Column(
            children: [
              // Camera preview with image
              Container(
                height: 300,
                color: Colors.black,
                child: Stack(
                  children: [
                    // Image preview
                    if (_lastCapturedImage != null)
                      Center(
                        child: Image.memory(
                          _lastCapturedImage!,
                          fit: BoxFit.contain,
                        ),
                      )
                    else
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 80,
                              color: Colors.white54,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Vista de cámara ESP32',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Processing overlay
                    if (ocrProvider.isProcessing)
                      Container(
                        color: Colors.black54,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 16),
                              Text(
                                'Procesando imagen...',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Scrollable content area
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Error message
                      if (ocrProvider.errorMessage != null)
                        Container(
                          padding: EdgeInsets.all(12),
                          color: Colors.red[100],
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  ocrProvider.errorMessage!,
                                  style: TextStyle(
                                    color: Colors.red[800],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Results
                      if (ocrProvider.lastResult != null)
                        Container(
                          padding: EdgeInsets.all(16),
                          color: Colors.grey[100],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text(
                                    'Texto Reconocido:',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Text(
                                  ocrProvider.lastResult!.rawText,
                                  style: TextStyle(
                                    fontSize: 16,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Confianza: ${(ocrProvider.lastResult!.confidence * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Action button (fixed at bottom)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      minimumSize: Size(double.infinity, 56),
                    ),
                    onPressed: ocrProvider.isProcessing
                        ? null
                        : () async {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => AlertDialog(
                          title: Text('Analizando...'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Esto puede tomar unos segundos'),
                            ],
                          ),
                        ),
                      );
                      try {
                        final imageBytes = await connectionProvider
                            .esp32Service
                            .captureImage();
                        if (imageBytes != null) {
                          setState(() {
                            _lastCapturedImage = imageBytes;
                          });
                          await ocrProvider.processImage(imageBytes);
                        }
                      } finally {
                        Navigator.pop(context);
                      }
                    },
                    child: Text(
                      ocrProvider.isProcessing
                          ? 'Analizando...'
                          : 'Capturar y Analizar',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}