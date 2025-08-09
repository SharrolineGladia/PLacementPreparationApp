from flask import Flask, request, jsonify, send_file
import google.generativeai as genai
import os
from dotenv import load_dotenv
from google.cloud import texttospeech, speech
from google.oauth2 import service_account
import logging
from moviepy.editor import AudioFileClip  # Import MoviePy
import firebase_admin
from firebase_admin import credentials, db
import random
import json
import ast
import re


# Load environment variables from .env file
load_dotenv()
app = Flask(__name__)

# Set up logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

# Set up Gemini API key
genai.configure(api_key=os.environ.get("GEMINI_API_KEY"))

if not os.environ.get("GEMINI_API_KEY"):
    raise ValueError("GEMINI_API_KEY environment variable is not set")


# Initialize Firebase
try:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_db_url = os.environ.get("FIREBASE_DATABASE_URL")
    if not firebase_db_url:
        raise ValueError("FIREBASE_DATABASE_URL environment variable is not set")
    firebase_admin.initialize_app(cred, {
        'databaseURL': firebase_db_url
    })
    logger.info("Firebase initialized successfully")
except Exception as e:
    logger.error(f"Failed to initialize Firebase: {str(e)}")
    raise

# Get a reference to the database
ref = db.reference('questions')

# Load the credentials for Text-to-Speech and Speech-to-Text clients
credentials_path = "credentials.json"
tts_credentials = service_account.Credentials.from_service_account_file(credentials_path)
tts_client = texttospeech.TextToSpeechClient(credentials=tts_credentials)
stt_credentials = service_account.Credentials.from_service_account_file(credentials_path)
stt_client = speech.SpeechClient(credentials=stt_credentials)

# Select the Gemini model
model = genai.GenerativeModel('gemini-1.0-pro')




def select_fallback_categories(all_questions, num_categories):
    # Implement a fallback method to select categories if Gemini fails
    all_categories = list(set(q['category'] for q in all_questions))
    return random.sample(all_categories, min(num_categories, len(all_categories)))

def generate_java_questions_with_gemini(num_questions=3):
    try:
        question_prompt = f"""
        You are an expert Java interviewer conducting interviews for college-level placement. 
        Generate {num_questions} Java basic interview questions.Dont ask any implementation questions. These questions should:
        
        1. Be relevant for entry-level Java positions
        2. Have continuity and flow well from one to another
        3. Be at a basic to intermediate level, suitable for college graduates
        4. Cover a range of fundamental Java concepts

        Your response must be a valid JSON array of objects. Each object must have a 'question' key.
        Do not include any additional text or formatting outside of the JSON structure.
        """

        logger.debug(f"Sending question prompt to Gemini: {question_prompt[:100]}...")
        question_response = model.generate_content(question_prompt)
        logger.debug(f"Raw Gemini response: {question_response.text}")

        # Process the response
        questions = preprocess_gemini_response(question_response.text)

        if questions and isinstance(questions, list):
            logger.info(f"Successfully generated {len(questions)} questions")
            return questions
        else:
            logger.error("Gemini response is not in the expected format")
            logger.debug(f"Processed questions: {questions}")
            return []

    except Exception as e:
        logger.error(f"Error generating questions with Gemini: {str(e)}")
        return []
    
@app.route('/start_interview', methods=['POST'])
def start_interview():
    try:
        logger.info("Starting interview process")
        questions = generate_java_questions_with_gemini()
        
        if not questions:
            logger.error("Failed to generate questions")
            return jsonify({"error": "Failed to generate questions"}), 500
        
        logger.info(f"Generated {len(questions)} questions with Gemini")
        
        # Ensure the questions are in the correct format
        formatted_questions = []
        for q in questions:
            if isinstance(q, dict):
                formatted_questions.append(q)
            elif isinstance(q, str):
                formatted_questions.append({"question": q})
            else:
                logger.warning(f"Unexpected question format: {q}")
                formatted_questions.append({"question": str(q)})
        
        # Return the formatted questions
        return jsonify({"questions": formatted_questions})
    except Exception as e:
        logger.error(f"Failed to start interview: {str(e)}")
        return jsonify({"error": str(e)}), 500
    
