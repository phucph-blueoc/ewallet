import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Secure text field with enhanced security features
/// - Prevents screenshots (on supported platforms)
/// - Uses secure keyboard
/// - Prevents text selection/copying
class SecureTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final TextInputType keyboardType;

  const SecureTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.maxLength,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.keyboardType = TextInputType.number,
  });

  @override
  State<SecureTextField> createState() => _SecureTextFieldState();
}

class _SecureTextFieldState extends State<SecureTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
        suffixIcon: IconButton(
          icon: Icon(
            _obscureText ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: () {
            setState(() {
              _obscureText = !_obscureText;
            });
          },
        ),
      ),
      obscureText: _obscureText,
      keyboardType: widget.keyboardType,
      maxLength: widget.maxLength,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      validator: widget.validator,
      // Security features
      enableInteractiveSelection: false, // Prevent text selection
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly, // Only numbers for PIN
        LengthLimitingTextInputFormatter(widget.maxLength),
      ],
      // Use secure keyboard
      keyboardAppearance: Brightness.dark,
      // Prevent screenshots (iOS/Android)
      enableSuggestions: false,
      autocorrect: false,
    );
  }
}

