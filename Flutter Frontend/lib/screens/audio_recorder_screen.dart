import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/ayah.dart';
import '../screens/match_results_view.dart';
import '../screens/quran_paged_view.dart';
import '../utils/quran_utils.dart';
import '../utils/recording_utils.dart';

class AudioRecorderScreen extends StatefulWidget {
  @override
  _AudioRecorderScreenState createState() => _AudioRecorderScreenState();
}

class _AudioRecorderScreenState extends State<AudioRecorderScreen> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  String? _recordedFilePath;
  Timer? _timer;
  int _recordDuration = 0;
  String? _backendResponse;

  List<Ayah>? _rawAyahs;
  List<Ayah>? _simpleAyahs;
  bool _isQuranLoaded = false;

  List<Map<String, dynamic>>? _lastMatches;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
    _loadQuranTexts();
  }

  Future<void> _loadQuranTexts() async {
    final raw = await loadQuranFromAsset('quran.txt');
    final simple = await loadQuranFromAsset('quran-simple.txt');
    setState(() {
      _rawAyahs = raw;
      _simpleAyahs = simple;
      _isQuranLoaded = true;
    });
  }

  Future<List<Ayah>> loadQuranFromAsset(String fileName) async {
    final raw = await rootBundle.loadString('assets/$fileName');
    final lines = raw.split('\n');
    final List<Ayah> ayahs = [];

    for (final line in lines) {
      if (line.trim().isEmpty || !line.contains('|')) continue;
      final parts = line.split('|');
      if (parts.length < 3) continue;
      try {
        final surah = int.parse(parts[0].trim());
        final ayah = int.parse(parts[1].trim());
        final text = parts[2].trim();
        ayahs.add(Ayah(surah: surah, ayah: ayah, text: text));
      } catch (_) {}
    }

    return ayahs;
  }

  Future<void> _initializeRecorder() async {
    await Permission.microphone.request();
    await Permission.storage.request();
    await _recorder.openRecorder();
  }

  Future<void> _sendToBackend() async {
    if (_recordedFilePath == null || !_isQuranLoaded) return;

    setState(() {
      _backendResponse = "⏳ جاري معالجة التسجيل...";
    });

    try {
      final uri = Uri.parse('http://10.0.2.2:5000/transcribe');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', _recordedFilePath!));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['matches'] != null && data['matches'].isNotEmpty) {
          _lastMatches = List<Map<String, dynamic>>.from(data['matches']);
          final firstMatch = _lastMatches!.first;
          final firstVerse = firstMatch['verses'][0] as Map<String, dynamic>;
          
          setState(() {
            _backendResponse = null;
          });
          
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QuranPagedView(
                rawAyahs: _rawAyahs!,
                simpleAyahs: _simpleAyahs!,
                highlightSurah: firstVerse['surah'],
                highlightAyahs: [firstVerse['ayah']],
                matchedText: firstMatch['matched_text'],
                highlightVerses: [firstVerse],
                wordsToHighlight: firstMatch['words_to_highlight'],
                allMatches: _lastMatches,
              ),
            ),
          );
        } else {
          setState(() {
            _backendResponse = "🔍 لم يتم العثور على تطابقات";
            _lastMatches = null;
          });
        }
      } else {
        setState(() {
          _backendResponse = "❌ خطأ: ${response.statusCode}";
          _lastMatches = null;
        });
      }
    } catch (e) {
      setState(() {
        _backendResponse = "❌ خطأ: ${e.toString()}";
        _lastMatches = null;
      });
    }
  }

  void _startRecording() async {
    final filePath = await getRecordingFilePath();
    
    setState(() {
      _isRecording = true;
      _recordedFilePath = filePath;
      _recordDuration = 0;
    });

    await _recorder.startRecorder(toFile: filePath, codec: Codec.aacADTS);

    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      _recordDuration++;
      if (_recordDuration >= 10) {
        _stopRecording();
      }
      setState(() {});
    });
  }

  void _stopRecording() async {
    if (!_isRecording) return;
    await _recorder.stopRecorder();
    _timer?.cancel();
    setState(() {
      _isRecording = false;
    });
    
    await _sendToBackend();
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _timer?.cancel();
    _backendResponse = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final durationText = _isRecording ? 'التسجيل: $_recordDuration ثانية' : '';
    return Scaffold(
      appBar: AppBar(
        title: Text('تطبيق التعرف على القرآن', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(Icons.mic, size: 50, color: Colors.teal),
                      SizedBox(height: 20),
                      Text(
                        'اضغط مع الاستمرار للتسجيل',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 30),
              GestureDetector(
                onLongPressStart: (_) => _startRecording(),
                onLongPressEnd: (_) => _stopRecording(),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  width: _isRecording ? 120 : 100,
                  height: _isRecording ? 120 : 100,
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.red : Colors.teal,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.mic_none,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                durationText,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              SizedBox(height: 20),
              if (_lastMatches != null)
                ElevatedButton.icon(
                  icon: Icon(Icons.search),
                  label: Text('نتائج البحث السابقة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MatchResultsView(
                          rawAyahs: _rawAyahs!,
                          simpleAyahs: _simpleAyahs!,
                          matches: _lastMatches!,
                        ),
                      ),
                    );
                  },
                ),
              SizedBox(height: 10),
              ElevatedButton.icon(
                icon: Icon(Icons.menu_book),
                label: Text('تصفح القرآن الكريم'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.teal[400],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: _isQuranLoaded
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => QuranPagedView(
                              rawAyahs: _rawAyahs!,
                              simpleAyahs: _simpleAyahs!,
                            ),
                          ),
                        );
                      }
                    : null,
              ),
              if (_backendResponse != null)
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal[100]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_backendResponse!.contains('⏳'))
                          CircularProgressIndicator(color: Colors.teal),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            _backendResponse!,
                            style: TextStyle(fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}