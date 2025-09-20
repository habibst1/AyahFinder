import os
import threading
import time
os.environ['KMP_DUPLICATE_LIB_OK']='True'
from flask import Flask, request, jsonify
from transformers import WhisperForConditionalGeneration, WhisperProcessor, pipeline
import torch
from rapidfuzz import fuzz

app = Flask(__name__)

# Load Whisper Model
device = "cuda:0" if torch.cuda.is_available() else "cpu"
print("Device Used: " , device)
torch_dtype = torch.float16 if torch.cuda.is_available() else torch.float32

model_name = "openai/whisper-large-v3-turbo"
processor = WhisperProcessor.from_pretrained(model_name)
model = WhisperForConditionalGeneration.from_pretrained(model_name, torch_dtype=torch_dtype).to(device)

pipe = pipeline(
    "automatic-speech-recognition",
    model=model,
    tokenizer=processor.tokenizer,
    feature_extractor=processor.feature_extractor,
    torch_dtype=torch_dtype,
    device=device,
    chunk_length_s=None,
    return_timestamps=True,
    generate_kwargs={"language": "arabic", "task": "transcribe"},
)

print("Warmupping...")
warmup = pipe("audio.mp3")
warmup_text = warmup["text"]
print("Finished Warmupping.")
print("Warmup Text: " , warmup_text)

# Updated fuzzy search function to find top 5 distinct matches with words to highlight
def fuzzy_search(text, result_container):
    start_time = time.time()
    transcribed_len = len(text)
    min_score = 90  # Minimum score threshold
    
    # First find all potential matches
    all_matches = []
    for i in range(len(big_text) - transcribed_len + 1):
        substring = big_text[i:i+transcribed_len]
        score = fuzz.ratio(text, substring)
        
        if score >= min_score:
            # Find which verses this substring covers
            covered_verse_indices = []
            for idx, (start, end) in enumerate(positions):
                if end >= i and start <= i + transcribed_len:
                    covered_verse_indices.append(idx)
            
            if covered_verse_indices:
                all_matches.append({
                    'score': score,
                    'start': i,
                    'end': i + transcribed_len,
                    'verse_indices': covered_verse_indices,
                    'matched_text': substring
                })
    
    # Sort all matches by score (highest first)
    all_matches.sort(reverse=True, key=lambda x: x['score'])
    
    # Select top matches ensuring no verse overlap
    top_matches = []
    used_verses = set()
    
    for match in all_matches:
        # Check if any of these verses are already used
        if not any(v in used_verses for v in match['verse_indices']):
            # Find words to highlight in these verses
            words_to_highlight = []
            for verse_idx in match['verse_indices']:
                verse = verses[verse_idx]
                words = verse_words[verse_idx]
                
                for word in words:
                    # Check if word overlaps with the matched substring
                    if not (word['end'] < match['start'] or word['start'] > match['end']):
                        words_to_highlight.append({
                            "surah": verse['surah'],
                            "ayah": verse['ayah'],
                            "position": word['position'],
                            "word": word['text']
                        })
            
            match['words_to_highlight'] = words_to_highlight
            top_matches.append(match)
            used_verses.update(match['verse_indices'])
            # if len(top_matches) >= 5:
            #     break
    
    # Prepare the result with verse details
    results = []
    for match in top_matches:
        covered_verses = [verses[i] for i in match['verse_indices']]
        first = covered_verses[0]
        last = covered_verses[-1]
        
        results.append({
            'score': match['score'],
            'start': match['start'],
            'end': match['end'],
            'matched_text': match['matched_text'],
            'verses': covered_verses,
            'surah_range': f"{first['surah']}:{first['ayah']}-{last['surah']}:{last['ayah']}",
            'verse_text': " ".join(v['text'] for v in covered_verses),
            'words_to_highlight': match['words_to_highlight']
        })
    
    result_container['matches'] = results
    print(f"[FUZZY SEARCH] Found {len(results)} matches in {time.time() - start_time:.2f} seconds")

# Load Quran text with word-level information
verses = []
texts = []
positions = []
verse_words = []  # Store word information for each verse
big_text = ""
current_pos = 0

load_start = time.time()
with open("quran.txt", encoding="utf-8") as f:
    for line in f:
        parts = line.strip().split("|", 2)
        if len(parts) == 3:
            surah, ayah, text = parts
            verses.append({"surah": int(surah), "ayah": int(ayah), "text": text})
            texts.append(text)
            
            # Process words in this verse
            words = []
            word_start = current_pos
            for word_pos, word in enumerate(text.split()):
                word_end = word_start + len(word)
                words.append({
                    "text": word,
                    "start": word_start,
                    "end": word_end,
                    "position": word_pos + 1  # 1-based position in ayah
                })
                word_start = word_end + 1  # +1 for space
            
            verse_words.append(words)
            
            # Record positions in big text
            start = current_pos
            end = start + len(text)
            positions.append((start, end))
            big_text += text + " "
            current_pos = end + 1
print(f"[QURAN LOAD] Completed in {time.time() - load_start:.2f} seconds")

@app.route("/transcribe", methods=["POST"])
def transcribe():
    total_start = time.time()
    
    if 'file' not in request.files:
        return jsonify({"error": "No file part"}), 400

    file = request.files['file']
    if file.filename == "":
        return jsonify({"error": "No selected file"}), 400

    temp_path = f"temp_{file.filename}"
    file_save_start = time.time()
    file.save(temp_path)
    print(f"[FILE SAVE] Completed in {time.time() - file_save_start:.2f} seconds")

    try:
        # Step 1: Transcription
        transcribe_start = time.time()
        result = pipe(temp_path)
        if "ألف لام ميم" in result["text"]:
            result["text"] = result["text"].replace("ألف لام ميم", "الم")
        text = result["text"]
        # text = "من شر ما خلق ومن شر غاسق إذا وقب ومن شر النفاثات في العقد"
        # text = "من شر ما خلق"
        print(f"[TRANSCRIPTION] Completed in {time.time() - transcribe_start:.2f} seconds")
        print(f"[TRANSCRIPTION TEXT] {text}")

        # Step 2: Fuzzy matching
        fuzzy_start = time.time()
        result_container = {'matches': []}
        search_thread = threading.Thread(target=fuzzy_search, args=(text, result_container))
        search_thread.start()
        search_thread.join(timeout=10)

        if search_thread.is_alive():
            print("[FUZZY SEARCH] Timed out after 10 seconds")
            return jsonify({
                "text": text,
                "matches": [],
                "message": "Search timed out"
            })
        
        matches = result_container['matches']
        print(f"[FUZZY TOTAL] Completed in {time.time() - fuzzy_start:.2f} seconds")

        print(f"[TOTAL TIME] {time.time() - total_start:.2f} seconds")
        
        return jsonify({
            "text": text,
            "matches": matches,
            "count": len(matches)
        })

    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)

if __name__ == "__main__":
    app.run(debug=True)