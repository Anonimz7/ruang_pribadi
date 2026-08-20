import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quiz_provider.dart';
import '../providers/settings_provider.dart';

class Keypad extends StatelessWidget {
  final String keyboardSize;
  const Keypad({super.key, required this.keyboardSize});

  double _getButtonSize() {
    switch (keyboardSize) {
      case "small":
        return 50;
      case "large":
        return 70;
      case "medium":
      default:
        return 60;
    }
  }

  @override
  Widget build(BuildContext context) {
    double buttonSize = _getButtonSize();
    double spacing = 8;

    Widget buildButton(String text, {VoidCallback? onPressed, IconData? icon}) {
      return SizedBox(
        width: buttonSize,
        height: buttonSize,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            alignment: Alignment.center,
            padding: EdgeInsets.zero,
          ),
          onPressed: onPressed,
          child: icon != null
              ? Icon(icon, size: buttonSize / 2)
              : Text(text, style: TextStyle(fontSize: buttonSize / 2.5)),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            buildButton("1", onPressed: () {
              Provider.of<QuizProvider>(context, listen: false).addDigit("1");
            }),
            buildButton("2", onPressed: () {
              Provider.of<QuizProvider>(context, listen: false).addDigit("2");
            }),
            buildButton("3", onPressed: () {
              Provider.of<QuizProvider>(context, listen: false).addDigit("3");
            }),
          ],
        ),
        SizedBox(height: spacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            buildButton("4", onPressed: () {
              Provider.of<QuizProvider>(context, listen: false).addDigit("4");
            }),
            buildButton("5", onPressed: () {
              Provider.of<QuizProvider>(context, listen: false).addDigit("5");
            }),
            buildButton("6", onPressed: () {
              Provider.of<QuizProvider>(context, listen: false).addDigit("6");
            }),
          ],
        ),
        SizedBox(height: spacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            buildButton("7", onPressed: () {
              Provider.of<QuizProvider>(context, listen: false).addDigit("7");
            }),
            buildButton("8", onPressed: () {
              Provider.of<QuizProvider>(context, listen: false).addDigit("8");
            }),
            buildButton("9", onPressed: () {
              Provider.of<QuizProvider>(context, listen: false).addDigit("9");
            }),
          ],
        ),
        SizedBox(height: spacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            buildButton("", onPressed: () {
              Provider.of<QuizProvider>(context, listen: false).deleteDigit();
            }, icon: Icons.backspace),
            buildButton("0", onPressed: () {
              Provider.of<QuizProvider>(context, listen: false).addDigit("0");
            }),
            buildButton("", onPressed: () {
              Provider.of<QuizProvider>(context, listen: false).submitAnswer(
                settings: Provider.of<SettingsProvider>(context, listen: false),
              );
            }, icon: Icons.check),
          ],
        ),
      ],
    );
  }
}