def preprocess_gemini_response(response_text):
    # Remove the Markdown code block syntax
    cleaned_response = response_text.strip()
    if cleaned_response.startswith("```json") and cleaned_response.endswith("```"):
        cleaned_response = cleaned_response[7:-3]  # Remove ```json from start and ``` from end
    
    # Parse the JSON
    try:
        questions = json.loads(cleaned_response)
        return questions
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse Gemini response as JSON: {str(e)}")
        logger.debug(f"Cleaned response: {cleaned_response}")
        return None

@app.route('/get_question_audio', methods=['POST'])
def get_question_audio():
    data = request.json
    question = data['question']
    
    # Configure the voice
    synthesis_input = texttospeech.SynthesisInput(text=question)
    voice = texttospeech.VoiceSelectionParams(
        language_code="en-US", ssml_gender=texttospeech.SsmlVoiceGender.NEUTRAL
    )
    audio_config = texttospeech.AudioConfig(
        audio_encoding=texttospeech.AudioEncoding.MP3
    )

    # Perform the text-to-speech request
    response = tts_client.synthesize_speech(
        input=synthesis_input, voice=voice, audio_config=audio_config
    )

    # Save the audio content to a file
    output_filename = os.path.join("server_files", "output.mp3")
    os.makedirs("server_files", exist_ok=True)  # Create the folder if it doesn't exist

    with open(output_filename, "wb") as out:
        out.write(response.audio_content)

    app.logger.info(f"Saved question audio to {output_filename}")

    return send_file(output_filename, mimetype="audio/mpeg")

def convert_aac_to_mp3(input_file):
    output_file = input_file.rsplit('.', 1)[0] + '.mp3'
    try:
        # Use MoviePy to convert AAC to MP3
        audio_clip = AudioFileClip(input_file)
        audio_clip.write_audiofile(output_file, codec='libmp3lame')
        audio_clip.close()  # Close the audio file to free resources
        return output_file
    except Exception as e:
        app.logger.error(f"Error converting audio: {e}")
        return None

@app.route('/submit_audio_answer', methods=['POST'])
def submit_audio_answer():
    app.logger.info("Received audio submission request")
    if 'file' not in request.files:
        app.logger.error("No file part in the request")
        return jsonify({"error": "No file part"}), 400
    file = request.files['file']
    if file.filename == '':
        app.logger.error("No selected file")
        return jsonify({"error": "No selected file"}), 400
    
    try:
        # Save the uploaded file on the server side for confirmation
        upload_dir = "server_files"
        os.makedirs(upload_dir, exist_ok=True)  # Create the folder if it doesn't exist
        uploaded_filename = os.path.join(upload_dir, file.filename)
        file.save(uploaded_filename)

        app.logger.info(f"Uploaded file saved to {uploaded_filename}")

        # Convert AAC to MP3
        mp3_filename = convert_aac_to_mp3(uploaded_filename)
        app.logger.info(f"Converted to MP3: {mp3_filename}, exists: {os.path.exists(mp3_filename)}")
        if not mp3_filename or not os.path.exists(mp3_filename):
            return jsonify({"error": "Failed to convert audio file"}), 500

        # Read the MP3 file
        with open(mp3_filename, 'rb') as audio_file:
            audio_content = audio_file.read()

        # Perform speech recognition
        audio = speech.RecognitionAudio(content=audio_content)
        config = speech.RecognitionConfig(
            encoding=speech.RecognitionConfig.AudioEncoding.MP3,
            sample_rate_hertz=44100,  # Typical sample rate for MP3
            language_code="en-US",
        )

        app.logger.info("Sending request to Google Speech-to-Text API")
        response = stt_client.recognize(config=config, audio=audio)
        app.logger.info(f"Received response from Google Speech-to-Text API: {response}")

        # Get the transcription
        if response.results:
            transcription = response.results[0].alternatives[0].transcript
            app.logger.info(f"Transcription: {transcription}")
        else:
            app.logger.warning("No transcription results returned from the API")
            transcription = ""

        if not transcription:
            app.logger.error("Failed to transcribe audio (empty transcription)")
            return jsonify({"error": "Failed to transcribe audio (empty transcription)"}), 400

        return jsonify({"transcription": transcription})

    except Exception as e:
        app.logger.error(f"Error during transcription: {str(e)}")
        return jsonify({"error": f"Failed to transcribe audio: {str(e)}"}), 500

