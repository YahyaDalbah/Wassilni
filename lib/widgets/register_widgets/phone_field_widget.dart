import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:wassilni/pages/Component/input_field.dart';

class BuildPhoneNumberField extends StatefulWidget {
  final TextEditingController controller;

  const BuildPhoneNumberField({super.key, required this.controller});

  @override
  State<BuildPhoneNumberField> createState() => _BuildPhoneNumberFieldState();
}

class _BuildPhoneNumberFieldState extends State<BuildPhoneNumberField> {
  String _selectedCountryCode = '+970';
  String _selectedCountryFlag = '🇵🇸';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          _selectedCountryFlag,
          style: TextStyle(fontSize: 24),
        ),
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
              },
            );
          },
          icon: Icon(
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
              if(value.length < 8 || value.length > 10){
                return "The number must be between 8 - 10 digits";
              }
              return null;
            },
            text: "Phone Number ",
            prefixText: _selectedCountryCode,
            keyboardType: TextInputType.phone,
          ),
        ),
      ],
    );
  }
}