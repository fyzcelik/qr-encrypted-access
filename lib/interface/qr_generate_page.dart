import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class QrGeneratePage extends StatefulWidget {
  @override
  _QrGeneratePageState createState() => _QrGeneratePageState();
}

class _QrGeneratePageState extends State<QrGeneratePage> {
  final TextEditingController messageController = TextEditingController();
  String? qrCodeData;
  bool isGenerating = false;
  Uint8List? hiddenImageBytes;
  bool isImageHidden = false;

  Future<void> generateQrCode() async {
    final message = messageController.text.trim();
    if (message.isEmpty) {
      setState(() {
        qrCodeData = 'Lütfen mesaj girin.';
        hiddenImageBytes = null;
        isImageHidden = false;
      });
      return;
    }

    final schoolName = "Kırıkkale Üniversitesi";

    setState(() {
      isGenerating = true;
      qrCodeData = '';
      hiddenImageBytes = null;
      isImageHidden = false;
    });

    try {
      final keyBytes = sha256.convert(utf8.encode(schoolName)).bytes;
      final secretKey = SecretKey(keyBytes);
      final nonce = List<int>.filled(12, 1);

      final algorithm = AesGcm.with256bits();
      final secretBox = await algorithm.encrypt(
        utf8.encode(message),
        secretKey: secretKey,
        nonce: nonce,
      );

      final encryptedCombined = secretBox.concatenation();
      final encodedMessage = base64.encode(encryptedCombined);

      final painter = QrPainter(
        data: encodedMessage,
        version: QrVersions.auto,
        gapless: true,
        color: Colors.black,
        emptyColor: Colors.white,
      );

      final picData = await painter.toImageData(300);
      if (picData != null) {
        final qrBytes = picData.buffer.asUint8List();

        // QR'ı beyaz bir görselin içine gizle
        final int size = 300;
        final Uint8List coverBytes =
            Uint8List.fromList(List.filled(size * size * 4, 255));
        final Uint8List result = Uint8List(coverBytes.length);

        for (int i = 0; i < qrBytes.length && i < coverBytes.length; i++) {
          result[i] =
              (coverBytes[i] & 0xFE) | ((qrBytes[i] & 0x80) >> 7); // MSB -> LSB
        }

        setState(() {
          hiddenImageBytes = result;
          isImageHidden = true;
        });

        // Kaydetme işlemi
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/hidden_qr_image.png');
        await file.writeAsBytes(result);
      }
    } catch (e) {
      setState(() {
        qrCodeData = 'Şifreleme hatası: $e';
        hiddenImageBytes = null;
        isImageHidden = false;
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
            if (isImageHidden)
              Column(
                children: [
                  const Text(
                    'Gizlenmiş QR Görseli:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Image.memory(
                      hiddenImageBytes!,
                      width: 300,
                      height: 300,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            if (isImageHidden)
              ElevatedButton.icon(
                onPressed: () async {
                  final directory = await getApplicationDocumentsDirectory();
                  final file = File('${directory.path}/hidden_qr_image.png');
                  // Dosya kaydetme veya paylaşma işlemleri yapılabilir.
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Görsel kaydedildi: ${file.path}")),
                  );
                },
                icon: const Icon(Icons.save),
                label: const Text("Resmi Kaydet"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
