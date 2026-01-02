import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lottie/lottie.dart';
import 'package:nexgeno_mcrm/Exitdialuge.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
// 👈 for PDF rendering

class WebViewStack extends StatefulWidget {
  const WebViewStack({super.key});

  @override
  State<WebViewStack> createState() => _WebViewStackState();
}

class _WebViewStackState extends State<WebViewStack>
    with TickerProviderStateMixin {
  late InAppWebViewController webViewController;
  bool _isLoading = true;
  bool _initialPageLoaded = false;
  bool showPdf = false;
  String? localPdfPath;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.status;
    if (!status.isGranted) {
      await Permission.location.request();
    }
  }

  Future<Position?> _getDeviceLocation() async {
    var permission = await Permission.location.request();
    if (permission.isGranted) {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    }
    return null;
  }

  // ✅ Handles secure PDF download + viewer
  Future<void> _openPdfFromUrl(String url) async {
    try {
      setState(() {
        _isLoading = true;
        showPdf = false;
      });

      debugPrint("⏳ Starting PDF download: $url");

      final dir = await getTemporaryDirectory();
      final filePath = "${dir.path}/preview_file.pdf";

      // 🧠 Get cookies from WebView session (for authenticated download)
      final cookieManager = CookieManager.instance();
      final cookies = await cookieManager.getCookies(url: WebUri(url));
      final cookieHeader = cookies
          .map((c) => "${c.name}=${c.value}")
          .join("; ");

      debugPrint("🍪 Using cookies: $cookieHeader");

      // 🚀 Download file
      final dio = Dio();
      final response = await dio.download(
        url,
        filePath,
        options: Options(headers: {"Cookie": cookieHeader}),
      );

      if (response.statusCode == 200 && File(filePath).existsSync()) {
        debugPrint("✅ PDF downloaded successfully: $filePath");
        setState(() {
          localPdfPath = filePath;
          showPdf = true;
        });
      } else {
        debugPrint("❌ PDF download failed: ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to load PDF (${response.statusCode})"),
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ PDF error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error opening PDF: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _injectRealTimeLocation(
    InAppWebViewController controller,
  ) async {
    try {
      final position = await _getDeviceLocation();
      if (position == null) {
        debugPrint("⚠️ No GPS position available");
        return;
      }

      final latitude = position.latitude;
      final longitude = position.longitude;

      debugPrint("📍 Injecting live location: ($latitude, $longitude)");

      await controller.evaluateJavascript(
        source:
            """
      // Override getCurrentPosition and watchPosition to use Flutter GPS
      navigator.geolocation.getCurrentPosition = function(success, error) {
        success({
          coords: { latitude: $latitude, longitude: $longitude, accuracy: 10 }
        });
      };

      navigator.geolocation.watchPosition = function(success, error) {
        // Call immediately
        success({
          coords: { latitude: $latitude, longitude: $longitude, accuracy: 10 }
        });
        // Then update every 10 seconds from Flutter via polling
        if (window.flutterLocationInterval) clearInterval(window.flutterLocationInterval);
        window.flutterLocationInterval = setInterval(async function() {
          window.flutter_inappwebview.callHandler('requestLocationUpdate');
        }, 10000);
      };

      console.log("✅ Real-time location injected");
    """,
      );

      // 🧠 Setup a JS handler to respond with updated Flutter GPS on-demand
      controller.addJavaScriptHandler(
        handlerName: 'requestLocationUpdate',
        callback: (args) async {
          final updatedPosition = await _getDeviceLocation();
          if (updatedPosition != null) {
            await controller.evaluateJavascript(
              source:
                  """
            if (window.updateLocationCallback) {
              window.updateLocationCallback({
                coords: { latitude: ${updatedPosition.latitude}, longitude: ${updatedPosition.longitude}, accuracy: 10 }
              });
            }
          """,
            );
            debugPrint(
              "📡 Updated JS with new location: (${updatedPosition.latitude}, ${updatedPosition.longitude})",
            );
          }
          return null;
        },
      );
    } catch (e) {
      debugPrint("❌ Error injecting real-time location: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: WillPopScope(
        onWillPop: () async {
          if (showPdf) {
            setState(() {
              showPdf = false;
              localPdfPath = null;
            });
            return false;
          }

          if (await webViewController.canGoBack()) {
            await webViewController.goBack();
            return false;
          }

          return await ExitConfirmationDialog(context);
        },
        child: Scaffold(
          body: Stack(
            children: [
              // 🌐 Main WebView
              if (!showPdf)
                InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri(
                      "https://faizalsharifsnsari.github.io/MyPortfolio.github.io/",
                    ),
                  ),
                  initialOptions: InAppWebViewGroupOptions(
                    crossPlatform: InAppWebViewOptions(
                      javaScriptEnabled: true,
                      useShouldOverrideUrlLoading: true,
                    ),
                    android: AndroidInAppWebViewOptions(
                      useHybridComposition: true,
                    ),
                  ),
                  onWebViewCreated: (controller) {
                    webViewController = controller;
                    debugPrint("✅ WebView created");
                  },
                  shouldOverrideUrlLoading:
                      (controller, navigationAction) async {
                        final uri = navigationAction.request.url;
                        if (uri != null) {
                          final url = uri.toString();
                          debugPrint("🌐 Navigating: $url");

                          // ✅ Handle preview links (PDFs, images, etc.)
                          if (url.contains("/preview_file/")) {
                            try {
                              final cookieManager = CookieManager.instance();
                              final cookies = await cookieManager.getCookies(
                                url: WebUri(url),
                              );
                              final cookieHeader = cookies
                                  .map((c) => "${c.name}=${c.value}")
                                  .join("; ");

                              final dio = Dio();
                              final response = await dio.head(
                                url,
                                options: Options(
                                  headers: {"Cookie": cookieHeader},
                                ),
                              );

                              final contentType =
                                  response.headers.value("content-type") ?? "";
                              debugPrint("📎 Content-Type: $contentType");

                              if (contentType.contains("application/pdf")) {
                                debugPrint("📄 PDF detected via Content-Type");
                                _openPdfFromUrl(url);
                                return NavigationActionPolicy.CANCEL;
                              } else {
                                debugPrint(
                                  "🖼️ Not a PDF, allowing normal load",
                                );
                                return NavigationActionPolicy.ALLOW;
                              }
                            } catch (e) {
                              debugPrint("⚠️ HEAD request failed: $e");
                              return NavigationActionPolicy.ALLOW;
                            }
                          }

                          // 🧩 Fallback for direct .pdf links
                          if (url.toLowerCase().endsWith(".pdf")) {
                            debugPrint("📄 Direct PDF URL detected");
                            _openPdfFromUrl(url);
                            return NavigationActionPolicy.CANCEL;
                          }
                        }

                        return NavigationActionPolicy.ALLOW;
                      },

                  onLoadStart: (controller, url) {
                    setState(() => _isLoading = true);
                    debugPrint("⏳ Page started loading: $url");
                  },
                  onLoadStop: (controller, url) async {
                    setState(() {
                      _isLoading = false;
                    });
                    await Future.delayed(Duration(seconds: 3));
                    if (!mounted) return;
                    setState(() {
                      _initialPageLoaded = true;
                    });
                    debugPrint("✅ Page finished loading: $url");

                    // 🌍 Inject real-time geolocation handlers
                    await _injectRealTimeLocation(controller);
                  },

                  onConsoleMessage: (controller, consoleMessage) {
                    debugPrint("🧾 JS Console: ${consoleMessage.message}");
                  },
                  androidOnGeolocationPermissionsShowPrompt:
                      (controller, origin) async {
                        return GeolocationPermissionShowPromptResponse(
                          origin: origin,
                          allow: true,
                          retain: true,
                        );
                      },
                  onPermissionRequest: (controller, request) async {
                    return PermissionResponse(
                      resources: request.resources,
                      action: PermissionResponseAction.GRANT,
                    );
                  },
                ),

              // 📄 PDF Viewer
              if (showPdf && localPdfPath != null)
                PDFView(
                  filePath: localPdfPath!,
                  enableSwipe: true,
                  swipeHorizontal: true,
                  autoSpacing: true,
                  pageSnap: true,
                  onRender: (pages) =>
                      debugPrint("📖 PDF rendered with $pages pages"),
                  onError: (error) {
                    debugPrint("❌ Error displaying PDF: $error");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error displaying PDF")),
                    );
                  },
                  onViewCreated: (_) =>
                      debugPrint("✅ PDF viewer opened successfully"),
                ),

              // 🌀 Splash / initial loader
              if (!_initialPageLoaded)
                Stack(
                  children: [
                    // Background image
                    Container(
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/images/Portfolio.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                    // Lottie animation overlay
                    Center(
                      child: Lottie.asset(
                        'assets/images/About Project.json',
                        width: 200,
                        height: 200,
                      ),
                    ),
                  ],
                ),

              // 📶 Top progress bar
              if (_isLoading)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    color: Colors.blueGrey,
                    minHeight: 3,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
