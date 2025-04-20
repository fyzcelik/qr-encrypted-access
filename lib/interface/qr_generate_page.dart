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
      // Use a key based on the school name
      final secretKey = SecretKey(utf8.encode(schoolName));
      final encrypter = AesGcm.with256bits();
      final cipherText = await encrypter.encrypt(
        utf8.encode(message),
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
      if (mounted) {
        setState(() => isGenerating = false);
      }
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
              controller: studentIdController,
              decoration: InputDecoration(
                labelText: 'Öğrenci Numarası',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
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
