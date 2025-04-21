import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart';

class QrDecryptPage extends StatefulWidget {
  @override
  _QrDecryptPageState createState() => _QrDecryptPageState();
}

class _QrDecryptPageState extends State<QrDecryptPage> {
  String? qrData;
  String resultMessage = '';
  bool isLoading = false;
  final TextEditingController studentIdController = TextEditingController();
  Map<String, String> allowedStudentIds = {};

  @override
  void initState() {
    super.initState();
    loadStudentIds();
  }

  Future<void> loadStudentIds() async {
    final jsonString = await rootBundle.loadString('assets/student_ids.json');
    final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
    setState(() {
      allowedStudentIds =
          jsonMap.map((key, value) => MapEntry(key, value.toString()));
    });
  }

  Future<void> decryptQrCode() async {
    final studentId = studentIdController.text.trim();

    if (qrData == null || studentId.isEmpty) {
      setState(() {
        resultMessage = 'Lütfen QR kodu okutun ve okul numarasını girin.';
      });
      return;
    }

    final schoolName = allowedStudentIds[studentId];
    if (schoolName == null) {
      setState(() {
        resultMessage = 'Bu öğrenci numarasına ait kayıt bulunamadı.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      resultMessage = '';
    });

    try {
      // ✅ Şifreleme ile aynı şekilde: öğrenci numarasını SHA256 ile hashle
      final keyBytes = sha256.convert(utf8.encode(studentId)).bytes;
      final secretKey = SecretKey(keyBytes);

      // ✅ Sabit nonce kullan (QR üretme kısmında da aynısı olmalı!)
      final nonce = List.filled(12, 1);

      final encrypter = AesGcm.with256bits();
      final cipherBytes = base64.decode(qrData!);

      final decrypted = await encrypter.decrypt(
        SecretBox(cipherBytes, nonce: nonce, mac: Mac.empty),
        secretKey: secretKey,
      );

      setState(() {
        resultMessage = '📩 Mesaj: ${utf8.decode(decrypted)}';
      });
    } catch (e) {
      setState(() {
        resultMessage = '❌ Şifre çözme hatası: $e';
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  void onQrScanned(String? value) {
    if (value == null) return;
    setState(() {
      qrData = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("QR Şifre Çözme")),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: MobileScanner(
              onDetect: (BarcodeCapture barcodeCapture) {
                final List<Barcode> barcodes = barcodeCapture.barcodes;
                if (barcodes.isNotEmpty) {
                  final String code = barcodes.first.rawValue ?? '';
                  if (code.isNotEmpty) {
                    onQrScanned(code);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("✅ QR Kod Okundu")),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("❌ QR Kod Okunamadı")),
                    );
                  }
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'Okul Numarası',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: studentIdController,
                  decoration: InputDecoration(
                    labelText: 'Okul Numarası',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 12),
                ElevatedButton(
                  onPressed: isLoading ? null : decryptQrCode,
                  child: Text("📥 Mesajı Getir"),
                ),
                SizedBox(height: 12),
                if (resultMessage.isNotEmpty)
                  Text(
                    resultMessage,
                    style: TextStyle(fontSize: 16),
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
