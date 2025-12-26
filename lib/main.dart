import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexgeno_mcrm/check_internet.dart';
import 'package:nexgeno_mcrm/provider.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Lock portrait orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(const MyApp());

    // ✅ Apply system UI overlay AFTER runApp
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF112852), // Dark blue background
        statusBarIconBrightness:
            Brightness.light, // <-- for Android (white icons)
        statusBarBrightness: Brightness.dark, // <-- for iOS (white icons)

        systemNavigationBarColor: Color(0xFF445968),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppProvider())],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff9F0055)),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xfff1f5f9),

          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF112852),
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Color(0xFF112852),
              statusBarIconBrightness: Brightness.light, // Ensures white icons
              statusBarBrightness: Brightness.dark, // iOS
            ),
          ),
        ),
        home: const InternetConnection(),
      ),
    );
  }
}
