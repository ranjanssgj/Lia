import os
import sys
import socket
import threading
import asyncio
import edge_tts
import platform
import subprocess
import tempfile
import time
import speech_recognition as sr
from groq import Groq
from dotenv import load_dotenv

# --- CONFIG ---
load_dotenv()
GROQ_API_KEY = os.getenv("GROQ_API_KEY")

if not GROQ_API_KEY:
    print("Error: GROQ_API_KEY not found in .env")
    # Fallback for testing if .env fails
    # GROQ_API_KEY = "gsk_..." 

GODOT_IP = "127.0.0.1"
SEND_PORT = 4242
RECEIVE_PORT = 4243
VOICE_NAME = "en-US-AnaNeural"

# --- GLOBAL STATE ---
is_ai_speaking = False
is_user_typing = False

# --- SETUP ---
client = Groq(api_key=GROQ_API_KEY)
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
receiver_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

try:
    receiver_sock.bind((GODOT_IP, RECEIVE_PORT))
except OSError:
    print(f"Error: Port {RECEIVE_PORT} is busy.")
    sys.exit(1)

recognizer = sr.Recognizer()
IS_WINDOWS = platform.system() == "Windows"
print(f"--- LIA AUDIO SERVER (Smart Pause Enabled) ---")

# --- PLAYBACK ---
def play_audio_cross_platform(file_path):
    if IS_WINDOWS:
        try:
            from pydub import AudioSegment
            from pydub.playback import play
            audio = AudioSegment.from_file(file_path)
            play(audio) # This blocks until audio finishes
        except Exception as e:
            print(f"Windows Audio Error: {e}")
    else:
        try:
            # Linux ffplay (blocks until finish)
            subprocess.run(["ffplay", "-nodisp", "-autoexit", "-v", "0", file_path], check=True)
        except Exception as e:
            print(f"Linux Audio Error: {e}")

# --- TTS (THE MOUTH) ---
async def generate_and_play_tts(text):
    global is_ai_speaking
    print(f"Lia: {text}")
    
    # 1. LOCK THE MIC
    is_ai_speaking = True 
    
    output_file = "lia_voice.mp3"
    try:
        communicate = edge_tts.Communicate(text, VOICE_NAME)
        await communicate.save(output_file)
        play_audio_cross_platform(output_file)
    except Exception as e:
        print(f"TTS Error: {e}")
    
    # 2. UNLOCK THE MIC
    is_ai_speaking = False 
    
    if os.path.exists(output_file):
        try: os.remove(output_file)
        except: pass

def run_tts_listener():
    global is_user_typing
    while True:
        try:
            data, addr = receiver_sock.recvfrom(8192)
            text = data.decode("utf-8")
            
            if text:
                # --- COMMAND HANDLING ---
                if text == "__SYS__PAUSE_MIC":
                    is_user_typing = True
                    print(">> Mic Paused (User is typing...)")
                    continue
                elif text == "__SYS__RESUME_MIC":
                    is_user_typing = False
                    print(">> Mic Resumed")
                    continue
                
                # --- NORMAL TTS ---
                asyncio.run(generate_and_play_tts(text))
                
        except Exception as e:
            print(f"TTS Loop Error: {e}")

# --- STT (THE EARS) ---
def transcribe_audio_groq(audio_data):
    # Save temp file for Groq
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as temp_wav:
        temp_wav.write(audio_data.get_wav_data())
        temp_filename = temp_wav.name

    try:
        with open(temp_filename, "rb") as file:
            transcription = client.audio.transcriptions.create(
                file=(temp_filename, file.read()),
                model="whisper-large-v3",
                response_format="json",
                language="en"
            )
        return transcription.text
    except Exception as e:
        print(f"Groq STT Error: {e}")
        return None
    finally:
        os.remove(temp_filename)

def run_mic_listener():
    with sr.Microphone() as source:
        print("Calibrating Mic...")
        recognizer.adjust_for_ambient_noise(source, duration=1)
        print("Lia is listening...")
        
        while True:
            # 1. STOP IF AI SPEAKING OR USER TYPING
            if is_ai_speaking or is_user_typing:
                time.sleep(0.5) 
                continue
            
            try:
                # 2. LISTEN (Short timeout to check flags frequently)
                audio = recognizer.listen(source, timeout=1.0, phrase_time_limit=15)
                
                print("Processing...")
                text = transcribe_audio_groq(audio)
                
                # Double check typing flag before sending (in case user started typing while processing)
                if is_user_typing: 
                    print("Ignored voice (User started typing)")
                    continue

                if text and text.strip() != "":
                    print(f"User: {text}")
                    sock.sendto(text.encode(), (GODOT_IP, SEND_PORT))
                    print("... (Cooldown 2s) ...")
                    time.sleep(2.0)
                    
            except sr.WaitTimeoutError:
                continue 
            except Exception as e:
                print(f"Mic Loop Error: {e}")

if __name__ == "__main__":
    tts_thread = threading.Thread(target=run_tts_listener)
    tts_thread.daemon = True
    tts_thread.start()
    
    while True:
        try:
            run_mic_listener()
        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"Restarting: {e}")
