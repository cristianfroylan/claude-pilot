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
  String? _errorDetail;

  @override
  void initState() {
    super.initState();
    // Defer until after first frame to avoid platform channel errors (RESEARCH.md A1, T-05-05)
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    setState(() { _authFailed = false; _errorDetail = null; });
    final auth = LocalAuthentication();
    try {
      final didAuth = await auth.authenticate(
        localizedReason: 'Autentícate para acceder a Claude Pilot',
        options: const AuthenticationOptions(
          stickyAuth: false,
          biometricOnly: false,
        ),
      );
      if (didAuth && mounted) {
        ref.read(biometricAuthProvider.notifier).setAuthenticated(true);
      } else if (mounted) {
        setState(() { _authFailed = true; _errorDetail = 'didAuth=false (cancelado o no reconocido)'; });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _authFailed = true;
          _errorDetail = 'code=${e.code}  msg=${e.message}  details=${e.details}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Claude Pilot',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Autentícate para continuar',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                if (_authFailed) ...[
                  Text(
                    'Autenticación fallida',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_errorDetail != null) ...[
                    const SizedBox(height: 8),
                    SelectableText(
                      _errorDetail!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
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
      ),
    );
  }
}
