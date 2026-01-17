import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../providers/traffic_light_provider.dart';
import 'dart:typed_data';

class TrafficLightDetectionScreen extends StatefulWidget {
  @override
  _TrafficLightDetectionScreenState createState() =>
      _TrafficLightDetectionScreenState();
}

class _TrafficLightDetectionScreenState
    extends State<TrafficLightDetectionScreen> {
  Uint8List? _lastCapturedImage;
  bool _isProcessing = false;

  Future<void> _handleSingleDetection(
    TrafficLightProvider trafficLightProvider,
    ConnectionProvider connectionProvider,
  ) async {
    if (_isProcessing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ya hay un análisis en proceso, por favor espera...'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await trafficLightProvider.detectOnce(() async {
        final bytes = await connectionProvider.esp32Service.captureImage();
        if (bytes != null && mounted) {
          setState(() {
            _lastCapturedImage = bytes;
          });
        }
        return bytes;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Color _getStatusColor(TrafficLightProvider provider) {
    if (provider.lastResult == null) return Colors.grey;
    
    switch (provider.lastResult!.predictedClass) {
      case 0: // Red
        return Colors.red;
      case 1: // Green
        return Colors.green;
      case 2: // Countdown Green
        return Colors.amber;
      case 3: // Countdown Blank
        return Colors.orange;
      case 4: // None
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(TrafficLightProvider provider) {
    if (provider.lastResult == null) return Icons.traffic;
    
    switch (provider.lastResult!.predictedClass) {
      case 0: // Red
        return Icons.stop_circle;
      case 1: // Green
        return Icons.check_circle;
      case 2: // Countdown Green
        return Icons.timer;
      case 3: // Countdown Blank
        return Icons.warning_amber;
      case 4: // None
        return Icons.visibility_off;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildProbabilityBar(String label, double probability, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              Text(
                '${(probability * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: probability,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConnectionProvider, TrafficLightProvider>(
      builder: (context, connectionProvider, trafficLightProvider, child) {
        final statusColor = _getStatusColor(trafficLightProvider);
        
        return Scaffold(
          appBar: AppBar(
            leading: BackButton(color: Colors.white),
            title: Text('Detección de Semáforos'),
            backgroundColor: statusColor,
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
                            Icons.traffic,
                            size: 80,
                            color: Colors.white54,
                          ),
                        ),
                      
                      // Monitoring overlay
                      if (trafficLightProvider.isMonitoring)
                        Positioned(
                          top: 16,
                          left: 16,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.9),
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
                      
                      // Processing overlay
                      if (_isProcessing && !trafficLightProvider.isMonitoring)
                        Container(
                          color: Colors.black54,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Detectando semáforo...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
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

              // Results panel
              if (trafficLightProvider.lastResult != null)
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    border: Border(
                      top: BorderSide(color: statusColor, width: 3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main status
                      Row(
                        children: [
                          Icon(
                            _getStatusIcon(trafficLightProvider),
                            size: 32,
                            color: statusColor,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trafficLightProvider.lastResult!.className,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                                Text(
                                  'Confianza: ${trafficLightProvider.lastResult!.confidence.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 16),
                      Divider(),
                      SizedBox(height: 8),
                      
                      // Probability breakdown
                      Text(
                        'Probabilidades por Clase:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      
                      _buildProbabilityBar(
                        'Rojo',
                        trafficLightProvider.lastResult!.allProbabilities[0],
                        Colors.red,
                      ),
                      _buildProbabilityBar(
                        'Verde',
                        trafficLightProvider.lastResult!.allProbabilities[1],
                        Colors.green,
                      ),
                      _buildProbabilityBar(
                        'Verde Intermitente',
                        trafficLightProvider.lastResult!.allProbabilities[2],
                        Colors.amber,
                      ),
                      _buildProbabilityBar(
                        'Intermitente',
                        trafficLightProvider.lastResult!.allProbabilities[3],
                        Colors.orange,
                      ),
                      _buildProbabilityBar(
                        'Sin Semáforo',
                        trafficLightProvider.lastResult!.allProbabilities[4],
                        Colors.grey,
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
                          backgroundColor: statusColor,
                          minimumSize: Size(double.infinity, 56),
                        ),
                        onPressed: _isProcessing
                            ? null
                            : () async {
                                if (trafficLightProvider.isMonitoring) {
                                  trafficLightProvider.stopMonitoring();
                                } else {
                                  await trafficLightProvider.startMonitoring(
                                    () async {
                                      final bytes = await connectionProvider
                                          .esp32Service
                                          .captureImage();
                                      if (bytes != null && mounted) {
                                        setState(() {
                                          _lastCapturedImage = bytes;
                                        });
                                      }
                                      return bytes;
                                    },
                                  );
                                }
                              },
                        child: Text(
                          trafficLightProvider.isMonitoring
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
                        onPressed: (_isProcessing ||
                                trafficLightProvider.isMonitoring)
                            ? null
                            : () => _handleSingleDetection(
                                  trafficLightProvider,
                                  connectionProvider,
                                ),
                        child: Text(
                          _isProcessing
                              ? 'Procesando...'
                              : 'Detectar semáforo (una vez)',
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