import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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
  Uint8List? hiddenImageBytes;

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

  Future<void> pickImage() async {
    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      hiddenImageBytes = await file.readAsBytes();
      setState(() {});
    }
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

      // QR koddan gelen birleşik veri çözülüyor (nonce + ciphertext + mac)
      final secretBox = SecretBox.fromConcatenation(
        hiddenImageBytes!,
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
    if (value == null || !isQrScanned) return;
    setState(() {
      qrData = value;
      isQrScanned = true;
    });
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
        title: const Text("QR Kod Çözme"),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const Text(
              'QR Kod Çözümleme',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            MobileScanner(
              onDetect: (BarcodeCapture barcodeCapture) {
                final List<Barcode> barcodes = barcodeCapture.barcodes;
                if (barcodes.isNotEmpty) {
                  final String? code = barcodes.first.rawValue;
                  if (code != null && code.isNotEmpty) {
                    onQrScanned(code);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("❌ QR Kod Okunamadı")),
                    );
                  }
                }
              },
            ),
            if (!isQrScanned)
              const Text(
                'Lütfen QR kodu tarayın.',
                style: TextStyle(fontSize: 16, color: Colors.red),
              ),
            if (qrData != null)
              Text(
                'QR Verisi: $qrData',
                style: const TextStyle(fontSize: 16, color: Colors.green),
              ),
            const SizedBox(height: 24),
            TextField(
              controller: studentIdController,
              decoration: const InputDecoration(
                labelText: 'Öğrenci Numarası',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: decryptQrCode,
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Çözümle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              resultMessage,
              style: const TextStyle(fontSize: 16, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}
