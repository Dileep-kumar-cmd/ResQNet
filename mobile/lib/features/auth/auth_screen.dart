import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/features/auth/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  
  bool _isRegisterMode = false;
  bool _isPasswordVisible = false;
  bool _isSubmitting = false;
  String _selectedRole = 'FIRST_RESPONDER';
  String? _errorMessage;

  Future<void> _handleAuthSubmit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      if (_isRegisterMode) {
        await authService.register(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
          role: _selectedRole,
        );
      } else {
        await authService.login(
          _emailCtrl.text.trim(),
          _passwordCtrl.text.trim(),
        );
      }
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, size: 80, color: Colors.indigo.shade900),
              const SizedBox(height: 16),
              Text(
                'ResQNet Offline-First Portal',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Text('Dual Online / Airplane-Mode Authentication'),
              const SizedBox(height: 24),

              // Segmented Tab Selector for Login vs Register
              Container(
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isRegisterMode = false;
                          _errorMessage = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isRegisterMode ? Colors.indigo.shade900 : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'LOGIN',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: !_isRegisterMode ? Colors.white : Colors.indigo.shade900,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isRegisterMode = true;
                          _errorMessage = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isRegisterMode ? Colors.indigo.shade900 : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'REGISTER',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _isRegisterMode ? Colors.white : Colors.indigo.shade900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_isRegisterMode) ...[
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Responder Email',
                  hintText: 'e.g. rescuer@resqnet.org',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordCtrl,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Emergency Password',
                  hintText: 'Enter password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                      color: Colors.indigo.shade900,
                    ),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (_isRegisterMode) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role / Designation',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'FIRST_RESPONDER', child: Text('First Responder (SAR Team)')),
                    DropdownMenuItem(value: 'RESCUER', child: Text('Lead Rescue Command')),
                    DropdownMenuItem(value: 'CITIZEN', child: Text('Local Citizen / Volunteer')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRole = val);
                  },
                ),
                const SizedBox(height: 16),
              ],

              Row(
                children: [
                  const Icon(Icons.airplanemode_active),
                  const SizedBox(width: 8),
                  const Text('Simulate Airplane Mode'),
                  const Spacer(),
                  Switch(
                    value: authService.isAirplaneModeForced,
                    onChanged: (val) => authService.toggleAirplaneModeSim(val),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleAuthSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade900,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isRegisterMode
                              ? (authService.isAirplaneModeForced ? 'CREATE OFFLINE PROFILE' : 'REGISTER ONLINE')
                              : (authService.isAirplaneModeForced ? 'LOGIN OFFLINE' : 'LOGIN ONLINE / CACHE'),
                        ),
                ),
              ),
              const SizedBox(height: 10),

              // Optional quick demo fill button
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  icon: const Icon(Icons.bolt, size: 14, color: Colors.indigo),
                  label: const Text('Fill Demo Responder (rescuer@resqnet.org)', style: TextStyle(fontSize: 12, color: Colors.indigo)),
                  onPressed: () {
                    setState(() {
                      _emailCtrl.text = 'rescuer@resqnet.org';
                      _passwordCtrl.text = 'EmergencyPassword2026!';
                    });
                  },
                ),
              ),
              const SizedBox(height: 6),

              TextButton(
                onPressed: () => Navigator.of(context).pushReplacementNamed('/home'),
                child: const Text('Continue as Anonymous Local Rescue Guest'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
