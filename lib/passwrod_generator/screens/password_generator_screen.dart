import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/password_generator_service.dart';

class PasswordGeneratorPage extends StatefulWidget {
  const PasswordGeneratorPage({super.key});

  @override
  State<PasswordGeneratorPage> createState() => _PasswordGeneratorPageState();
}

class _PasswordGeneratorPageState extends State<PasswordGeneratorPage> {
  // Nilai default
  int _passwordLength = 12;
  bool _includeUppercase = true;
  bool _includeLowercase = true;
  bool _includeNumbers = true;
  bool _includeSpecial = true;
  String _generatedPassword = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Menampilkan password yang dihasilkan
              TextField(
                readOnly: true,
                controller: TextEditingController(text: _generatedPassword),
                decoration: InputDecoration(
                  labelText: 'Generated Password',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: _generatedPassword));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Password disalin ke clipboard')),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Slider untuk memilih panjang password
              Row(
                children: [
                  const Text('Panjang:'),
                  Expanded(
                    child: Slider(
                      value: _passwordLength.toDouble(),
                      min: 4,
                      max: 32,
                      divisions: 28,
                      label: _passwordLength.toString(),
                      onChanged: (value) {
                        setState(() {
                          _passwordLength = value.toInt();
                        });
                      },
                    ),
                  ),
                  Text(_passwordLength.toString()),
                ],
              ),
              const SizedBox(height: 20),
              // Opsi checkbox untuk tiap jenis karakter
              CheckboxListTile(
                title: const Text('Uppercase'),
                value: _includeUppercase,
                onChanged: (value) {
                  setState(() {
                    _includeUppercase = value!;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('Lowercase'),
                value: _includeLowercase,
                onChanged: (value) {
                  setState(() {
                    _includeLowercase = value!;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('Numbers'),
                value: _includeNumbers,
                onChanged: (value) {
                  setState(() {
                    _includeNumbers = value!;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('Special Characters'),
                value: _includeSpecial,
                onChanged: (value) {
                  setState(() {
                    _includeSpecial = value!;
                  });
                },
              ),
              const SizedBox(height: 20),
              // Tombol untuk menghasilkan password
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _generatedPassword = PasswordGeneratorService.generatePassword(
                      length: _passwordLength,
                      includeUppercase: _includeUppercase,
                      includeLowercase: _includeLowercase,
                      includeNumbers: _includeNumbers,
                      includeSpecial: _includeSpecial,
                    );
                  });
                },
                child: const Text('Generate Password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
