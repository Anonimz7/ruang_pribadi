import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/arithmetic_operation.dart';
import '../models/record.dart';
import '../providers/record_provider.dart';

class RecordScreen extends StatelessWidget {
  const RecordScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final recordProvider = Provider.of<RecordProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text("Rekor")),
      body: ListView(
        children: ArithmeticOperation.values.map((op) {
          String opName = opToString(op);
          Record? rec = recordProvider.records[op];
          String scoreText = rec != null ? rec.topScore.toString() : "0";
          String timeText =
              rec != null && rec.bestAverageTime != double.infinity
                  ? rec.bestAverageTime.toStringAsFixed(2)
                  : "-";
          return ListTile(
            title: Text(opName),
            subtitle: Text(
                "Top Nilai: $scoreText, Waktu Rata-rata Terbaik: $timeText detik"),
          );
        }).toList(),
      ),
    );
  }
}
