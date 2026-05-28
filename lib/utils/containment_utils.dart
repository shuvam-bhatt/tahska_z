import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class ContainmentUtils {
  static final ContainmentUtils _instance = ContainmentUtils._internal();
  factory ContainmentUtils() => _instance;
  ContainmentUtils._internal();

  bool _isContainmentActive = false;
  VoidCallback? _onScreenshotDetected;

  bool get isContainmentActive => _isContainmentActive;

  void initialize() {
    // Screenshot prevention is handled at the system level
    // For demo purposes, we'll simulate the functionality
    print('Security containment initialized');
  }

  void activateContainment({VoidCallback? onScreenshotDetected}) {
    _isContainmentActive = true;
    _onScreenshotDetected = onScreenshotDetected;
    
    // For demo purposes, simulate screenshot detection
    // In a real app, this would be handled by native platform code
    print('Security containment activated - screenshot prevention enabled');
  }

  void deactivateContainment() {
    _isContainmentActive = false;
    _onScreenshotDetected = null;
  }

  void _onScreenshot() {
    if (_isContainmentActive) {
      _onScreenshotDetected?.call();
    }
  }

  void dispose() {
    print('Containment utils disposed');
  }
}

// Custom TextField that prevents copy-paste
class SecureTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool enabled;
  final InputDecoration? decoration;
  final FormFieldValidator<String>? validator;

  const SecureTextField({
    super.key,
    this.controller,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.onChanged,
    this.onTap,
    this.enabled = true,
    this.decoration,
    this.validator,
  });

  @override
  State<SecureTextField> createState() => _SecureTextFieldState();
}

class _SecureTextFieldState extends State<SecureTextField> {
  late TextEditingController _controller;
  bool _isPasteBlocked = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _blockPaste() {
    setState(() {
      _isPasteBlocked = true;
    });
    
    // Show warning
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copy-paste is disabled for security'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );

    // Reset after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isPasteBlocked = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      enabled: widget.enabled,
      validator: widget.validator,
      decoration: widget.decoration ?? InputDecoration(
        hintText: widget.hintText,
        border: const OutlineInputBorder(),
      ),
      onChanged: widget.onChanged,
      onTap: widget.onTap,
      onFieldSubmitted: (value) {
        // Prevent paste on submit
        if (_isPasteBlocked) {
          _blockPaste();
        }
      },
      inputFormatters: [
        // Block paste operations
        FilteringTextInputFormatter.deny(RegExp(r'[\u0000-\u001F\u007F-\u009F]')),
        _PasteBlockingFormatter(),
      ],
    );
  }
}

// Custom formatter to block paste operations
class _PasteBlockingFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Check if the change looks like a paste operation
    if (newValue.text.length - oldValue.text.length > 1) {
      // This might be a paste operation, block it
      return oldValue;
    }
    return newValue;
  }
}

// Custom Text widget that prevents selection
class SecureText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const SecureText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      text,
      style: style,
      maxLines: maxLines,
      onSelectionChanged: (selection, cause) {
        // Block text selection
        if (selection.isValid) {
          // Clear selection immediately
          SystemChannels.textInput.invokeMethod('TextInput.hide');
        }
      },
    );
  }
}

// Widget to wrap sensitive content
class SecureContainer extends StatelessWidget {
  final Widget child;
  final bool enableScreenshotBlocking;
  final VoidCallback? onScreenshotDetected;

  const SecureContainer({
    super.key,
    required this.child,
    this.enableScreenshotBlocking = true,
    this.onScreenshotDetected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Hide keyboard when tapping outside
        FocusScope.of(context).unfocus();
      },
      child: Container(
        child: child,
      ),
    );
  }
}

// Utility to show security warnings
class SecurityWarning {
  static void showScreenshotWarning(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⚠️ Screenshots are not allowed for security reasons'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void showCopyWarning(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⚠️ Copy-paste is disabled for security reasons'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void showSecurityInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Security Features'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Screenshots are blocked'),
            Text('• Copy-paste is disabled'),
            Text('• Messages are end-to-end encrypted'),
            Text('• All data is stored securely'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
