import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/features/auth/auth_service.dart';
import 'package:mobile/features/mesh/mesh_router.dart';
import 'package:mobile/features/sync/sync_service.dart';
import 'package:mobile/features/auth/auth_screen.dart';
import 'package:mobile/features/home/home_screen.dart';
import 'package:mobile/features/medical/first_aid_guide_screen.dart';
import 'package:mobile/features/resources/resource_management_screen.dart';
import 'package:mobile/features/volunteers/volunteer_management_screen.dart';
import 'package:mobile/features/shelters/shelter_finder_screen.dart';
import 'package:mobile/features/map/offline_map_screen.dart';
import 'package:mobile/features/profile/user_profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => MeshRouter.instance),
        ChangeNotifierProvider(create: (_) => SyncService.instance),
      ],
      child: const ResQNetApp(),
    ),
  );
}

class ResQNetApp extends StatelessWidget {
  const ResQNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ResQNet Offline Disaster Platform',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          primary: Colors.indigo.shade900,
          secondary: Colors.blueAccent,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      initialRoute: '/auth',
      routes: {
        '/auth': (context) => const AuthScreen(),
        '/home': (context) => const HomeScreen(),
        '/first_aid': (context) => const FirstAidGuideScreen(),
        '/resources': (context) => const ResourceManagementScreen(),
        '/volunteers': (context) => const VolunteerManagementScreen(),
        '/shelters': (context) => const ShelterFinderScreen(),
        '/map': (context) => const OfflineMapScreen(),
        '/profile': (context) => const UserProfileScreen(),
      },
    );
  }
}
