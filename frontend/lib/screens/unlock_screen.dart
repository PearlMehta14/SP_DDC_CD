import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../utils/responsive.dart';

class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  String _pin = '';
  bool _isError = false;

  void _onKeyPress(String key) async {
    if (key == 'backspace') {
      if (_pin.isNotEmpty) {
        setState(() {
          _pin = _pin.substring(0, _pin.length - 1);
          _isError = false;
        });
      }
    } else if (_pin.length < 4) {
      setState(() {
        _pin += key;
        _isError = false;
      });

      if (_pin.length == 4) {
        final success = await ref.read(authProvider.notifier).unlock(_pin);
        if (!success && mounted) {
          setState(() {
            _isError = true;
            _pin = '';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAF8),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Responsive.constrainedForm(
                context,
                Column(
                  children: [
                    const SizedBox(height: 60),
                    const Text(
                      'DDC DIAMONDS',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        color: Color(0xFFD4AF37),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Icon(Icons.lock_outline, size: 48, color: Color(0xFF1A1A1A)),
                    const SizedBox(height: 16),
                    const Text(
                      'App Locked',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter your 4-digit PIN',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF6B6B6B),
                      ),
                    ),
                    const SizedBox(height: 48),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final isFilled = index < _pin.length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFilled ? const Color(0xFF1A1A1A) : Colors.transparent,
                            border: Border.all(
                              color: _isError ? Colors.red : const Color(0xFF1A1A1A),
                              width: 2,
                            ),
                          ),
                        );
                      }),
                    ),
                    
                    if (_isError)
                      const Padding(
                        padding: EdgeInsets.only(top: 16.0),
                        child: Text(
                          'Incorrect PIN',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ),
                      
                    const SizedBox(height: 48),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48.0),
                      child: Column(
                        children: [
                          _buildNumpadRow(['1', '2', '3']),
                          const SizedBox(height: 24),
                          _buildNumpadRow(['4', '5', '6']),
                          const SizedBox(height: 24),
                          _buildNumpadRow(['7', '8', '9']),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              const SizedBox(width: 70),
                              _buildNumpadButton('0'),
                              _buildBackspaceButton(),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumpadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((k) => _buildNumpadButton(k)).toList(),
    );
  }

  Widget _buildNumpadButton(String label) {
    return InkWell(
      onTap: () => _onKeyPress(label),
      borderRadius: BorderRadius.circular(35),
      child: Container(
        width: 70,
        height: 70,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade100,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return InkWell(
      onTap: () => _onKeyPress('backspace'),
      borderRadius: BorderRadius.circular(35),
      child: Container(
        width: 70,
        height: 70,
        alignment: Alignment.center,
        child: const Icon(Icons.backspace_outlined, size: 28, color: Color(0xFF1A1A1A)),
      ),
    );
  }
}
