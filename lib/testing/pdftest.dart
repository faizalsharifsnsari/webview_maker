import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart'; // 👈 for cookies

class PdfTestPage extends StatefulWidget {
  const PdfTestPage({super.key});

  @override
  State<PdfTestPage> createState() => _PdfTestPageState();
}

class _PdfTestPageState extends State<PdfTestPage> {
  bool isLoading = false;
  String? localFilePath;

  final String pdfUrl =
      "https://lumifog.nexgeno.cloud/admin/expenses/preview_file/100";

  @override
  void initState() {
    super.initState();
    _downloadAndOpenPdf();
  }

  Future<void> _downloadAndOpenPdf() async {
    try {
      setState(() => isLoading = true);
      debugPrint("⏳ Starting PDF download from: $pdfUrl");

      final dir = await getTemporaryDirectory();
      final filePath = "${dir.path}/lumifog_preview.pdf";

      // ✅ Get cookies from WebView session
      final cookieManager = CookieManager.instance();
      final cookies = await cookieManager.getCookies(url: WebUri(pdfUrl));
      String cookieHeader = cookies
          .map((c) => "${c.name}=${c.value}")
          .join("; ");
      debugPrint("🍪 Cookies used for download: $cookieHeader");

      // ✅ Download using authenticated cookies
      final dio = Dio();
      final response = await dio.download(
        pdfUrl,
        filePath,
        options: Options(headers: {"Cookie": cookieHeader}),
        onReceiveProgress: (count, total) {
          if (total != -1) {
            debugPrint(
              "📦 Download progress: ${(count / total * 100).toStringAsFixed(0)}%",
            );
          }
        },
      );

      if (response.statusCode == 200) {
        debugPrint("✅ PDF downloaded successfully to: $filePath");
        setState(() {
          localFilePath = filePath;
          isLoading = false;
        });
      } else {
        debugPrint(
          "❌ PDF download failed with status code: ${response.statusCode}",
        );
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("❌ Error downloading PDF: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PDF Preview Test"),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _downloadAndOpenPdf,
          ),
        ],
      ),
      body: Center(
        child: isLoading
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.blueAccent),
                  SizedBox(height: 16),
                  Text("📥 Downloading PDF, please wait..."),
                ],
              )
            : localFilePath != null
            ? PDFView(
                filePath: localFilePath!,
                enableSwipe: true,
                swipeHorizontal: true,
                autoSpacing: true,
                pageSnap: true,
                onRender: (pages) =>
                    debugPrint("📄 PDF rendered with $pages pages"),
                onError: (error) =>
                    debugPrint("❌ Error displaying PDF: $error"),
                onPageError: (page, error) => debugPrint(
                  "⚠️ Error on page $page while displaying PDF: $error",
                ),
                onViewCreated: (controller) =>
                    debugPrint("✅ PDF viewer created successfully"),
              )
            : const Text("⚠️ No PDF loaded"),
      ),
    );
  }
}
