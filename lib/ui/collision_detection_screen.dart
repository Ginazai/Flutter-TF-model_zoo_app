import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../providers/collision_provider.dart';

class CollisionDetectionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Consumer2: escucha DOS providers
    return Consumer2<ConnectionProvider, CollisionProvider>(
      builder: (context, connectionProvider, collisionProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Detección de Colisiones'),
            backgroundColor: Colors.red[700],
          ),
          body: Column(
            children: [
              // Vista previa (simulada)
              Expanded(
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: collisionProvider.isMonitoring
                        ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Monitoreando...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    )
                        : Icon(
                      Icons.camera_alt,
                      size: 80,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ),

              // Información de distancia
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
                        'Distancia: ${collisionProvider.lastResult!.minDistance.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),

              // Botón de control
              Padding(
                padding: EdgeInsets.all(16),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    minimumSize: Size(double.infinity, 56),
                  ),
                  onPressed: () async {
                    if (collisionProvider.isMonitoring) {
                      collisionProvider.stopMonitoring();
                    } else {
                      // Pasar función que capture imagen del ESP32
                      await collisionProvider.startMonitoring(() async {
                        return await connectionProvider.esp32Service.captureImage();
                      });
                    }
                  },
                  child: Text(
                    collisionProvider.isMonitoring
                        ? 'Detener'
                        : 'Iniciar Monitoreo',
                    style: TextStyle(fontSize: 18),
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