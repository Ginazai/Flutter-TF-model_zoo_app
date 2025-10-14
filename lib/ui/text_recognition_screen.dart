import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../providers/ocr_provider.dart';

class TextRecognitionScreen extends StatelessWidget {
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
              // Camera preview
              Expanded(
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: ocrProvider.isProcessing
                        ? CircularProgressIndicator(color: Colors.white)
                        : Column(
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
                          Icon(Icons.volume_up, color: Colors.purple),
                          SizedBox(width: 8),
                          Text(
                            'Resultado:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        ocrProvider.lastResult?.correctedText ?? '',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),

              // Action button
              Padding(
                padding: EdgeInsets.all(16),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    minimumSize: Size(double.infinity, 56),
                  ),
                  onPressed: () async {
                    final imageBytes = await connectionProvider.esp32Service.captureImage();
                    if (imageBytes != null) {
                      await ocrProvider.processImage(imageBytes);
                    } else {
                      print('No se pudo capturar la imagen');
                      // Show error to user
                    }
                  },
                  child: Text(
                    'Capturar y Analizar',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
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
