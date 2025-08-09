# AlumniConnect

AlumniConnect is a cross-platform application designed to connect alumni and students, featuring chat, mock interviews, and more. The project consists of a Flutter frontend (`alumni_app`) and a Python Flask backend (`backend`).

## Features
- User authentication and profile management
- Real-time chat between users
- Mock interview generation using Gemini API
- Audio processing and transcription (Google Cloud)
- Firebase integration for data storage

## Project Structure
```
frameworkx/
├── alumni_app/   # Flutter frontend
├── backend/      # Python Flask backend
```

## Setup Guidelines

### Prerequisites
- Flutter SDK (for `alumni_app`)
- Python 3.8+ (for `backend`)
- Firebase project and service account
- Google Cloud project with Speech-to-Text and Text-to-Speech APIs enabled
- Gemini API key

### 1. Backend Setup
1. Navigate to the backend directory:
   ```sh
   cd backend
   ```
2. Create and activate a virtual environment (optional but recommended):
   ```sh
   python -m venv venv
   venv\Scripts\activate  # On Windows
   source venv/bin/activate  # On macOS/Linux
   ```
3. Install dependencies:
   ```sh
   pip install -r requirements.txt
   ```
4. Add your Firebase `serviceAccountKey.json` and `credentials.json` to the backend directory (not tracked by git).
5. Set environment variables:
   - `FIREBASE_DATABASE_URL` (in `.env` or system env)
   - `GEMINI_API_KEY` (in system env or `.env`)
6. Run the backend server:
   ```sh
   python app.py
   ```

### 2. Frontend (Flutter) Setup
1. Navigate to the alumni_app directory:
   ```sh
   cd alumni_app
   ```
2. Install dependencies:
   ```sh
   flutter pub get
   ```
3. Add your Firebase configuration files:
   - `google-services.json` (Android)
   - `GoogleService-Info.plist` (iOS)
4. Run the app:
   ```sh
   flutter run
   ```

## Notes
- Sensitive files like credentials and `.env` are ignored by git.
- For production, ensure all API keys and credentials are securely managed.

## License
This project is for educational purposes.
