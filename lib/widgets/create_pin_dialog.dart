import 'package:flutter/material.dart';
import '../services/native_bridge.dart';

class CreatePinDialog extends StatefulWidget {
  const CreatePinDialog({Key? key}) : super(key: key);

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const CreatePinDialog(),
    );
    return result == true;
  }

  @override
  State<CreatePinDialog> createState() => _CreatePinDialogState();
}

class _CreatePinDialogState extends State<CreatePinDialog> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  
  int _step = 1; // 1: Create, 2: Confirm
  String _firstPin = '';
  String? _errorMessage;
  bool _isSaving = false;

  void _onNextStep() {
    final pin = _pinController.text.trim();
    if (pin.length != 4) {
      setState(() => _errorMessage = 'PIN must be exactly 4 digits');
      return;
    }
    setState(() {
      _firstPin = pin;
      _step = 2;
      _errorMessage = null;
    });
  }

  Future<void> _onConfirmPin() async {
    final confirm = _confirmController.text.trim();
    if (confirm != _firstPin) {
      setState(() => _errorMessage = 'PINs do not match. Try again.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final ok = await NativeBridge.setPin(_firstPin);
    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Security PIN created successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        setState(() => _errorMessage = 'Failed to save PIN. Please retry.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shield_outlined, color: Color(0xFF06B6D4), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _step == 1 ? 'Create Security PIN' : 'Confirm Security PIN',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _step == 1
                ? 'Choose a 4-digit PIN to protect your settings, channel blocks, and app limits.'
                : 'Re-enter your 4-digit PIN to confirm.',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _step == 1 ? _pinController : _confirmController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            textAlign: TextAlign.center,
            autofocus: true,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              letterSpacing: 10,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              hintText: '••••',
              hintStyle: const TextStyle(color: Color(0xFF64748B), letterSpacing: 10),
              counterText: '',
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF06B6D4), width: 1.5),
              ),
            ),
            onSubmitted: (_) {
              if (_step == 1) {
                _onNextStep();
              } else {
                _onConfirmPin();
              }
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
        ),
        ElevatedButton(
          onPressed: _isSaving
              ? null
              : () {
                  if (_step == 1) {
                    _onNextStep();
                  } else {
                    _onConfirmPin();
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF06B6D4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  _step == 1 ? 'Continue' : 'Set PIN',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}
