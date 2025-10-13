import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'login_page.dart';
import 'folder_homepage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
  }

  if (Platform.isWindows) {
    final primaryDisplay = await screenRetriever.getPrimaryDisplay();

    final scaledWidth = primaryDisplay.size.width;
    final scaledHeight = primaryDisplay.size.height;

    final windowWidth = scaledWidth / 2;
    final windowHeight = scaledHeight * 0.8;

    WindowOptions windowOptions = WindowOptions(
      size: Size(windowWidth, windowHeight),
      minimumSize: Size(windowWidth * 0.8, windowHeight * 0.8),
      center: true,
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.normal,
      alwaysOnTop: false,
      windowButtonVisibility: true,
      fullScreen: false,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  runApp(const AkilliTahtaProjeDemo());
}

class AkilliTahtaProjeDemo extends StatelessWidget {
  const AkilliTahtaProjeDemo({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF5B4CE6);
    const secondaryColor = Color(0xFFFF6B6B);
    const surfaceColor = Color(0xFFFFFFFF);
    const backgroundColor = Color(0xFFF8F9FD);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Fix text scaling issue
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.0)),
          child: child!,
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
          primary: primaryColor,
          secondary: secondaryColor,
          surface: surfaceColor,
          surfaceContainerHighest: const Color(0xFFF1F3F9),
          onSurface: const Color(0xFF1A1D29),
          onSurfaceVariant: const Color(0xFF6B7280),
        ),
        scaffoldBackgroundColor: backgroundColor,
        dividerColor: const Color(0xFFE8EAF0),
        appBarTheme: AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          backgroundColor: surfaceColor,
          surfaceTintColor: Colors.transparent,
          foregroundColor: const Color(0xFF1A1D29),
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1D29),
            letterSpacing: -0.5,
          ),
          iconTheme: const IconThemeData(color: Color(0xFF1A1D29), size: 24),
          shadowColor: Colors.black.withValues(alpha: 0.03),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: surfaceColor,
          surfaceTintColor: surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE8EAF0), width: 1.5),
          ),
          shadowColor: Colors.black.withValues(alpha: 0.04),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: primaryColor.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              letterSpacing: -0.2,
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF1F3F9),
            foregroundColor: const Color(0xFF1A1D29),
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              letterSpacing: -0.2,
            ),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: const Color(0xFF6B7280),
            hoverColor: const Color(0xFFF1F3F9),
          ),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: primaryColor,
          inactiveTrackColor: const Color(0xFFE8EAF0),
          thumbColor: surfaceColor,
          overlayColor: primaryColor.withValues(alpha: 0.12),
          trackHeight: 4,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: surfaceColor,
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titleTextStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1D29),
            letterSpacing: -0.3,
          ),
        ),
        listTileTheme: const ListTileThemeData(
          selectedColor: primaryColor,
          iconColor: Color(0xFF6B7280),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF1F3F9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE8EAF0), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF1A1D29),
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const LoginGate(),
    );
  }
}

class LoginGate extends StatefulWidget {
  const LoginGate({super.key});

  @override
  State<LoginGate> createState() => _LoginGateState();
}

class _LoginGateState extends State<LoginGate> {
  bool _loggedIn = false;
  String? _dropboxToken;

  static const String dropboxAccessToken =
      'sl.u.AGChW34bvLkjFQDCZ1lYoN4TsfDploUu3UgNUmDauhSk8w5f30T2XIJgxOefKW11ZukDKJzNDu_Q8tP4Ptmq-u9d_-eaI6R1rJUORHcwkSYkOpLOgC1D8ExQUvuk-pVIGC-yhFZCP5I83jQRpkrpD_U1WH2e5Un3xVtcVu8h7m7MQigadN_ki0fMJfFj-o_z9WZR2eMvlA9GfzJvcf3e4BFgvUY_LXxJcyzbr3AAGMZsQ3MYZ7xios4Unf0iaCM8e_ngOiAZnBNXCOkmnWvUxyVoSDb5Bmg0tiMmCQV_77-4JDJrG_S4CyzcIXx86QcvDA9bi4uMVFzvUVJeRrCSPHYt4MbDxp5e5L4jqrf0XLgQqdYyQOrdsGBc8uwSf7ER2C4OvfRBf_96mch6Lb3vZzuK9TgpzF_yDJbaGDN7fnc7Ij2qzvn7GCqKPSDatymlvXTQlpvYsp_HMswr6tMHmzRpFw3Pjl-F0o8eJXJ-uTWBDsDia4yAzPH176eK2GhOCrLAaKcH-w-kXU0T9cO28sOYi-UJvF1eIi5E1uUAX7w5aNSBTLMJANFv5as34MSlGxEm3oqP7unUAeCN8CVfeiEYfbWB2kmfA0Vma4aEFW0lOuINH25sxA5AWb0lYPQ5XBnKwYiEsa5CV6ol5SW9QCPwlQH7cW936giRQh9eNBEBV16bsXW-kZXXvBqiekWl-K4r0uXOeAgOKP6oohivh-Ulpc7wWX47KsIH2YAKqiqFW1N0PM6t2Lfv5B5GTkOa0Qhmfq7ujS33fOwtqNvV8O0_SyVzTktrQCQRibBTnPZ0riXZ9Ev765pibzZd2_d8C7FQS3_oE0weM9Sz8yGGlTYw8WhRC-WBwpkcya-oucOCYGToNDkhQh3arPvCPl4t0AFGH_tOnmKdac_nk-htF-EqzkIOIuDbih-pnL4UAtYCSYmg-gQZp9Ulx_j-Crfb-qRyCljrSE9k3Ewtx1axtbrlxF6-I6SymYPkO2o-mlxk6yVNtgr8nfVd--6Nw4W3juzn9v-nb4bZCwSLTUobviDy9jMI18ITsBJtQUEM_Z14UTrMm0AtmAc38p3ZeMmg6suJnk-pGrnI9nUgnoYxaalld5edxf1BKznr6OgZPzH9oL1eO0nZoE4EtFjDKiX8fAzQnA-UMEo2mgVaYwyyjItId9RerAY_2wyFHonbCIIfJU2vHIcv9bqHulNhwNodUQfOYtACAIOT9dSIk1i-ZyfgLOrgMJ749mG3XSnSCXDIF3P7TMe81h-suMsMDcNrW8U_5pjph2FZ_tKnJQOZ0lzdMmxE3Vj37Q11267KWrpbCHmBvQg4oijQoyF5f1sFk2VujRHBH_gZav_pU-EpcLfOi9QXWFWUEuqBTknwHwkTjNaM3NYtFxLNNMLcH3Mt2c5LR4uWHbqnM1eqEe6dd0Y2EnRJ0I1nX1CGg-7-YEK1Nw';

  Future<bool> _handleLogin(String username, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final ok = username.isNotEmpty && password.isNotEmpty;

    if (ok) {
      setState(() {
        _loggedIn = true;
        _dropboxToken = dropboxAccessToken;
      });
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    if (_loggedIn && _dropboxToken != null) {
      return SafeArea(child: FolderHomePage(dropboxToken: _dropboxToken!));
    }
    return SafeArea(child: LoginPage(onLogin: _handleLogin));
  }
}
