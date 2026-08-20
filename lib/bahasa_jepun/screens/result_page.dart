import 'package:flutter/material.dart';
import '../../database/dao/hirakana_dao.dart';

/// ResultPage untuk tabel hirakana
class ResultPage extends StatefulWidget {
  final String jenis;
  final String kategori;
  final bool acak;
  final bool sensorKarakter;
  final bool sensorRomaji;
  final bool multiView;
  final int slideCount;
  const ResultPage({
    super.key,
    required this.jenis,
    required this.kategori,
    required this.acak,
    required this.sensorKarakter,
    required this.sensorRomaji,
    required this.multiView,
    required this.slideCount,
  });

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  List<Map<String, dynamic>> data = [];
  int currentIndex = 0;
  bool isKarakterHidden = true;
  bool isRomajiHidden = true;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  void fetchData() async {
    var result = await HirakanaDao()
        .getData(widget.jenis, widget.kategori, widget.acak);
    setState(() {
      data = result;
    });
  }

  void nextCharacter() {
    int increment = widget.multiView ? widget.slideCount : 1;
    if (currentIndex + increment < data.length) {
      setState(() {
        currentIndex += increment;
        isKarakterHidden = true;
        isRomajiHidden = true;
      });
    }
  }

  void backCharacter() {
    int decrement = widget.multiView ? widget.slideCount : 1;
    if (currentIndex - decrement >= 0) {
      setState(() {
        currentIndex -= decrement;
        isKarakterHidden = true;
        isRomajiHidden = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentPage = widget.multiView
        ? (currentIndex ~/ widget.slideCount) + 1
        : currentIndex + 1;
    final totalPages = widget.multiView
        ? ((data.length + widget.slideCount - 1) ~/ widget.slideCount)
        : data.length;

    return Scaffold(
      appBar: AppBar(title: const Text("Hasil Hirakana")),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Jenis: ${widget.jenis.toUpperCase()}",
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                "Kategori: ${widget.kategori.toUpperCase()}",
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                "$currentPage/$totalPages",
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              widget.multiView
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(widget.slideCount, (index) {
                          int dataIndex = currentIndex + index;
                          if (dataIndex >= data.length) return const SizedBox();
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTapDown: (_) =>
                                      setState(() => isKarakterHidden = false),
                                  onTapUp: (_) =>
                                      setState(() => isKarakterHidden = true),
                                  child: widget.sensorKarakter &&
                                          isKarakterHidden
                                      ? Container(
                                          width: widget.multiView ? 60 : 100,
                                          height: widget.multiView ? 60 : 100,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.black,
                                          ),
                                        )
                                      : Text(
                                          data[dataIndex]['karakter'] ?? '-',
                                          style: TextStyle(
                                            fontFamily: 'NotoSansJP',
                                            fontSize:
                                                widget.multiView ? 60 : 100,
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 10),
                                GestureDetector(
                                  onTapDown: (_) =>
                                      setState(() => isRomajiHidden = false),
                                  onTapUp: (_) =>
                                      setState(() => isRomajiHidden = true),
                                  child: widget.sensorRomaji && isRomajiHidden
                                      ? Container(
                                          width: 30,
                                          height: 30,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.black,
                                          ),
                                        )
                                      : Text(
                                          data[dataIndex]['romaji'] ?? '-',
                                          style: const TextStyle(fontSize: 24),
                                        ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    )
                  : Column(
                      children: [
                        GestureDetector(
                          onTapDown: (_) =>
                              setState(() => isKarakterHidden = false),
                          onTapUp: (_) =>
                              setState(() => isKarakterHidden = true),
                          child: widget.sensorKarakter && isKarakterHidden
                              ? Container(
                                  width: widget.multiView ? 60 : 100,
                                  height: widget.multiView ? 60 : 100,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black,
                                  ),
                                )
                              : Text(
                                  data[currentIndex]['karakter'] ?? '-',
                                  style: TextStyle(
                                    fontFamily: 'NotoSansJP',
                                    fontSize: widget.multiView ? 60 : 100,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTapDown: (_) =>
                              setState(() => isRomajiHidden = false),
                          onTapUp: (_) => setState(() => isRomajiHidden = true),
                          child: widget.sensorRomaji && isRomajiHidden
                              ? Container(
                                  width: 30,
                                  height: 30,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black,
                                  ),
                                )
                              : Text(
                                  data[currentIndex]['romaji'] ?? '-',
                                  style: const TextStyle(fontSize: 24),
                                ),
                        ),
                      ],
                    ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: currentIndex > 0 ? backCharacter : null,
                    child: const Text("Back"),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: currentIndex <
                            data.length -
                                (widget.multiView ? widget.slideCount : 1)
                        ? nextCharacter
                        : null,
                    child: const Text("Next"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
