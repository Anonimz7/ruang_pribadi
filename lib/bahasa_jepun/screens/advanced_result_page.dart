import 'package:flutter/material.dart';
import '../../database/dao/advanced_dao.dart';

class AdvancedResultPage extends StatefulWidget {
  final String type;
  final bool acak;
  final String jlptLevel;
  final int limit;
  const AdvancedResultPage({
    super.key,
    required this.type,
    required this.acak,
    required this.jlptLevel,
    required this.limit,
  });

  @override
  State<AdvancedResultPage> createState() => _AdvancedResultPageState();
}

class _AdvancedResultPageState extends State<AdvancedResultPage> {
  List<Map<String, dynamic>> data = [];
  bool isLoading = true;
  int currentPage = 1;
  int totalCount = 0;
  int totalPages = 1;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  void fetchData() async {
    setState(() {
      isLoading = true;
    });
    try {
      // Ambil total count data terlebih dahulu
      int count = await AdvancedDao().getCountByType(
        widget.type,
        jlptLevel: widget.jlptLevel,
      );
      setState(() {
        totalCount = count;
        totalPages =
            count == 0 ? 1 : ((count + widget.limit - 1) ~/ widget.limit);
      });

      int offset = (currentPage - 1) * widget.limit;
      var result = await AdvancedDao().getDataByType(
        widget.type,
        widget.acak,
        jlptLevel: widget.jlptLevel,
        limit: widget.limit,
        offset: offset,
      );
      setState(() {
        data = result;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      // Tangani error sesuai kebutuhan
    }
  }

  void nextPage() {
    if (currentPage < totalPages) {
      setState(() {
        currentPage++;
        isLoading = true;
      });
      fetchData();
    }
  }

  void previousPage() {
    if (currentPage > 1) {
      setState(() {
        currentPage--;
        isLoading = true;
      });
      fetchData();
    }
  }

  void showDetailPopup(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(widget.type.toUpperCase()),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: buildDetailContent(widget.type, item),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Tutup"),
            ),
          ],
        );
      },
    );
  }

  List<Widget> buildDetailContent(String type, Map<String, dynamic> item) {
    List<Widget> content = [];
    if (type == "kanji" || type == "kanji_freq_use") {
      content.add(Text("Kanji: ${item['kanji'] ?? '-'}"));
      content.add(Text("Onyomi: ${item['onyomi'] ?? '-'}"));
      content.add(Text("Onchar: ${item['onchar'] ?? '-'}"));
      content.add(Text("Kunyomi: ${item['kunyomi'] ?? '-'}"));
      content.add(Text("Kunchar: ${item['kunchar'] ?? '-'}"));
      content.add(Text("Arti (EN): ${item['arti_en'] ?? '-'}"));
      content.add(Text("Arti (ID): ${item['arti_id'] ?? '-'}"));
      content.add(Text("JLPT Level: ${item['jlpt_level'] ?? '-'}"));
    } else if (type == "vocal") {
      content.add(Text("Kanji: ${item['kanji'] ?? '-'}"));
      content.add(Text("Verbal: ${item['verbal'] ?? '-'}"));
      content.add(Text("Verbal (JP): ${item['verbal_j'] ?? '-'}"));
      content.add(Text("Jenis Kata (EN): ${item['jenis_kata_en'] ?? '-'}"));
      content.add(Text("Jenis Kata (ID): ${item['jenis_kata_id'] ?? '-'}"));
      content.add(Text("Arti (EN): ${item['arti_en'] ?? '-'}"));
      content.add(Text("Arti (ID): ${item['arti_id'] ?? '-'}"));
      content.add(Text("JLPT Level: ${item['jlpt_level'] ?? '-'}"));
    } else if (type == "grammar") {
      content.add(Text("Tata Bahasa: ${item['tata_bahasa'] ?? '-'}"));
      content.add(Text("Tata Bahasa (JP): ${item['tata_bahasa_j'] ?? '-'}"));
      content.add(Text("Arti (EN): ${item['arti_en'] ?? '-'}"));
      content.add(Text("Arti (ID): ${item['arti_id'] ?? '-'}"));
      content.add(Text("JLPT Level: ${item['jlpt_level'] ?? '-'}"));
    } else if (type == "jlpt_grammar_full") {
      content.add(Text("Verbal: ${item['vechar'] ?? '-'}"));
      content.add(Text("Verbal (JP): ${item['javchar'] ?? '-'}"));
      content.add(Text("Arti (EN): ${item['arti_en'] ?? '-'}"));
      content.add(Text("Arti (ID): ${item['arti_id'] ?? '-'}"));
      content.add(Text("JLPT Level: ${item['jlpt_level'] ?? '-'}"));
    } else {
      content.add(const Text("Data tidak tersedia"));
    }
    return content;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.type.toUpperCase()} - List"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : data.isEmpty
              ? const Center(child: Text("Tidak ada data"))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        itemCount: data.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          var item = data[index];
                          String title = "";
                          if (widget.type == "kanji" ||
                              widget.type == "kanji_freq_use") {
                            title = item['kanji'] ?? '-';
                          } else if (widget.type == "vocal") {
                            title = item['verbal'] ?? '-';
                          } else if (widget.type == "grammar") {
                            title = item['tata_bahasa'] ?? '-';
                          } else if (widget.type == "jlpt_grammar_full") {
                            title = item['vechar'] ?? '-';
                          }
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: ListTile(
                              title: Text(
                                title,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                  "JLPT Level: ${item['jlpt_level'] ?? '-'}"),
                              trailing: const Icon(Icons.arrow_forward_ios),
                              onTap: () => showDetailPopup(item),
                            ),
                          );
                        },
                      ),
                    ),
                    // Tampilan pagination
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: currentPage > 1 ? previousPage : null,
                            child: const Text("Back"),
                          ),
                          const SizedBox(width: 20),
                          Text("Page $currentPage of $totalPages"),
                          const SizedBox(width: 20),
                          ElevatedButton(
                            onPressed:
                                currentPage < totalPages ? nextPage : null,
                            child: const Text("Next"),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
