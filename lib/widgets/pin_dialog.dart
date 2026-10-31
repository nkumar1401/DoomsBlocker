import 'package:flutter/material.dart';
import '../services/native_bridge.dart';
import 'create_pin_dialog.dart';

class PinDialog extends StatefulWidget {
  final String title;
  final String description;
  final bool returnPin;

  const PinDialog({
    Key? key,
    this.title = 'Enter Parent PIN',
    this.description = 'Please enter your 4-digit PIN to modify rules.',
    this.returnPin = false,
  }) : super(key: key);

  static Future<bool> show(
    BuildContext context, {
    String title = 'Enter Parent PIN',
    String description = 'Please enter your 4-digit PIN to modify rules.',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PinDialog(
        title: title,
        description: description,
        returnPin: false,
      ),
    );
    return result == true;
  }

  static Future<String?> showForPin(
    BuildContext context, {
    String title = 'Enter Parent PIN',
    String description = 'Please enter your 4-digit PIN to confirm action.',
  }) async {
    final result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PinDialog(
        title: title,
        description: description,
        returnPin: true,
      ),
    );
    return (result is String) ? result : null;
  }

  static Future<String?> showAndGetPin(
    BuildContext context, {
    String title = 'Enter Parent PIN',
    String description = 'Please enter your 4-digit PIN to confirm action.',
  }) => showForPin(context, title: title, description: description);

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  final TextEditingController _pinController = TextEditingController();
  bool _hasError = false;
  bool _isLoading = false;

  Future<void> _submit() async {
    final pin = _pinController.text.trim();
    if (pin.length < 4) {
      setState(() => _hasError = true);
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final valid = await NativeBridge.verifyPin(pin);

    if (mounted) {
      setState(() => _isLoading = false);
      if (valid) {
        Navigator.of(context).pop(widget.returnPin ? pin : true);
      } else {
        setState(() => _hasError = true);
      }
    }
  }

  Future<void> _handleForgotPin() async {
    final verified = await NativeBridge.authenticateDeviceOwner();
    if (!mounted) return;

    if (verified) {
      final created = await CreatePinDialog.show(context, isUpdating: true);
      if (created && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN successfully reset using your phone security!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.of(context).pop(widget.returnPin ? null : true);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device authentication was not completed.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      title: Text(
        widget.title,
        style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.description,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            textAlign: TextAlign.center,
            autofocus: true,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 24,
              letterSpacing: 12,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: _hasError ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: _hasError ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: _hasError ? const Color(0xFFEF4444) : const Color(0xFF06B6D4),
                  width: 1.5,
                ),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_hasError)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Incorrect PIN. Default is 1234',
                style: TextStyle(color: Color(0xFFEF4444), fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _handleForgotPin,
            icon: const Icon(Icons.fingerprint_rounded, size: 16, color: Color(0xFF06B6D4)),
            label: const Text(
              'Forgot PIN? Verify with phone lock / fingerprint',
              style: TextStyle(color: Color(0xFF06B6D4), fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(widget.returnPin ? null : false),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF06B6D4),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
