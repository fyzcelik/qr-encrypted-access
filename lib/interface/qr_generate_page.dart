import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class QrGeneratePage extends StatefulWidget {
  @override
  _QrGeneratePageState createState() => _QrGeneratePageState();
}

class _QrGeneratePageState extends State<QrGeneratePage> {
  String? qrCodeData;
  Uint8List? hiddenImageBytes;
  bool isImageVisible = false;
  final TextEditingController messageController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  Future<void> generateAndHideQr() async {
    final message = messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lütfen bir mesaj giriniz')),
      );
      return;
    }

    // Resim seçme
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    // API'ye gönder
    final uri = Uri.parse("http://10.0.2.2:8000/qr_gizle");
    final request = http.MultipartRequest('POST', uri)
      ..fields['mesaj'] = message
      ..files.add(await http.MultipartFile.fromPath(
        'resim',
        image.path,
      ));

    final response = await request.send();

    if (response.statusCode == 200) {
      final resBytes = await response.stream.toBytes();
      setState(() {
        hiddenImageBytes = resBytes;
        isImageVisible = true;
      });

      // Dosyayı kaydet
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/gizli_qr.png');
      await file.writeAsBytes(resBytes);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QR kodu başarıyla resme gizlendi')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata oluştu: ${response.statusCode}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("QR Kod Gizleme"),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Gizlenecek mesaj',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () => messageController.clear(),
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: generateAndHideQr,
              icon: Icon(Icons.qr_code),
              label: Text("QR Oluştur ve Gizle"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            SizedBox(height: 24),
            if (isImageVisible && hiddenImageBytes != null)
              Column(
                children: [
                  Text(
                    'Oluşturulan Gizli Resim:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  Image.memory(
                    hiddenImageBytes!,
                    width: 300,
                    height: 300,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final directory =
                          await getApplicationDocumentsDirectory();
                      final file = File('${directory.path}/gizli_qr.png');
                      if (await file.exists()) {
                        // Paylaşım işlevselliği eklenebilir
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Resim kaydedildi: ${file.path}')),
                        );
                      }
                    },
                    child: Text('Kaydet'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
