import speech_recognition as sr
import socket
import threading
import asyncio
import edge_tts
import os
import sys
import platform
import subprocess # <--- NEW: For safe external playback

# --- CONFIG ---
GODOT_IP = "127.0.0.1"
SEND_PORT = 4242    # Python -> Godot (User Voice)
RECEIVE_PORT = 4243 # Godot -> Python (Lia Voice)
VOICE_NAME = "en-US-AnaNeural" 

# --- SETUP ---
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
receiver_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

try:
    receiver_sock.bind((GODOT_IP, RECEIVE_PORT))
except OSError:
    print(f"Error: Port {RECEIVE_PORT} is busy.")
    sys.exit(1)

recognizer = sr.Recognizer()
IS_WINDOWS = platform.system() == "Windows"
print(f"--- LIA AUDIO SERVER ({platform.system()}) ---")

# --- FUNCTION: ROBUST PLAYBACK (NO CRASHES) ---
def play_audio_cross_platform(file_path):
    if IS_WINDOWS:
        # Windows usually handles pydub fine, but we can use ffplay here too if needed
        try:
            from pydub import AudioSegment
            from pydub.playback import play
            audio = AudioSegment.from_file(file_path)
            play(audio)
        except Exception as e:
            print(f"Windows Audio Error: {e}")
    else:
        # LINUX FIX: Use external FFplay to prevent SegFaults
        # -nodisp: No window
        # -autoexit: Close after playing
        # -v 0: Silence log output
        try:
            subprocess.run(
                ["ffplay", "-nodisp", "-autoexit", "-v", "0", file_path],
                check=True
            )
        except Exception as e:
            print(f"Linux Audio Error: {e}")
            print("Make sure ffmpeg is installed: sudo pacman -S ffmpeg")

# --- FUNCTION: SPEAKING (TTS) ---
async def generate_and_play_tts(text):
    print(f"Lia: {text}")
    output_file = "lia_voice.mp3"
    
    try:
        communicate = edge_tts.Communicate(text, VOICE_NAME)
        await communicate.save(output_file)
        play_audio_cross_platform(output_file)
    except Exception as e:
        print(f"TTS Generation Error: {e}")
    
    # Cleanup
    if os.path.exists(output_file):
        try:
            os.remove(output_file)
        except:
            pass

def run_tts_listener():
    print(f"2. TTS Listening on port {RECEIVE_PORT}...")
    while True:
        try:
            data, addr = receiver_sock.recvfrom(8192)
            text = data.decode("utf-8")
            if text:
                asyncio.run(generate_and_play_tts(text))
        except Exception as e:
            print(f"TTS Loop Error: {e}")

# --- FUNCTION: LISTENING (STT) ---
def run_mic_listener():
    # Attempt to find default mic
    mic_index = None
            
    with sr.Microphone(device_index=mic_index) as source:
        print("1. Calibrating Mic (1s)...")
        recognizer.adjust_for_ambient_noise(source, duration=1)
        print("   -> Mic Ready! Speak now.")
        
        while True:
            try:
                audio = recognizer.listen(source, timeout=None, phrase_time_limit=None)
                # print("   -> Hearing...") # Commented out to reduce spam
                
                text = recognizer.recognize_google(audio)
                if text:
                    print(f"User: {text}")
                    sock.sendto(text.encode(), (GODOT_IP, SEND_PORT))
                    
            except sr.WaitTimeoutError:
                pass
            except sr.UnknownValueError:
                pass
            except Exception as e:
                print(f"Mic Error: {e}")
                break # Break to trigger restart in main loop

if __name__ == "__main__":
    # 1. Start TTS Thread
    tts_thread = threading.Thread(target=run_tts_listener)
    tts_thread.daemon = True
    tts_thread.start()

    # 2. Main Loop with Auto-Restart
    print("Lia Audio System: Online")
    
    while True:
        try:
            run_mic_listener()
        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"Restarting Mic Listener: {e}")
