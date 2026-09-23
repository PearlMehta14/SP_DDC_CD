import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../utils/responsive.dart';

class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends ConsumerState<SecuritySettingsScreen> {
  void _showSetPinDialog() {
    _showPinDialog(title: 'Set PIN', isSettingNew: true);
  }

  void _showChangePinDialog() {
    _showPinDialog(title: 'Change PIN', isChanging: true);
  }

  void _showRemovePinDialog() {
    _showPinDialog(title: 'Remove PIN', isRemoving: true);
  }

  void _showPinDialog({required String title, bool isSettingNew = false, bool isChanging = false, bool isRemoving = false}) {
    String currentPin = '';
    String newPin = '';
    String confirmPin = '';
    int step = (isSettingNew) ? 1 : 0; // 0: current, 1: new, 2: confirm
    String errorMsg = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            String promptText = '';
            if (step == 0) promptText = 'Enter Current PIN';
            else if (step == 1) promptText = 'Enter New 4-digit PIN';
            else if (step == 2) promptText = 'Confirm New PIN';

            String currentInput = (step == 0) ? currentPin : (step == 1) ? newPin : confirmPin;

            void onKeyPress(String key) async {
              if (key == 'backspace') {
                if (currentInput.isNotEmpty) {
                  setStateDialog(() {
                    currentInput = currentInput.substring(0, currentInput.length - 1);
                    if (step == 0) currentPin = currentInput;
                    else if (step == 1) newPin = currentInput;
                    else confirmPin = currentInput;
                    errorMsg = '';
                  });
                }
              } else if (currentInput.length < 4) {
                setStateDialog(() {
                  currentInput += key;
                  if (step == 0) currentPin = currentInput;
                  else if (step == 1) newPin = currentInput;
                  else confirmPin = currentInput;
                  errorMsg = '';
                });

                if (currentInput.length == 4) {
                  if (step == 0) {
                    if (isRemoving) {
                      final success = await ref.read(authProvider.notifier).removePin(currentPin);
                      if (success) {
                        if (mounted) Navigator.pop(ctx);
                        _showSuccessSnackbar('PIN removed successfully');
                      } else {
                        setStateDialog(() {
                          errorMsg = 'Incorrect Current PIN';
                          currentPin = '';
                        });
                      }
                    } else if (isChanging) {
                      final testUnlock = await ref.read(authProvider.notifier).unlock(currentPin);
                      if (testUnlock) {
                        setStateDialog(() => step = 1);
                      } else {
                        setStateDialog(() {
                          errorMsg = 'Incorrect Current PIN';
                          currentPin = '';
                        });
                      }
                      ref.read(authProvider.notifier).lockApp();
                    }
                  } else if (step == 1) {
                    setStateDialog(() => step = 2);
                  } else if (step == 2) {
                    if (newPin == confirmPin) {
                      if (isSettingNew) {
                        await ref.read(authProvider.notifier).setPin(newPin);
                        if (mounted) Navigator.pop(ctx);
                        _showSuccessSnackbar('PIN set successfully');
                      } else if (isChanging) {
                        final success = await ref.read(authProvider.notifier).changePin(currentPin, newPin);
                        if (success) {
                          if (mounted) Navigator.pop(ctx);
                          _showSuccessSnackbar('PIN changed successfully');
                        } else {
                          setStateDialog(() {
                            errorMsg = 'Failed to change PIN';
                            step = 0;
                            currentPin = ''; newPin = ''; confirmPin = '';
                          });
                        }
                      }
                    } else {
                      setStateDialog(() {
                        errorMsg = 'PINs do not match. Try again.';
                        step = 1;
                        newPin = ''; confirmPin = '';
                      });
                    }
                  }
                }
              }
            }

            return AlertDialog(
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(promptText, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final isFilled = index < currentInput.length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFilled ? const Color(0xFF1A1A1A) : Colors.transparent,
                            border: Border.all(color: errorMsg.isNotEmpty ? Colors.red : const Color(0xFF1A1A1A), width: 2),
                          ),
                        );
                      }),
                    ),
                    if (errorMsg.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Text(errorMsg, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    const SizedBox(height: 32),
                    _buildNumpadRow(['1', '2', '3'], onKeyPress),
                    const SizedBox(height: 16),
                    _buildNumpadRow(['4', '5', '6'], onKeyPress),
                    const SizedBox(height: 16),
                    _buildNumpadRow(['7', '8', '9'], onKeyPress),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const SizedBox(width: 60),
                        _buildNumpadButton('0', onKeyPress),
                        _buildBackspaceButton(onKeyPress),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (isChanging && step > 0 && mounted) {
                      ref.read(authProvider.notifier).lockApp(); 
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Widget _buildNumpadRow(List<String> keys, Function(String) onKeyPress) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((k) => _buildNumpadButton(k, onKeyPress)).toList(),
    );
  }

  Widget _buildNumpadButton(String label, Function(String) onKeyPress) {
    return InkWell(
      onTap: () => onKeyPress(label),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 60,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade100,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A)),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton(Function(String) onKeyPress) {
    return InkWell(
      onTap: () => onKeyPress('backspace'),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 60,
        height: 60,
        alignment: Alignment.center,
        child: const Icon(Icons.backspace_outlined, size: 24, color: Color(0xFF1A1A1A)),
      ),
    );
  }

  void _showSuccessSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.green.shade600,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF8),
      appBar: AppBar(
        title: const Text('SECURITY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2.0)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Responsive.constrainedForm(
          context,
          maxWidth: 600.0,
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Responsive.horizontalPadding(context), vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('APP PIN'),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Status:', style: TextStyle(fontSize: 16, color: Color(0xFF6B6B6B))),
                          Text(
                            authState.hasPin ? 'Enabled' : 'Disabled',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: authState.hasPin ? Colors.green.shade600 : Colors.red.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (!authState.hasPin)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _showSetPinDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4AF37),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('SET PIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          ),
                        )
                      else ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _showChangePinDialog,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: Color(0xFFD4AF37)),
                            ),
                            child: const Text('CHANGE PIN', style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _showRemovePinDialog,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(color: Colors.red.shade200),
                            ),
                            child: Text('REMOVE PIN', style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 2.0,
        color: Color(0xFF6B6B6B),
      ),
    );
  }
}
