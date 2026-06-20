import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../providers/biometric_auth_provider.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _authFailed = false;

  @override
  void initState() {
    super.initState();
    // Defer until after first frame to avoid platform channel errors (RESEARCH.md A1, T-05-05)
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    final auth = LocalAuthentication();
    try {
      final didAuth = await auth.authenticate(
        localizedReason: 'Autentícate para acceder a Claude Pilot',
        // biometricOnly defaults to false — PIN fallback automatic (BIO-04, T-05-06)
      );
      if (didAuth && mounted) {
        ref.read(biometricAuthProvider.notifier).setAuthenticated(true);
      } else if (mounted) {
        setState(() => _authFailed = true);
      }
    } on PlatformException {
      // local_auth 2.x throws PlatformException (not LocalAuthException which is 3.x only)
      if (mounted) setState(() => _authFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Claude Pilot',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Autentícate para continuar',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              if (_authFailed) ...[
                Text(
                  'Autenticación requerida',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              FilledButton(
                onPressed: _authenticate,
                child: const Text('Autenticar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
