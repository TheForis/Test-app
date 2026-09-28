import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/brand.dart';
import '../services/storage/storage_backend.dart';
import '../state/app_scope.dart';
import 'shell.dart';
import 'widgets/brand_logo.dart';

/// Decides what the app shows first: a splash while storage access is checked
/// and the home screen's data loads, then either the app or a page asking for
/// access. The home screen never appears half-loaded.
///
/// Also re-checks access and picks up new files when the app is resumed.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final scope = AppScope.of(context);
    final index = scope.index;
    if (!index.ready) return;
    final wasGranted = index.hasAccess;
    // The user may have just granted "All files access" in system settings.
    index.recheckAccess(showHidden: scope.settings.showHidden);
    // Back from the camera or a download: quietly pick up new files. Only
    // changed folders are re-read, so this is cheap.
    final last = index.lastScan;
    if (wasGranted && !index.loading && (last == null || DateTime.now().difference(last).inSeconds > 30)) {
      index.refresh(showHidden: scope.settings.showHidden);
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = AppScope.of(context).index;
    return ListenableBuilder(
      listenable: index,
      builder: (context, _) {
        final Widget page;
        if (!index.ready) {
          page = const SplashScreen(key: ValueKey('splash'));
        } else if (!index.hasAccess) {
          page = const AccessScreen(key: ValueKey('access'));
        } else {
          page = const AppShell(key: ValueKey('app'));
        }
        return AnimatedSwitcher(duration: const Duration(milliseconds: 280), child: page);
      },
    );
  }
}

/// Matches the system splash (the mark on ink), so the hand-over from the
/// platform splash is invisible. A spinner appears only if startup is slow.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: ColoredBox(
      color: Brand.ink,
      child: Stack(
        children: [
          const Center(
            child: CustomPaint(size: Size.square(112), painter: BurrowMarkPainter(background: false)),
          ),
          Align(
            alignment: const Alignment(0, 0.55),
            child: TweenAnimationBuilder<double>(
              // Stays invisible for the first 600 ms, so quick starts don't flash a spinner.
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: const Interval(0.66, 1),
              builder: (context, t, child) => Opacity(opacity: t, child: child),
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Brand.glow),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Shown when Burrow may not read storage: explains why and asks for access.
class AccessScreen extends StatelessWidget {
  const AccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final index = scope.index;
    final text = Theme.of(context).textTheme;
    final permanently = index.access == AccessState.permanentlyDenied;
    final white70 = Colors.white.withValues(alpha: 0.72);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Brand.ink,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.35),
              radius: 0.9,
              colors: [Brand.ember.withValues(alpha: 0.22), Brand.ember.withValues(alpha: 0)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    children: [
                      const CustomPaint(size: Size.square(132), painter: BurrowMarkPainter(background: false)),
                      const SizedBox(height: 28),
                      Text(
                        'Let Burrow into your storage',
                        textAlign: TextAlign.center,
                        style: text.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'To browse, search, open and organize your files, Burrow needs '
                        '"All files access". Turn it on for Burrow on the next screen, then come back.',
                        textAlign: TextAlign.center,
                        style: text.bodyLarge?.copyWith(color: white70, height: 1.45),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_outline_rounded, size: 16, color: Brand.glow),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Your files never leave your phone.',
                              style: text.labelLarge?.copyWith(color: Brand.glow),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Brand.ember,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () => permanently
                              ? scope.backend.openAccessSettings()
                              : index.requestAccess(showHidden: scope.settings.showHidden),
                          icon: Icon(permanently ? Icons.settings_rounded : Icons.lock_open_rounded),
                          label: Text(permanently ? 'Open settings' : 'Allow access'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
