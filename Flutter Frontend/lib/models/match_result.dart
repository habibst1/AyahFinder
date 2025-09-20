class MatchResult {
  final String matchedText;
  final double score;
  final List<Map<String, dynamic>> verses;
  final List<dynamic> wordsToHighlight;

  MatchResult({
    required this.matchedText,
    required this.score,
    required this.verses,
    required this.wordsToHighlight,
  });

  factory MatchResult.fromJson(Map<String, dynamic> json) {
    return MatchResult(
      matchedText: json['matched_text'],
      score: json['score'],
      verses: List<Map<String, dynamic>>.from(json['verses']),
      wordsToHighlight: json['words_to_highlight'],
    );
  }
}