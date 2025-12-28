import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../providers/scene_provider.dart';
import 'dart:typed_data';

class EnvironmentDescriptionScreen extends StatefulWidget {
  @override
  _EnvironmentDescriptionScreenState createState() =>
      _EnvironmentDescriptionScreenState();
}

class _EnvironmentDescriptionScreenState
    extends State<EnvironmentDescriptionScreen> {
  Uint8List? _lastCapturedImage;

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConnectionProvider, SceneDetectionProvider>(
      builder: (context, connectionProvider, sceneProvider, child) {
        return Scaffold(
          appBar: AppBar(
            leading: BackButton(color: Colors.white),
            title: Text('Descriptor de Escenas'),
            backgroundColor: Colors.green[700],
            actions: [
              if (sceneProvider.hasValidResult)
                IconButton(
                  icon: Icon(Icons.volume_up),
                  onPressed: () => sceneProvider.repeatLastDescription(),
                  tooltip: 'Repetir descripción',
                ),
              if (sceneProvider.history.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.delete_sweep),
                  onPressed: () => sceneProvider.clearHistory(),
                  tooltip: 'Limpiar historial',
                ),
            ],
          ),
          body: Column(
            children: [
              // Preview container
              Container(
                height: 250,
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
                              Icons.landscape,
                              size: 80,
                              color: Colors.white54,
                            ),
                            SizedBox(height: 16),
                            Text(
                              sceneProvider.isMonitoring
                                  ? 'Modo monitoreo activo'
                                  : 'Listo para detectar',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Processing overlay
                    if (sceneProvider.isProcessing)
                      Container(
                        color: Colors.black54,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                color: Colors.green[400],
                              ),
                              SizedBox(height: 16),
                              Text(
                                sceneProvider.isMonitoring
                                    ? 'Monitoreando escena...'
                                    : 'Analizando escena...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Monitoring indicator
                    if (sceneProvider.isMonitoring && !sceneProvider.isProcessing)
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fiber_manual_record,
                                  color: Colors.red, size: 12),
                              SizedBox(width: 8),
                              Text(
                                'EN VIVO',
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

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Scene result
                      if (sceneProvider.lastResult != null)
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: sceneProvider.lastResult!.isHighConfidence
                                ? Colors.green[50]
                                : Colors.orange[50],
                            border: Border(
                              top: BorderSide(
                                color: sceneProvider.lastResult!.isHighConfidence
                                    ? Colors.green
                                    : Colors.orange,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    sceneProvider.lastResult!.isHighConfidence
                                        ? Icons.check_circle
                                        : Icons.info,
                                    color: sceneProvider.lastResult!.isHighConfidence
                                        ? Colors.green[700]
                                        : Colors.orange[700],
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      sceneProvider.lastResult!.naturalDescription,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  Chip(
                                    label: Text(
                                      sceneProvider.lastResult!.rawLabel
                                          .replaceAll('_', ' '),
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    backgroundColor: Colors.green[100],
                                  ),
                                  Chip(
                                    label: Text(
                                      'Confianza: ${sceneProvider.lastResult!.confidenceLevel}',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    backgroundColor: Colors.green[100],
                                  ),
                                  Chip(
                                    label: Text(
                                      '${(sceneProvider.lastResult!.confidence * 100).toStringAsFixed(0)}%',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    backgroundColor: Colors.green[100],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                      // History
                      if (sceneProvider.history.isNotEmpty)
                        Container(
                          height: 120,
                          padding: EdgeInsets.symmetric(vertical: 8),
                          color: Colors.grey[100],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'Historial',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                              SizedBox(height: 4),
                              Expanded(
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: sceneProvider.history.length,
                                  itemBuilder: (context, index) {
                                    final scene = sceneProvider.history[index];
                                    return Container(
                                      width: 140,
                                      margin: EdgeInsets.only(right: 8),
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.green[200]!),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            scene.rawLabel.replaceAll('_', ' '),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: 4),
                                          LinearProgressIndicator(
                                            value: scene.confidence,
                                            backgroundColor: Colors.grey[300],
                                            valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.green[700]!,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            '${(scene.confidence * 100).toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
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
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          minimumSize: Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(Icons.camera_alt, size: 24),
                        label: Text(
                          'Detectar Escena Ahora',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                        onPressed: sceneProvider.isProcessing
                            ? null
                            : () async {
                          final imageBytes = await connectionProvider
                              .esp32Service
                              .captureImage();
                          if (imageBytes != null) {
                            setState(() {
                              _lastCapturedImage = imageBytes;
                            });
                            await sceneProvider.detectScene(imageBytes);
                          }
                        },
                      ),
                      SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: sceneProvider.isMonitoring
                              ? Colors.red[600]
                              : Colors.green[700],
                          minimumSize: Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(
                          sceneProvider.isMonitoring
                              ? Icons.stop
                              : Icons.play_arrow,
                          size: 24,
                        ),
                        label: Text(
                          sceneProvider.isMonitoring
                              ? 'Detener Monitoreo'
                              : 'Iniciar Monitoreo Continuo',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                        onPressed: () async {
                          if (sceneProvider.isMonitoring) {
                            sceneProvider.stopMonitoring();
                          } else {
                            await sceneProvider.startMonitoring(
                                  () async {
                                final bytes = await connectionProvider
                                    .esp32Service
                                    .captureImage();
                                if (bytes != null) {
                                  setState(() {
                                    _lastCapturedImage = bytes;
                                  });
                                }
                                return bytes;
                              },
                              interval: Duration(seconds: 5),
                            );
                          }
                        },
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