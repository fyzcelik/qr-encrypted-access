import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';
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
    if (messageController.text.isEmpty) {
      setState(() {
        qrCodeData = 'Lütfen bir mesaj girin.';
      });
      return;
    }

    setState(() {
      isGenerating = true;
      qrCodeData = '';
    });

    try {
      final secretKey = SecretKey(utf8.encode('mySecretKey1234'));
      final encrypter = AesGcm.with256bits();
      final cipherText = await encrypter.encrypt(
        utf8.encode(messageController.text),
        secretKey: secretKey,
      );

      final encodedMessage = base64.encode(cipherText.cipherText);
      setState(() {
        qrCodeData = encodedMessage;
      });
    } catch (e) {
      setState(() {
        qrCodeData = 'Şifreleme hatası: $e';
      });
    } finally {
      setState(() => isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("QR Kod Oluşturma")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: messageController,
              decoration: InputDecoration(
                labelText: 'Mesajınızı girin',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: isGenerating ? null : generateQrCode,
              child: Text("QR Kod Oluştur"),
            ),
            SizedBox(height: 12),
            if (qrCodeData != null && qrCodeData!.isNotEmpty)
              Column(
                children: [
                  Text(
                    'Şifreli Mesaj:',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  QrImageView(
                    data: qrCodeData!,
                    version: QrVersions.auto,
                    size: 200.0,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
