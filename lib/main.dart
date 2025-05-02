import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyApp());
}

/// Uygulama ana sınıfı
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Steganography Client',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

/// Ana sayfa: Üç farklı işlevi barındıran sekmeli yapı.
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  // Sunucu URL'inizi girin (örneğin, "http://192.168.1.100:5000")
  final String serverUrl = "10.0.2.2:5000";

  TabController? _tabController;

  @override
  void initState() {
    _tabController = TabController(length: 3, vsync: this);
    super.initState();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("QR Steganography Client"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "QR Oluştur"),
            Tab(text: "Embed QR"),
            Tab(text: "Extract QR"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          GenerateQRTab(),
          EmbedQRTab(),
          ExtractQRTab(),
        ],
      ),
    );
  }
}

/// 1. Sekme: Girilen mesajdan QR kod oluştur.
class GenerateQRTab extends StatefulWidget {
  const GenerateQRTab({super.key});
  @override
  State<GenerateQRTab> createState() => _GenerateQRTabState();
}

class _GenerateQRTabState extends State<GenerateQRTab> {
  final TextEditingController _messageController = TextEditingController();
  Uint8List? _qrImage;

  Future<void> _generateQR(String message) async {
    final url = Uri.parse("10.0.2.2:5000/generate_qr");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"message": message}),
    );
    if (response.statusCode == 200) {
      setState(() {
        _qrImage = response.bodyBytes;
      });
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("QR oluşturulamadı.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _messageController,
            decoration: const InputDecoration(labelText: "Mesajı Girin"),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              _generateQR(_messageController.text);
            },
            child: const Text("QR Oluştur"),
          ),
          const SizedBox(height: 20),
          _qrImage != null
              ? Image.memory(_qrImage!, width: 200, height: 200)
              : const Text("QR kod henüz üretilmedi."),
        ],
      ),
    );
  }
}

/// 2. Sekme: Girilen mesajı ve seçilen resmi Python sunucusuna göndererek QR kodu resme göm.
class EmbedQRTab extends StatefulWidget {
  const EmbedQRTab({super.key});
  @override
  State<EmbedQRTab> createState() => _EmbedQRTabState();
}

class _EmbedQRTabState extends State<EmbedQRTab> {
  final TextEditingController _messageController = TextEditingController();
  XFile? _selectedImage;
  Uint8List? _stegoImageBytes;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedImage = picked;
      });
    }
  }

  Future<void> _embedQR() async {
    if (_messageController.text.isEmpty || _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mesaj ve resim gerekli")));
      return;
    }

    final url = Uri.parse("10.0.2.2:5000/embed_qr");
    final request = http.MultipartRequest('POST', url);
    request.fields['message'] = _messageController.text;
    request.files
        .add(await http.MultipartFile.fromPath("image", _selectedImage!.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      setState(() {
        _stegoImageBytes = response.bodyBytes;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gömme işlemi başarısız.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _messageController,
            decoration: const InputDecoration(
                labelText: "QR içine gömülecek mesajı girin"),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _pickImage,
            child: const Text("Resim Seç (Galeri)"),
          ),
          const SizedBox(height: 10),
          _selectedImage != null
              ? Image.file(File(_selectedImage!.path), width: 200, height: 200)
              : const Text("Resim seçilmedi."),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _embedQR,
            child: const Text("QR'yı Resme Gizle"),
          ),
          const SizedBox(height: 20),
          _stegoImageBytes != null
              ? Column(
                  children: [
                    const Text("Gömülü Resim:"),
                    Image.memory(_stegoImageBytes!, width: 200, height: 200),
                  ],
                )
              : const Text("Gömülü resim henüz oluşturulmadı."),
        ],
      ),
    );
  }
}

/// 3. Sekme: Seçilen gizlenmiş resimden QR kodu çıkar.
class ExtractQRTab extends StatefulWidget {
  const ExtractQRTab({super.key});
  @override
  State<ExtractQRTab> createState() => _ExtractQRTabState();
}

class _ExtractQRTabState extends State<ExtractQRTab> {
  XFile? _selectedStegoImage;
  Uint8List? _extractedQRBytes;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickStegoImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedStegoImage = picked;
      });
    }
  }

  Future<void> _extractQR() async {
    if (_selectedStegoImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gömülü resim seçilmedi.")));
      return;
    }

    final url = Uri.parse("10.0.2.2:5000/extract_qr");
    final request = http.MultipartRequest('POST', url);
    request.files.add(
      await http.MultipartFile.fromPath("image", _selectedStegoImage!.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      setState(() {
        _extractedQRBytes = response.bodyBytes;
      });
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("QR çıkarılamadı.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: _pickStegoImage,
            child: const Text("Gömülü Resmi Seç (Galeri)"),
          ),
          const SizedBox(height: 10),
          _selectedStegoImage != null
              ? Image.file(File(_selectedStegoImage!.path),
                  width: 200, height: 200)
              : const Text("Resim seçilmedi."),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _extractQR,
            child: const Text("Gizlenmiş Resmi Çöz"),
          ),
          const SizedBox(height: 20),
          _extractedQRBytes != null
              ? Column(
                  children: [
                    const Text("Çıkarılmış QR Kod:"),
                    Image.memory(_extractedQRBytes!, width: 200, height: 200),
                  ],
                )
              : const Text("QR kod henüz çıkarılmadı."),
        ],
      ),
    );
  }
}
