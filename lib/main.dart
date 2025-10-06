import 'package:flutter/material.dart';
import 'login_page.dart';
import 'folder_homepage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Premium color palette
    const primaryColor = Color(0xFF5B4CE6); // Modern purple
    const secondaryColor = Color(0xFFFF6B6B); // Coral accent
    const surfaceColor = Color(0xFFFFFFFF);
    const backgroundColor = Color(0xFFF8F9FD);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
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

        // Premium AppBar
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

        // Premium Cards
        cardTheme: CardThemeData(
          elevation: 0,
          color: surfaceColor,
          surfaceTintColor: surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFFE8EAF0), width: 1.5),
          ),
          shadowColor: Colors.black.withValues(alpha: 0.04),
        ),

        // Premium Buttons
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

        // Premium Slider
        sliderTheme: SliderThemeData(
          activeTrackColor: primaryColor,
          inactiveTrackColor: const Color(0xFFE8EAF0),
          thumbColor: surfaceColor,
          overlayColor: primaryColor.withValues(alpha: 0.12),
          trackHeight: 4,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        ),

        // Premium Dialog
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

        // Premium ListTile
        listTileTheme: const ListTileThemeData(
          selectedColor: primaryColor,
          iconColor: Color(0xFF6B7280),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),

        // Premium Input
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

        // Premium SnackBar
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

  Future<bool> _handleLogin(String username, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final ok = username.isNotEmpty && password.isNotEmpty;

    if (ok) {
      setState(() {
        _loggedIn = true;
        // IMPORTANT: Replace with your actual Dropbox access token
        _dropboxToken =
            'sl.u.AGBaYeFIM5bN9aW7qxAwDq_9X1zTKpwnLb2Lqm3a6W4YxTuyJQpR92zLVGh_yJSzcaQR3fuQmq5xOHc65sVQeKZxS6Kmey9MZ8TLaiq36vM-fobrhsdbhr1gFWbPQ24LSw98LRlrvKoTqDIUozqmqf3OfsMI0wwUfqud7n1HfTwiSJSYVqCKDZOCLfiWLFUWnJkAqNdQFx2qBWXcVxYyakclQMFiolKvAlLF-3uKoPk9TWFdEPS4BD1DyyCertwYxQzrNlszDsQDmqeueAK3kxz-sNfdIZ1N6aGIkW50wu0VQj8cgEPvcQ767Jx-gAFnby26Pw8YIr1jLVo8uQxqPnBV1H3Rkhzez5OZkQ385OzkWX157H1iIQ54bT878gtu4wgnYGuDtbH_B_FBYwDbUVo6kmYh110sr6yRS1yjahg2gF-ERfzYcXuLx04Nxd9TiHTX2KpG9tgvAL2iQ4VseS412UENefiQdcL3AvrnJxIoREsL49YC0l4za74RNdb-4iYhWr4tpC2fCPW-n3yeWIoKQ021cM-hi_WO-67E6tjztCnHdCJDq2unqjORZQl97-ALvKlODhZg8Hnxf9Nvq7_uVWr_OXvh1ZjhV-9JXj2IjMXHd3giK13SRyKfaxiOR76FRXG3uk5f37nkJn0qtbPY4zdsexi7fc8hfyNxBAKUe7SXXwfdS7shDEqq3Gguzk10Xq82RLfbllUAjGCOBDplvf2fLk6wuRQ02mgC8rYh4Pw3mmWjKGVE93ntJbXql4jdmyJF5XJ8wDrBDaIx76ri9u1SFfpwmSRf9fJrpTxd8McruuXiV-9IW0-agsT3-XVP-o4DkkDfeJYNc0sxMSg1F9ukr41yUwbFf5Mj4_76sa7ujEc7HiXArHIpoudzqH3Q5MiRSw6I_arM1ROMmU9RnLw0LoshdUVRT-Q5SX0f37q0Hu-W4VV93NUOaUKQ-e4rq5-l0HRqpWAnVRrJeuv9gYEqzC_CFVDxVHNfDitylJpy9UjkCXjWP9vwHM--5jSLTY4Xl4IEJdPc1GgSpKdqMSCy7xL-w7erGtjxiqw4JZ31oFisoUYyr2cRDa24UdXSeEtsViRKHZ4NyK7KEQczsYDUAl-QgR_t_Rm3Xbe8wKkCoyKbe4VZMbEGu48BjrOxkW7BueMg6sksG4O2tYfQ9eFBj6OrB8wEkcNvw5N_lSjCpr4W5jod2oF_LeYZL7zmxL7wrFwmQxtHnnS_WDQ_n0nwdfwAM2Uk4OATGNJ6-R2306Bl22HLzwsnKevUcIx1u5pp6TF-9x5c0faXaa7jZAufkGiXmHpQ8rNtw83gjU7Z3rTnd6-beqorH4n9WMjjL96fhxLEbWnRRQvsB3IdW3TNuTudaO_MMOKNUlYoRyK4RGI0xyZ3P6j4vUs_jvof2WNsQNYLJ2s0FqA2R1S1VnLwNESB5DDW-Nl6S9cwIQ';
      });
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    if (_loggedIn && _dropboxToken != null) {
      return FolderHomePage(dropboxToken: _dropboxToken!);
    }
    return LoginPage(onLogin: _handleLogin);
  }
}
