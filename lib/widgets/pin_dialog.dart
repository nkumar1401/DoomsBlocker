import 'package:flutter/material.dart';
import '../services/native_bridge.dart';

class PinDialog extends StatefulWidget {
  final String title;
  final String description;
  final bool returnPin;

  const PinDialog({
    Key? key,
    this.title = 'Enter Parent PIN',
    this.description = 'Enter your 4-digit PIN to modify parental restrictions.',
    this.returnPin = false,
  }) : super(key: key);

  static Future<bool> show(
    BuildContext context, {
    String title = 'Enter Parent PIN',
    String description = 'Enter your 4-digit PIN to modify parental restrictions.',
  }) async {
    final result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PinDialog(title: title, description: description, returnPin: false),
    );
    return result == true;
  }

  static Future<String?> showAndGetPin(
    BuildContext context, {
    String title = 'Enter Parent PIN',
    String description = 'Enter your 4-digit PIN to modify parental restrictions.',
  }) async {
    final result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PinDialog(title: title, description: description, returnPin: true),
    );
    return (result is String) ? result : null;
  }

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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.description,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
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
              color: Colors.white,
              fontSize: 24,
              letterSpacing: 12,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: _hasError ? const Color(0xFFEF4444) : Colors.transparent,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: _hasError ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
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
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(widget.returnPin ? null : false),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Confirm', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
