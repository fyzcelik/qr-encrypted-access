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
  bool isQrScanned = false;
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
      allowedStudentIds = jsonMap
          .map((key, value) => MapEntry(key.trim(), value.toString().trim()));
    });
  }

  Future<void> decryptQrCode() async {
    final studentId = studentIdController.text.trim();

    if (!isQrScanned) {
      setState(() {
        resultMessage = 'Lütfen önce QR kodu okutun.';
      });
      return;
    }

    if (studentId.isEmpty) {
      setState(() {
        resultMessage = 'Lütfen okul numaranızı girin.';
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
      final keyBytes = sha256.convert(utf8.encode(schoolName)).bytes;
      final secretKey = SecretKey(keyBytes);
      final algorithm = AesGcm.with256bits();

      final encryptedBytes = base64.decode(qrData!);

      // QR koddan gelen birleşik veri çözülüyor (nonce + ciphertext + mac)
      final secretBox = SecretBox.fromConcatenation(
        encryptedBytes,
        nonceLength: 12,
        macLength: 16,
      );

      final decrypted = await algorithm.decrypt(
        secretBox,
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
    if (value == null || isQrScanned) return;
    setState(() {
      qrData = value;
      isQrScanned = true;
      resultMessage =
          "✅ QR kod başarıyla okundu. Lütfen okul numaranızı girip 'Mesajı Getir' butonuna tıklayın.";
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ QR Kod Okundu")),
    );
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
        child: Column(
          children: [
            if (!isQrScanned)
              SizedBox(
                height: 300,
                child: MobileScanner(
                  onDetect: (BarcodeCapture barcodeCapture) {
                    final List<Barcode> barcodes = barcodeCapture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final String code = barcodes.first.rawValue ?? '';
                      if (code.isNotEmpty) {
                        onQrScanned(code);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("❌ QR Kod Okunamadı")),
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
                  const Text(
                    'Okul Numarası',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: studentIdController,
                    enabled: isQrScanned, // 🔒 QR okutulmadan önce kapalı
                    decoration: const InputDecoration(
                      labelText: 'Okul Numarası',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed:
                        (!isQrScanned || isLoading) ? null : decryptQrCode,
                    child: const Text("📥 Mesajı Getir"),
                  ),
                  const SizedBox(height: 12),
                  if (resultMessage.isNotEmpty)
                    Text(
                      resultMessage,
                      style: const TextStyle(fontSize: 16),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
