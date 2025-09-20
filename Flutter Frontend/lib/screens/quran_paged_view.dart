import 'package:flutter/material.dart';
import '../models/ayah.dart';
import '../utils/quran_utils.dart';

class QuranPagedView extends StatefulWidget {
  final List<Ayah> rawAyahs;
  final List<Ayah> simpleAyahs;
  final int? highlightSurah;
  final List<int>? highlightAyahs;
  final String? matchedText;
  final List<dynamic>? highlightVerses;
  final List<dynamic>? wordsToHighlight;
  final List<dynamic>? allMatches;

  QuranPagedView({
    required this.rawAyahs,
    required this.simpleAyahs,
    this.highlightSurah,
    this.highlightAyahs,
    this.matchedText,
    this.highlightVerses,
    this.wordsToHighlight,
    this.allMatches,
  });

  @override
  _QuranPagedViewState createState() => _QuranPagedViewState();
}

class _QuranPagedViewState extends State<QuranPagedView> {
  late Map<int, List<Ayah>> _surahs;
  late List<int> _surahOrder;
  int _currentSurahIndex = 0;
  bool _isLoading = true;
  late Map<int, Map<int, Set<int>>> _highlightWordIndices;
  late Map<int, Map<int, String>> _rawSurahAyahs;
  int _currentMatchIndex = 0;
  late List<Map<String, dynamic>> _matches;
  bool _hasMultipleMatches = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _highlightKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareData();
      _handleInitialScroll();
    });
  }

  void _handleInitialScroll() {
    if (widget.highlightSurah != null && widget.highlightAyahs != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToHighlight();
      });
    }
  }

  void _prepareData() {
    _surahs = {};
    for (final ayah in widget.simpleAyahs) {
      _surahs.putIfAbsent(ayah.surah, () => []).add(ayah);
    }

    _surahOrder = _surahs.keys.toList();

    if (widget.allMatches != null && widget.allMatches!.isNotEmpty) {
      _matches = List<Map<String, dynamic>>.from(widget.allMatches!);
      _hasMultipleMatches = _matches.length > 1;
      
      if (widget.highlightSurah != null) {
        _currentMatchIndex = _matches.indexWhere((match) => 
            (match['verses'][0] as Map<String, dynamic>)['surah'] == widget.highlightSurah &&
            (match['verses'][0] as Map<String, dynamic>)['ayah'] == widget.highlightAyahs?.first);
        if (_currentMatchIndex == -1) _currentMatchIndex = 0;
        _currentSurahIndex = _surahOrder.indexOf(widget.highlightSurah!);
      } else {
        _currentMatchIndex = 0;
        _currentSurahIndex = 0;
      }
    } else {
      _matches = [];
      _hasMultipleMatches = false;
      _currentSurahIndex = 0;
    }

    _rawSurahAyahs = {};
    for (final ayah in widget.rawAyahs) {
      _rawSurahAyahs.putIfAbsent(ayah.surah, () => {})[ayah.ayah] = ayah.text;
    }

    _highlightWordIndices = {};
    if (widget.wordsToHighlight != null) {
      _computeHighlightWordIndices(widget.wordsToHighlight!);
    }

    setState(() {
      _isLoading = false;
    });
    _handleInitialScroll();
  }

  void _computeHighlightWordIndices(List<dynamic> wordsToHighlight) {
    for (final wordInfo in wordsToHighlight) {
      final wordMap = wordInfo as Map<String, dynamic>;
      final surah = wordMap['surah'] as int;
      final ayah = wordMap['ayah'] as int;
      final position = wordMap['position'] as int;
      
      _highlightWordIndices.putIfAbsent(surah, () => {})
          .putIfAbsent(ayah, () => {})
          .add(position - 1);
    }
  }

  void _navigateToMatch(int direction) {
    if (_matches.isEmpty) return;

    setState(() {
      _currentMatchIndex = (_currentMatchIndex + direction) % _matches.length;
      if (_currentMatchIndex < 0) {
        _currentMatchIndex = _matches.length - 1;
      }

      final match = _matches[_currentMatchIndex];
      final verse = match['verses'][0] as Map<String, dynamic>;
      final wordsToHighlight = match['words_to_highlight'] as List<dynamic>;
      
      _highlightWordIndices.clear();
      _computeHighlightWordIndices(wordsToHighlight);
      
      final surahNum = verse['surah'] as int;
      _currentSurahIndex = _surahOrder.indexOf(surahNum);
    });

    _handleInitialScroll();
  }

  void _showSurahPickerDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('اختر السورة', textAlign: TextAlign.center),
            content: Container(
              width: double.maxFinite,
              height: 400,
              child: ListView.builder(
                itemCount: _surahOrder.length,
                itemBuilder: (context, index) {
                  final surahNum = _surahOrder[index];
                  final name = getSurahName(surahNum);
                  return ListTile(
                    title: Text(
                      name,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: Text(
                      surahNum.toString(),
                      style: TextStyle(color: Colors.teal),
                    ),
                    onTap: () {
                      setState(() {
                        _currentSurahIndex = index;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

List<TextSpan> _buildSurahText(int surah, List<Ayah> ayahs) {
  final spans = <TextSpan>[];
  final currentMatch = _matches.isNotEmpty ? _matches[_currentMatchIndex] : null;
  final currentVerse = currentMatch != null ? currentMatch['verses'][0] as Map<String, dynamic> : null;
  final isCurrentSurah = currentVerse != null && surah == currentVerse['surah'];

  // Add Surah name
  spans.add(TextSpan(
    text: '\n${getSurahName(surah)}\n',
    style: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: Colors.teal,
      fontFamily: 'QuranFontRegular',
    ),
  ));

  // Add Bismillah for all Surahs except Al-Fatihah (1) and Al-Tawbah (9)
  if (surah != 1 && surah != 9) {
    spans.add(TextSpan(
      text: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\n\n',
      style: TextStyle(
        fontSize: 24,
        color: Colors.black,
        fontFamily: 'QuranFont',
        fontWeight: FontWeight.w500,
        height: 2,
      ),
    ));
  }

  for (final ayah in ayahs) {
    final isHighlightedAyah = currentVerse != null && 
        ayah.ayah == currentVerse['ayah'] && 
        isCurrentSurah;
    
    // Handle first ayah differently for surahs with Basmalah
    if (surah != 1 && surah != 9 && ayah.ayah == 1) {
      const basmala ="بِسْمِ اللَّهِ الرَّحْمَـٰنِ الرَّحِيمِ";
      
      // Case 1: The entire ayah is just Basmalah - skip it completely
      if (ayah.text.trim() == basmala) {
        continue;
      }
      // Case 2: Ayah starts with Basmalah - remove it and keep the rest
      else if (ayah.text.contains(basmala)) {
        final trimmed = ayah.text.replaceFirst(basmala, '').trim();
        if (trimmed.isNotEmpty) {  // Only add if there's remaining text
          spans.add(TextSpan(
            children: [
              if (isHighlightedAyah)
                WidgetSpan(
                  child: SizedBox(
                    key: _highlightKey,
                    width: 0,
                    height: 0,
                  ),
                ),
              ..._highlightWords(trimmed, ayah.ayah, ayah.surah),
            ],
          ));
          spans.add(TextSpan(
            text: ' ﴿${ayah.ayah}﴾ ',
            style: TextStyle(
              color: Colors.blueGrey,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'QuranFont',
            ),
          ));
        }
        continue;
      }
    }

    // Normal ayah processing
    spans.add(TextSpan(
      children: [
        if (isHighlightedAyah)
          WidgetSpan(
            child: SizedBox(
              key: _highlightKey,
              width: 0,
              height: 0,
            ),
          ),
        ..._highlightWords(ayah.text, ayah.ayah, ayah.surah),
      ],
    ));
    spans.add(TextSpan(
      text: ' ﴿${ayah.ayah}﴾ ',
      style: TextStyle(
        color: Colors.blueGrey,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontFamily: 'QuranFont',
      ),
    ));
  }

  return spans;
}

  List<TextSpan> _highlightWords(String ayahText, int ayahNumber, int surahNumber) {
    final words = ayahText.trim().split(RegExp(r'\s+'));
    final spans = <TextSpan>[];

    final highlightIndices = _highlightWordIndices[surahNumber]?[ayahNumber] ?? {};

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final shouldHighlight = highlightIndices.contains(i);

      spans.add(TextSpan(
        text: '$word ',
        style: shouldHighlight
            ? TextStyle(
                backgroundColor: Colors.yellow.withOpacity(0.5),
                color: Colors.black,
                fontWeight: FontWeight.bold,
              )
            : TextStyle(color: Colors.black),
      ));
    }

    return spans;
  }

  void _scrollToHighlight() {
    if (_highlightKey.currentContext != null) {
      Scrollable.ensureVisible(
        _highlightKey.currentContext!,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.2,
      );
    } else {
      Future.delayed(Duration(milliseconds: 100), () {
        if (_highlightKey.currentContext != null) {
          Scrollable.ensureVisible(
            _highlightKey.currentContext!,
            duration: Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.2,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text("جاري التحميل...")),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentSurah = _surahOrder[_currentSurahIndex];
    final ayahs = _surahs[currentSurah]!;

    return Scaffold(
      appBar: AppBar(
        title: Text(getSurahName(currentSurah), style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.menu_book),
            tooltip: 'اختر السورة',
            onPressed: _showSurahPickerDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_hasMultipleMatches)
            Container(
              padding: EdgeInsets.symmetric(vertical: 8),
              color: Colors.teal[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back),
                    onPressed: () => _navigateToMatch(-1),
                  ),
                  Text(
                    'النتيجة ${_currentMatchIndex + 1} من ${_matches.length}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: Icon(Icons.arrow_forward),
                    onPressed: () => _navigateToMatch(1),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Container(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: RichText(
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 24,
                      fontFamily: 'QuranFont',
                    ),
                    children: _buildSurahText(currentSurah, ayahs),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.arrow_back),
                  label: Text("السابق"),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.teal[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _currentSurahIndex > 0
                      ? () {
                          setState(() {
                            _currentSurahIndex--;
                          });
                        }
                      : null,
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.arrow_forward),
                  label: Text("التالي"),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.teal[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _currentSurahIndex < _surahOrder.length - 1
                      ? () {
                          setState(() {
                            _currentSurahIndex++;
                          });
                        }
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}