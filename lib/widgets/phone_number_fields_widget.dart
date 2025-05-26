import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import 'package:wassilni/pages/Component/input_field.dart';

class PhoneNumberField extends StatefulWidget {
  final ValueChanged<String> onCountryChanged;
  final TextEditingController controller;

  const PhoneNumberField({
    super.key,
    required this.onCountryChanged,
    required this.controller,
  });

  @override
  State<PhoneNumberField> createState() => _PhoneNumberFieldState();
}

class _PhoneNumberFieldState extends State<PhoneNumberField> {
  String _selectedCountryCode = '+970';
  String _selectedCountryFlag = '🇵🇸';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(_selectedCountryFlag, style: const TextStyle(fontSize: 24)),
        IconButton(
          onPressed: () {
            showCountryPicker(
              context: context,
              showPhoneCode: true,
              onSelect: (Country country) {
                setState(() {
                  _selectedCountryCode = '+${country.phoneCode}';
                  _selectedCountryFlag = country.flagEmoji;
                });
                widget.onCountryChanged(_selectedCountryCode);
              },
            );
          },
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        Expanded(
          child: InputField(
            controller: widget.controller,
            validate: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your phone number';
              }
              if (value.length < 8 || value.length > 10) {
                return "The number must be between 8 - 10 digits";
              }
              return null;
            },
            text: "Phone Number",
            prefixText: _selectedCountryCode,
            keyboardType: TextInputType.phone,
          ),
        ),
      ],
    );
  }
}