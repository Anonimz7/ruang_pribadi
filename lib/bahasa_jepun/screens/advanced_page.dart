import 'package:flutter/material.dart';
import 'advanced_result_page.dart';

class AdvancedPage extends StatefulWidget {
  const AdvancedPage({super.key});
  @override
  State<AdvancedPage> createState() => _AdvancedPageState();
}

class _AdvancedPageState extends State<AdvancedPage> {
  String? selectedType;
  bool isAcak = false;
  // Opsi tipe sesuai dengan nama tabel di database
  final List<String> advancedTypes = [
    "kanji",
    "vocal",
    "grammar",
    "kanji_freq_use",
    "jlpt_grammar_full"
  ];
  String selectedJLPT = "Semua"; // filter JLPT level
  final List<String> jlptOptions = ["Semua", "N1", "N2", "N3", "N4", "N5"];

  int selectedLimit = 10; // maksimal list view data
  final List<int> limitOptions = [10, 50, 100];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Advanced Feature")),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DropdownButton<String>(
                hint: const Text("Pilih Tipe"),
                value: selectedType,
                items: advancedTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedType = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Acak Data"),
                  Switch(
                    value: isAcak,
                    onChanged: (value) {
                      setState(() {
                        isAcak = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Dropdown filter JLPT level
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Filter JLPT Level: "),
                  DropdownButton<String>(
                    value: selectedJLPT,
                    items: jlptOptions.map((level) {
                      return DropdownMenuItem<String>(
                        value: level,
                        child: Text(level),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedJLPT = value!;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Dropdown untuk batas data (limit)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Max Data: "),
                  DropdownButton<int>(
                    value: selectedLimit,
                    items: limitOptions.map((limit) {
                      return DropdownMenuItem<int>(
                        value: limit,
                        child: Text(limit.toString()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedLimit = value!;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: selectedType != null
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdvancedResultPage(
                              type: selectedType!,
                              acak: isAcak,
                              jlptLevel: selectedJLPT,
                              limit: selectedLimit,
                            ),
                          ),
                        );
                      }
                    : null,
                child: const Text("Tampilkan Data"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
