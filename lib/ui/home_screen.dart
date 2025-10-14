import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import 'collision_detection_screen.dart';
import 'text_recognition_screen.dart';
import 'environment_description_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Consumer: escucha cambios del provider
    return Consumer<ConnectionProvider>(
      builder: (context, connectionProvider, child) {
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 80.0,
            backgroundColor: Colors.indigoAccent,
            title: Padding(
              padding: EdgeInsets.only(
                left: 10.0,
                right: 10.0,
                top: 31.0,
                bottom: 10.0
              ),
              child: Text(
                'Asistente Visual',
                style: TextStyle(
                    color: Colors.white
                ),
              ),
            ),
            actions: [
              Icon(
                connectionProvider.isConnected
                    ? Icons.wifi
                    : Icons.wifi_off,
                color: connectionProvider.isConnected
                    ? Colors.green
                    : Colors.red,
              ),
              SizedBox(width: 16),
            ],
          ),
          body: Column(
            children: [
              // Botón de conexión
              if (!connectionProvider.isConnected)
                _buildConnectionButton(context, connectionProvider),

              // Menú de funciones
              Expanded(
                child: ListView(
                  padding: EdgeInsets.all(16),
                  children: [
                    _buildFeatureCard(
                      context,
                      title: 'Reconocimiento de Texto',
                      icon: Icons.text_fields,
                      color: Colors.purple,
                      enabled: connectionProvider.isConnected,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TextRecognitionScreen(),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildFeatureCard(
                      context,
                      title: 'Detección de Colisiones',
                      icon: Icons.warning,
                      color: Colors.red,
                      enabled: connectionProvider.isConnected,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CollisionDetectionScreen(),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildFeatureCard(
                      context,
                      title: 'Descripcion de entorno',
                      icon: Icons.remove_red_eye,
                      color: Colors.green,
                      enabled: connectionProvider.isConnected,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EnvironmentDescriptionScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionButton(
      BuildContext context,
      ConnectionProvider provider,
      ) {
    return Container(
      padding: EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: () async {
          // Llamar al provider para conectar
          await provider.connect('192.168.4.1');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigoAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0), // Adjust the radius as needed
          ),
        ),
        child: Text(
          'Conectar a ESP32',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Color color,
        required bool enabled,
        required VoidCallback onTap,
      }) {
    return Card(
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: enabled
                ? LinearGradient(colors: [color, color.withOpacity(0.7)])
                : null,
            color: enabled ? null : Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 40, color: Colors.white),
              SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}