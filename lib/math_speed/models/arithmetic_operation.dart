/// Enum untuk jenis operasi matematika.
enum ArithmeticOperation { addition, subtraction, multiplication, division }

String opToString(ArithmeticOperation op) {
  switch (op) {
    case ArithmeticOperation.addition:
      return "Penjumlahan";
    case ArithmeticOperation.subtraction:
      return "Pengurangan";
    case ArithmeticOperation.multiplication:
      return "Perkalian";
    case ArithmeticOperation.division:
      return "Pembagian";
  }
}