@app.route('/evaluate_answer', methods=['POST'])
def evaluate_answer():
    data = request.json
    question = data['question']
    answer = data['answer']

    app.logger.info(f"Received question: {question}")
    app.logger.info(f"Received answer: {answer}")

    prompt = f"""
    You are an expert Java interviewer. Evaluate the candidate's answer to the following question:

    Question: {question}
    Answer: {answer}

    Evaluate the answer based on the following criteria:
    1. Relevance (0-10)
    2. Correctness (0-10)
    3. Clarity (0-10)
    4. Depth (0-10)

    Provide a score and brief feedback for each criterion. Then give an overall score.
    Format your response exactly as follows:

    Relevance: [score]
    Relevance Feedback: [1-2 sentence explanation]
    Correctness: [score]
    Correctness Feedback: [1-2 sentence explanation]
    Clarity: [score]
    Clarity Feedback: [1-2 sentence explanation]
    Depth: [score]
    Depth Feedback: [1-2 sentence explanation]
    Overall Score: [average of all scores]
    """

    try:
        response = model.generate_content(prompt)
        evaluation = response.text
    except Exception as e:
        app.logger.error(f"Error calling Gemini API: {e}")
        return jsonify({"error": "Failed to evaluate answer"}), 500

    app.logger.info("Raw Gemini API response:")
    app.logger.info(evaluation)

    if not evaluation or not evaluation.strip():
        app.logger.error("Received empty response from Gemini API")
        return jsonify({"error": "Empty response from evaluation service"}), 500

    # Parse the evaluation
    criteria = ['Relevance', 'Correctness', 'Clarity', 'Depth']
    scores = {}
    feedback = {}
    overall_score = 0

    for criterion in criteria:
        score_pattern = rf"{criterion}: (\d+(?:\.\d+)?)"
        feedback_pattern = rf"{criterion} Feedback: (.*?)(?:\n|$)"
        
        score_match = re.search(score_pattern, evaluation)
        feedback_match = re.search(feedback_pattern, evaluation, re.DOTALL)
        
        if score_match and feedback_match:
            scores[criterion.lower()] = float(score_match.group(1))
            feedback[f"{criterion.lower()}_feedback"] = feedback_match.group(1).strip()

    overall_score_match = re.search(r"Overall Score: (\d+(?:\.\d+)?)", evaluation)
    if overall_score_match:
        overall_score = float(overall_score_match.group(1))
    else:
        overall_score = sum(scores.values()) / len(scores) if scores else 0

    result = {
        "question": question,
        "answer": answer,
        "overall_score": overall_score,
        "relevance": scores.get('relevance', 0),
        "correctness": scores.get('correctness', 0),
        "clarity": scores.get('clarity', 0),
        "depth": scores.get('depth', 0),
        "relevance_feedback": feedback.get('relevance_feedback', ''),
        "correctness_feedback": feedback.get('correctness_feedback', ''),
        "clarity_feedback": feedback.get('clarity_feedback', ''),
        "depth_feedback": feedback.get('depth_feedback', '')
    }

    app.logger.info("Parsed evaluation result:")
    app.logger.info(result)

    return jsonify(result)

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
