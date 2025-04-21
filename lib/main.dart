import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:crypto/crypto.dart';
import 'package:qr_encrypted_access/interface/qr_decrypt_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Encrypted Access',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Uygulaması')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('QR Kod Tara'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => QrDecryptPage()),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code),
              label: const Text('QR Kod Oluştur'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => QrGeneratePage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class QrGeneratePage extends StatefulWidget {
  @override
  _QrGeneratePageState createState() => _QrGeneratePageState();
}

class _QrGeneratePageState extends State<QrGeneratePage> {
  final TextEditingController messageController = TextEditingController();
  final TextEditingController studentIdController = TextEditingController();
  String? qrCodeData;
  String? errorMessage;
  bool isGenerating = false;

  final nonce = List<int>.filled(12, 1); // Sabit nonce (aynı değer çözme tarafında da kullanılmalı)

  Future<void> generateQrCode() async {
    final message = messageController.text.trim();
    final studentId = studentIdController.text.trim();

    if (message.isEmpty || studentId.isEmpty) {
      setState(() {
        errorMessage = 'Lütfen mesaj ve okul numarasını girin.';
        qrCodeData = null;
      });
      return;
    }

    setState(() {
      isGenerating = true;
      qrCodeData = null;
      errorMessage = null;
    });

    try {
      // Şifreleme anahtarını okul numarasından türet
      final keyBytes = sha256.convert(utf8.encode(studentId)).bytes;
      final secretKey = SecretKey(keyBytes);

      final encrypter = AesGcm.with256bits();
      final cipherText = await encrypter.encrypt(
        utf8.encode(message),
        secretKey: secretKey,
        nonce: nonce,
      );

      final encodedMessage = base64.encode(cipherText.cipherText);

      setState(() {
        qrCodeData = encodedMessage;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Şifreleme hatası: $e';
      });
    } finally {
      setState(() => isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("QR Kod Oluşturma")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: studentIdController,
              decoration: const InputDecoration(
                labelText: 'Okul Numarası',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Mesajınızı girin',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: isGenerating ? null : generateQrCode,
              child: const Text("QR Kod Oluştur"),
            ),
            const SizedBox(height: 12),
            if (isGenerating) const CircularProgressIndicator(),

            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(errorMessage!, style: const TextStyle(color: Colors.red)),
            ],

            if (qrCodeData != null && qrCodeData!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Şifreli Mesaj:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              QrImageView(
                data: qrCodeData!,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
