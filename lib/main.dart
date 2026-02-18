import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'providers/diary_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Turkish locale for date formatting
  await initializeDateFormatting('tr_TR', null);
  
  runApp(const VoiceDiaryApp());
}

class VoiceDiaryApp extends StatelessWidget {
  const VoiceDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DiaryProvider()..loadEntries(),
      child: MaterialApp(
        title: 'AI Ses Günlüğü',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        home: SplashScreen(nextScreen: const HomeScreen()),
      ),
    );
  }
}
