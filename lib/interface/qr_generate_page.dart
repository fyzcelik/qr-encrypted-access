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
  final TextEditingController studentIdController = TextEditingController();
  String? qrCodeData;
  bool isGenerating = false;
  Map<String, String> allowedStudentIds =
      {}; // Assuming this is populated from JSON

  Future<void> generateQrCode() async {
    final message = messageController.text.trim();
    final studentId = studentIdController.text.trim();

    if (message.isEmpty || studentId.isEmpty) {
      setState(() {
        qrCodeData = 'Lütfen öğrenci numarası ve mesaj girin.';
      });
      return;
    }

    final schoolName = allowedStudentIds[studentId];
    if (schoolName == null) {
      setState(() {
        qrCodeData = 'Bu öğrenci numarasına ait erişim izni bulunmamaktadır.';
      });
      return;
    }

    setState(() {
      isGenerating = true;
      qrCodeData = '';
    });

    try {
      // ✅ Aynı şekilde: öğrenci numarasına göre anahtar üret
      final keyBytes = sha256.convert(utf8.encode(studentId)).bytes;
      final secretKey = SecretKey(keyBytes);

      // ✅ Sabit nonce (12 bayt uzunluğunda olmalı)
      final nonce = List.filled(12, 1);

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
      appBar: AppBar(title: Text("QR Kod Oluşturma")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.qr_code, size: 80, color: Colors.deepPurple),
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
              controller: studentIdController,
              decoration: const InputDecoration(
                labelText: 'Öğrenci Numarası',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
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
              icon: const Icon(Icons.lock),
              label: const Text("QR Kod Oluştur"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 24),
            if (qrCodeData != null && qrCodeData!.isNotEmpty)
              Column(
                children: [
                  const Text(
                    'Şifreli Mesaj:',
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
