import 'package:flutter/material.dart';
import '../../database/dao/hirakana_dao.dart';
import 'result_page.dart';
import 'advanced_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Fitur asli untuk tabel hirakana
  String? selectedJenis;
  String? selectedKategori;
  bool isAcak = false;
  bool isSensorKarakterEnabled = false;
  bool isSensorRomajiEnabled = false;
  bool isMultiViewEnabled = false;
  int slideCount = 2;
  Map<String, List<String>> kategoriOptions = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchKategoriOptions();
  }

  void fetchKategoriOptions() async {
    final result = await HirakanaDao().getKategoriOptions();
    setState(() {
      kategoriOptions = result;
      isLoading = false;
    });
  }

  void showCategoryDialog() {
    if (selectedJenis != null && selectedKategori == null) {
      selectedKategori = kategoriOptions[selectedJenis!]!.first;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pilih Kategori'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateDialog) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selectedJenis != null)
                      RadioGroup<String>(
                        groupValue: selectedKategori,
                        onChanged: (String? value) {
                          setStateDialog(() {
                            selectedKategori = value;
                          });
                        },
                        child: Column(
                          children: kategoriOptions[selectedJenis!]!
                              .map((kategori) {
                            return RadioListTile<String>(
                              title: Text(kategori),
                              value: kategori,
                            );
                          }).toList(),
                        ),
                      ),
                    SwitchListTile(
                      title: const Text("Acak Data"),
                      value: isAcak,
                      onChanged: (bool value) {
                        setStateDialog(() {
                          isAcak = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text("Sensor Karakter"),
                      value: isSensorKarakterEnabled,
                      onChanged: (bool value) {
                        setStateDialog(() {
                          isSensorKarakterEnabled = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text("Sensor Romaji"),
                      value: isSensorRomajiEnabled,
                      onChanged: (bool value) {
                        setStateDialog(() {
                          isSensorRomajiEnabled = value;
                        });
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text("Multi View"),
                      value: isMultiViewEnabled,
                      onChanged: (bool value) {
                        setStateDialog(() {
                          isMultiViewEnabled = value;
                        });
                      },
                    ),
                    if (isMultiViewEnabled)
                      Column(
                        children: [
                          const Text("Jumlah Huruf per Halaman"),
                          Slider(
                            value: slideCount.toDouble(),
                            min: 2,
                            max: 5,
                            divisions: 3,
                            label: "$slideCount",
                            onChanged: (double value) {
                              setStateDialog(() {
                                slideCount = value.toInt();
                              });
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text("Proses"),
              onPressed: () {
                Navigator.pop(context);
                if (selectedJenis != null && selectedKategori != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ResultPage(
                        jenis: selectedJenis!,
                        kategori: selectedKategori!,
                        acak: isAcak,
                        sensorKarakter: isSensorKarakterEnabled,
                        sensorRomaji: isSensorRomajiEnabled,
                        multiView: isMultiViewEnabled,
                        slideCount: slideCount,
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Fitur asli untuk tabel hirakana
            DropdownButton<String>(
              hint: const Text("Pilih Jenis"),
              value: selectedJenis,
              items: kategoriOptions.keys.map((jenis) {
                return DropdownMenuItem<String>(
                  value: jenis,
                  child: Text(jenis),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedJenis = value;
                  selectedKategori = kategoriOptions[value!]!.first;
                });
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: selectedJenis != null ? showCategoryDialog : null,
              child: const Text("Proses"),
            ),
            const SizedBox(height: 20),
            // Tombol untuk fitur Advanced
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdvancedPage()),
                );
              },
              child: const Text("Advanced"),
            ),
          ],
        ),
      ),
    );
  }
}
