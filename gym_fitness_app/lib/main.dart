import 'package:flutter/material.dart';
/*
What it does: Bring in Flutter's Material Design UI library so you can use widgets like MaterialApp, Scaffold, Text, ThemeData,
AppBar, buttons and many others.
Why its needed: Without this import we can use StatelessWidget, BuildContext, ThemeData, etc.
Tip: You can also import smaller part (e.g., import 'package:flutter/widgets.dart';) if you want a lighter dependency,
but material.dart is usual for apps that use Material components.
*/

import 'pages/starting_page.dart';
/*
What it does: Includes the code from the starting_page.dart file in the pages folder so we can reference StartingPage here.
Why its needed: MaterialApp needs a home widget. We set home: const StartingPage(). That class lives in this file so we must import it.
Note: This is a relative import (within the project). Keep folder names consistent or the import will fail.
*/

import 'theme/color_schemes.dart';
/*
What it does: import color definitions (e.g., the coldColorScheme constant) so we can use them in ThemeData.
Why its needed: Theming is set globally in MaterialApp vie the theme property. Having color schemes in a separate file keeps
main.dart clean and encourages reuse.
*/

import 'package:provider/provider.dart';
import 'providers/unit_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final savedSchemeName = prefs.getString('selectedColorScheme') ?? 'Cold';
  final savedScheme = appColorSchemes[savedSchemeName]!;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UnitProvider()),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(
            initialSchemeName: savedSchemeName,
            initialScheme: savedScheme,
          ),
        ),
      ],
      child: const GymFitnessApp(),
    ),
  );
  /*
  What it does: Creates the widget tree root and hands it to the Flutter framework. runApp() inflates the given widget and attaches
  it to the screen.
  Why its needed: Without runApp nothing gets rendered.
  Why const: GymFitnessApp is created as a const - this tells Dart that this widget and its constructor parameters are compile-time
  constants (immutable). Using const where possible improves performance because Flutter can reuse that widget instance.
  Effect: The widget you pass to runApp() becomes the root of the app's widget tree.
  */
}
/*
What it does: Every Dart/Flutter app starts by calling main() which is entry point of the app.
Why its needed: Android/iOS looks for main() to start executing the program.
Sidenote: main can be async if you need to do asynchronous initialization before running the app (e.g., awaiting SharedPreferences
read or SQLite migrations).
*/

class ThemeProvider extends ChangeNotifier {
  String _schemeName;
  ColorScheme _scheme;

  ThemeProvider({
    required String initialSchemeName,
    required ColorScheme initialScheme,
  })  : _schemeName = initialSchemeName,
        _scheme = initialScheme;

  ColorScheme get scheme => _scheme;
  String get schemeName => _schemeName;

  Future<void> changeScheme(String newName) async {
    if (newName == _schemeName) return;
    _schemeName = newName;
    _scheme = appColorSchemes[newName]!;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedColorScheme', newName);
    notifyListeners();
  }
}

class GymFitnessApp extends StatelessWidget {
  /*
  What it does: declares a new widget named GymFitnessApp
  Role: This root widget typically configures the MaterialApp (theme, navigation, localization, routes) and acts as the app container.
  */
  const GymFitnessApp({super.key});
  /*
  What is does: constructor for GymFitnessApp. The const keyword marks it as a compile-time constant constructor.
  {super.key}: passes the optional key parameter to the StatelessWidget super-class. key is rarely needed at the root,
  but its a good practise to include it so the widget can participate in widget-tree identity if necessary.
  Why use const constructors: they let Flutter do additional compile-time optimizations and make some widgets
  canonicalized (reused), resulting in slightly less memory churn.
  */

  @override
  /*
  What it does: an annotation indicating the next method overrides a superclass method. Here it signals that build()
  overrides StatelessWidget's build method.
  Why: good for readability and the analyzer will warn you if you arent actually overriding anything.
  */
  Widget build(BuildContext context) {
    /*
    What it does: defines the build method which returns the widget subtree that this widget builds.
    BuildContext context: an object that provides information about where this widget sits in the widget tree. It is
    used to find theme data, localization, ancestor widgets, and to push routes.
    Important: build() should be pure - it should create widgets only from inputs (constructor fields, inherited widgets
    like Theme, etc.). Heavy computation or side-effects should be avoided here.
    */

    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      /*
      What it does: creates a MaterialApp widget - a convenience widget that wraps many common app-level behaviors:
      Sets up Navigator (routing), Applies Theme, Handles text direction, locales, Manages default visual properties
      like scaffoldBackgroundColor, AppBar theme if not overridden
      Why use it: it wires the app into Material Design conventions; even if you used CupertinoApp (iOS-style) or
      WidgetsApp (barebones), MaterialApp is the standard for cross-platform apps with Material widgets.
      */
      title: 'Gym Fitness App',
      theme: ThemeData(
        colorScheme: themeProvider.scheme,
        useMaterial3: false,
      ),
      home: const StartingPage(),
      /*
      What it does: sets the default home screen - the first route/page shown when the app launches.
      const: StartingPage() was declared with const (or should be) so using cont here yields the same compile-time advantages
      Alternative: you can instead use initialRoute and routes or a onGenerateRoute function when you want named routes;
      for simple apps home is easiest.
      */
      debugShowCheckedModeBanner: false,
      /*
      What it does: hides the little "DEBUG" banner that appears in the top-right corner when the app runs in debug mode.
      Why: its purely visual and makes screenshots cleaner; during development you can set this to true or remove it to
      remember you are in debug mode.
      Note: this has no effect in release builds (banner is not shown there anyway)
      */
    );
  }
}