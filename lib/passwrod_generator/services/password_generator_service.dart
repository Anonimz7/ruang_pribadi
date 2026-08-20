import 'dart:math';

class PasswordGeneratorService {
  static const String upperCaseLetters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String lowerCaseLetters = 'abcdefghijklmnopqrstuvwxyz';
  static const String numbers = '0123456789';
  static const String specialCharacters = '!@#\$%^&*()_-+=<>?';

  static String generatePassword({
    required int length,
    required bool includeUppercase,
    required bool includeLowercase,
    required bool includeNumbers,
    required bool includeSpecial,
  }) {
    String chars = '';
    if (includeUppercase) chars += upperCaseLetters;
    if (includeLowercase) chars += lowerCaseLetters;
    if (includeNumbers) chars += numbers;
    if (includeSpecial) chars += specialCharacters;

    // Pastikan ada setidaknya satu jenis karakter yang dipilih
    if (chars.isEmpty) {
      return 'Pilih setidaknya satu opsi karakter!';
    }

    Random rnd = Random();
    return List.generate(length, (index) {
      return chars[rnd.nextInt(chars.length)];
    }).join();
  }
}
