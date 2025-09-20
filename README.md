# 📖 AyahFinder App

## Overview
This project is a **mobile application and backend system** designed to help worshippers follow along with the imam during prayers.  
Many people in mosques try to identify which verse the imam is reciting by searching manually on their phones.  
This app makes the process effortless by using **speech recognition** and **fuzzy matching** against the Qur’an.

---


## 🎥 Demo


---

## ✨ Features
- 🎤 **Record Audio**: Capture a short snippet of the imam’s recitation using the mobile app.  
- 🤖 **AI Transcription**: The snippet is sent to a Flask backend running **OpenAI Whisper** to transcribe Arabic speech to text.  
- 🔍 **Verse Matching**: Using **fuzzy search**, the app finds the most similar verses in the Qur’an.  
- 📌 **Direct Navigation**: The user is taken directly to the identified **surah** and **ayah**, with the matching text highlighted.  
- 📑 **Multiple Results**: If several matches exist, the user can scroll through them and verify.  
- 📚 **Browse Qur’an**: Built-in navigation to explore the Qur’an, organized by Surah, even without a recording.

---

## 🛠️ Tech Stack
- **Frontend**: Flutter (mobile app)  
- **Backend**: Python Flask API  
- **AI Model**: [OpenAI Whisper](https://github.com/openai/whisper) (for Arabic transcription)  
- **Search**: RapidFuzz (for fuzzy string matching)  

---

## 🚀 How It Works
1. User presses and holds the record button in the mobile app.  
2. The recorded audio (a few seconds of recitation) is sent to the backend.  
3. The backend transcribes the recitation into text.  
4. A fuzzy matching algorithm compares the transcription against the Qur’an.  
5. The app displays the best matches and highlights the corresponding ayah.  

---

## 🌍 Use Case
- Perfect for **taraweeh prayers**, where the imam recites long passages and worshippers want to follow along.  
- Useful for **students of Qur’an** to practice listening and instantly locating verses.  
- Helps create a **more engaging mosque experience** by allowing participants to quickly identify recited passages.

---