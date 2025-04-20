import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

class QrDecryptPage extends StatefulWidget {
  @override
  _QrDecryptPageState createState() => _QrDecryptPageState();
}

class _QrDecryptPageState extends State<QrDecryptPage> {
  String? qrData;
  String studentId = '';
  String resultMessage = '';
  bool isLoading = false;

  Future<void> decryptQrCode() async {
    if (qrData == null || studentId.isEmpty) {
      setState(() {
        resultMessage = 'Lütfen QR kodu okutun ve okul numarasını girin.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      resultMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/decrypt'), // Android için
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'data': qrData, 'student_id': studentId}),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        setState(() {
          resultMessage = '📩 Mesaj: ${json['message']}';
        });
      } else {
        setState(() {
          resultMessage = '❌ Hata: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        resultMessage = '🔌 Ağ hatası: $e';
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
              )),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) => studentId = value,
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
