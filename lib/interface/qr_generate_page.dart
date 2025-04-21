import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrGeneratePage extends StatefulWidget {
  @override
  _QrGeneratePageState createState() => _QrGeneratePageState();
}

class _QrGeneratePageState extends State<QrGeneratePage> {
  final TextEditingController messageController = TextEditingController();
  String? qrCodeData;
  bool isGenerating = false;

  Future<void> generateQrCode() async {
    final message = messageController.text.trim();
    if (message.isEmpty) {
      setState(() {
        qrCodeData = 'Lütfen mesaj girin.';
      });
      return;
    }

    final schoolName = "Kırıkkale Üniversitesi";

    setState(() {
      isGenerating = true;
      qrCodeData = '';
    });

    try {
      final keyBytes = sha256.convert(utf8.encode(schoolName)).bytes;
      final secretKey = SecretKey(keyBytes);
      final nonce = List<int>.filled(12, 1); // AES-GCM için 12 byte nonce

      final algorithm = AesGcm.with256bits();
      final secretBox = await algorithm.encrypt(
        utf8.encode(message),
        secretKey: secretKey,
        nonce: nonce,
      );

      // Tüm şifreli veri + nonce + mac birleştirilerek tek parça yapılır
      final encryptedCombined = secretBox.concatenation();
      final encodedMessage = base64.encode(encryptedCombined);

      setState(() {
        qrCodeData = encodedMessage;
      });
    } catch (e) {
      setState(() {
        qrCodeData = 'Şifreleme hatası: $e';
      });
    } finally {
      if (mounted) {
        setState(() => isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text(
            'Geri',
            style: TextStyle(color: Colors.white),
          ),
        ),
        title: const Text("QR Kod Oluşturma"),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Text(
              'QR Kod Oluştur',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Mesajınızı girin',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: isGenerating ? null : generateQrCode,
              label: const Text("QR Kod Oluştur"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            if (qrCodeData != null && qrCodeData!.isNotEmpty)
              Column(
                children: [
                  const Text(
                    'Şifreli Mesaj (QR Kod):',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: QrImageView(
                      data: qrCodeData!,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
