import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../providers/collision_provider.dart';
import 'dart:typed_data';

class CollisionDetectionScreen extends StatefulWidget {
  @override
  _CollisionDetectionScreenState createState() => _CollisionDetectionScreenState();
}

class _CollisionDetectionScreenState extends State<CollisionDetectionScreen> {
  Uint8List? _lastCapturedImage;

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConnectionProvider, CollisionProvider>(
      builder: (context, connectionProvider, collisionProvider, child) {
        return Scaffold(
          appBar: AppBar(
            leading: BackButton(color: Colors.white),
            title: Text('Detección de Colisiones'),
            backgroundColor: Colors.red[700],
          ),
          body: Column(
            children: [
              // Camera preview
              Expanded(
                child: Container(
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
                          child: Icon(
                            Icons.camera_alt,
                            size: 80,
                            color: Colors.white54,
                          ),
                        ),
                      // Monitoring overlay
                      if (collisionProvider.isMonitoring)
                        Positioned(
                          top: 16,
                          left: 16,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Monitoreando...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Results
              if (collisionProvider.lastResult != null)
                Container(
                  padding: EdgeInsets.all(16),
                  color: collisionProvider.hasCollisionRisk
                      ? Colors.red[100]
                      : Colors.green[100],
                  child: Row(
                    children: [
                      Icon(
                        collisionProvider.hasCollisionRisk
                            ? Icons.warning
                            : Icons.check_circle,
                        color: collisionProvider.hasCollisionRisk
                            ? Colors.red
                            : Colors.green,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Distancia: ${collisionProvider.lastResult!.minDistance.toStringAsFixed(2)} cm',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),

              // Control buttons
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
                  child: Column(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          minimumSize: Size(double.infinity, 56),
                        ),
                        onPressed: () async {
                          if (collisionProvider.isMonitoring) {
                            collisionProvider.stopMonitoring();
                          } else {
                            await collisionProvider.startMonitoring(() async {
                              final bytes = await connectionProvider
                                  .esp32Service
                                  .captureImage();
                              if (bytes != null) {
                                setState(() {
                                  _lastCapturedImage = bytes;
                                });
                              }
                              return bytes;
                            });
                          }
                        },
                        child: Text(
                          collisionProvider.isMonitoring
                              ? 'Detener'
                              : 'Iniciar Monitoreo',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                      SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          minimumSize: Size(double.infinity, 56),
                        ),
                        onPressed: () async {
                          await collisionProvider.captureOnce(() async {
                            final bytes = await connectionProvider
                                .esp32Service
                                .captureImage();
                            if (bytes != null) {
                              setState(() {
                                _lastCapturedImage = bytes;
                              });
                            }
                            return bytes;
                          });
                        },
                        child: Text(
                          'Capturar imagen (una vez)',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ],
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