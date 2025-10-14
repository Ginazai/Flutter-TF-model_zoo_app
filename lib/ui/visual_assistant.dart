import 'package:flutter/material.dart';

class VisualAssistMockup extends StatefulWidget {
  const VisualAssistMockup({super.key});

  @override
  _VisualAssistMockupState createState() => _VisualAssistMockupState();
}

class _VisualAssistMockupState extends State<VisualAssistMockup> {
  String screen = 'home';
  bool isConnected = false;
  bool isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screen == 'home'
          ? HomeScreen()
          : ProcessingScreen(
        title: screen == 'text'
            ? 'Reconocimiento de Texto'
            : screen == 'collision'
            ? 'Detección de Colisiones'
            : 'Descripción de Entorno',
        color: screen == 'text'
            ? Colors.purple
            : screen == 'collision'
            ? Colors.red
            : Colors.green,
      ),
    );
  }

  Widget HomeScreen() {
    return Column(
      children: [
        // Header
        Container(
          color: Colors.indigoAccent,
          padding: const EdgeInsets.only(top: 60, bottom: 12, left: 12, right: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Asistente Visual',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    isConnected ? Icons.wifi : Icons.wifi_off,
                    color: isConnected ? Colors.greenAccent : Colors.redAccent,
                  ),
                ],
              ),
              Text(
                isConnected ? 'Conectado a ESP32' : 'Desconectado',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),

        // Connection Button
        if (!isConnected)
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () => setState(() => isConnected = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigoAccent,
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10), // Adjust the value for desired roundness
                ),
              ),
              child: const Text(
                'Conectar a ESP32',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),

        // Main Menu
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Selecciona una funcionalidad:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              buildOption(
                title: 'Reconocimiento de Texto',
                description: 'Lee texto de señales, documentos y pantallas',
                color: Colors.purple,
                icon: Icons.text_fields,
                onTap: () => setState(() => screen = 'text'),
              ),
              buildOption(
                title: 'Detección de Colisiones',
                description: 'Alerta sobre obstáculos en tu camino',
                color: Colors.red,
                icon: Icons.camera_alt,
                onTap: () => setState(() => screen = 'collision'),
              ),
              buildOption(
                title: 'Descripción de Entorno',
                description: 'Obtén una descripción de tu alrededor',
                color: Colors.green,
                icon: Icons.remove_red_eye,
                onTap: () => setState(() => screen = 'environment'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildOption({
    required String title,
    required String description,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isConnected ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isConnected ? color : Colors.grey,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget ProcessingScreen({required String title, required Color color}) {
    return Column(
      children: [
        // Header
        Container(
          color: color,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => screen = 'home'),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // Camera Preview Area
        Expanded(
          child: Container(
            color: Colors.black,
            child: Center(
              child: isProcessing
                  ? Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Procesando imagen...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              )
                  : const Icon(Icons.camera_alt, color: Colors.white, size: 100),
            ),
          ),
        ),

        // Results Area
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Resultado:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                isProcessing
                    ? 'Esperando resultado...'
                    : title == 'Reconocimiento de Texto'
                    ? 'Texto: "CALLE PRINCIPAL - NO ESTACIONAR"'
                    : title == 'Detección de Colisiones'
                    ? 'Advertencia: Objeto detectado a 2 metros al frente'
                    : 'Estás en una calle urbana con edificios a ambos lados.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => setState(() => isProcessing = !isProcessing),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  isProcessing ? 'Detener' : 'Capturar y Analizar',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}