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
GODOT_IP = "127.0.0.1"
SEND_PORT = 4242
RECEIVE_PORT = 4243
VOICE_NAME = "en-US-AnaNeural"

# --- GLOBAL STATE ---
is_ai_speaking = False 
is_user_typing = False 

# --- SETUP ---
if not GROQ_API_KEY:
    print("CRITICAL: GROQ_API_KEY missing in .env")

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
print(f"--- LIA AUDIO SERVER (Robust v2) ---")

# --- PLAYBACK ---
def play_audio_cross_platform(file_path):
    if IS_WINDOWS:
        try:
            from pydub import AudioSegment
            from pydub.playback import play
            audio = AudioSegment.from_file(file_path)
            play(audio)
        except Exception as e:
            print(f"Windows Audio Error: {e}")
    else:
        try:
            subprocess.run(["ffplay", "-nodisp", "-autoexit", "-v", "0", file_path], check=True)
        except Exception as e:
            print(f"Linux Audio Error: {e}")

# --- TTS (THE MOUTH) ---
async def generate_and_play_tts(text):
    global is_ai_speaking
    
    # FILTER: Don't try to speak empty text or just dots
    if not text or text.strip() in [".", "...", "", "?", "!"]:
        return

    print(f"Lia: {text}")
    
    # 1. LOCK MIC
    is_ai_speaking = True 
    output_file = "lia_voice.mp3"
    
    try:
        communicate = edge_tts.Communicate(text, VOICE_NAME)
        await communicate.save(output_file)
        play_audio_cross_platform(output_file)
    except Exception as e:
        print(f"TTS Error: {e}")
    finally:
        # 2. UNLOCK MIC (Crucial: This runs even if Error happens!)
        is_ai_speaking = False 
        
        # Cleanup
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
                if text == "__SYS__PAUSE_MIC":
                    is_user_typing = True
                    print(">> Mic Paused (Typing)")
                elif text == "__SYS__RESUME_MIC":
                    is_user_typing = False
                    print(">> Mic Resumed")
                else:
                    asyncio.run(generate_and_play_tts(text))
        except Exception as e:
            print(f"TTS Loop Error: {e}")

# --- STT (THE EARS) ---
def transcribe_audio_groq(audio_data):
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
        if os.path.exists(temp_filename):
            os.remove(temp_filename)

PAUSE_THRESHOLD = 1.5 
# Increase this if it's deaf (100-300), Decrease if it hears static (1000+)
ENERGY_THRESHOLD = 300

def run_mic_listener():
    with sr.Microphone() as source:
        print("Calibrating Mic...")
        recognizer.adjust_for_ambient_noise(source, duration=1)
        recognizer.energy_threshold = ENERGY_THRESHOLD
        recognizer.pause_threshold = PAUSE_THRESHOLD
        recognizer.dynamic_energy_threshold = True
        
        print(f"2. Listening! (Pause Threshold: {PAUSE_THRESHOLD}s)")
        
        while True:
            if is_ai_speaking or is_user_typing:
                time.sleep(0.5)
                continue
            
            try:
                audio = recognizer.listen(source, timeout=1.0, phrase_time_limit=16.0)
                
                # Double check typing flag before processing (Save API calls)
                if is_user_typing: continue

                text = transcribe_audio_groq(audio)
                
                if text and text.strip() != "":
                    print(f"User Said: {text}")
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
            print(f"Restarting Main Loop: {e}")
