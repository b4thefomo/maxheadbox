import sounddevice as sd
import queue
import json
import requests
from vosk import Model, KaldiRecognizer
from dotenv import load_dotenv
import os

load_dotenv()
BACKEND_URL = os.getenv("VITE_BACKEND_URL")

MODEL_PATH = "assets/vosk-model-small-en-us-0.15"
WAKE_WORD = "max"

q = queue.Queue()

def callback(indata, frames, time, status):
    if status:
        print(status, flush=True)
    q.put(bytes(indata))

print("Loading model...")
model = Model(MODEL_PATH)
rec = KaldiRecognizer(model, 16000)
found_word = False

print(f"Listening for wake word: '{WAKE_WORD}'")

# Use device 0 with 48kHz (hardware rate) and manually downsample
# Vosk expects 16kHz, so we use blocksize=24000 for 48kHz (equivalent to 8000 at 16kHz)
import numpy as np
from scipy import signal

# Store original sample rate for resampling
DEVICE_SAMPLE_RATE = 48000
TARGET_SAMPLE_RATE = 16000
resample_ratio = TARGET_SAMPLE_RATE / DEVICE_SAMPLE_RATE

def resample_callback(indata, frames, time, status):
    if status:
        print(status, flush=True)
    # Resample from 48kHz to 16kHz
    audio_48k = np.frombuffer(indata, dtype=np.int16)
    audio_16k = signal.resample_poly(audio_48k, TARGET_SAMPLE_RATE, DEVICE_SAMPLE_RATE)
    q.put(audio_16k.astype(np.int16).tobytes())

with sd.RawInputStream(device=0, samplerate=DEVICE_SAMPLE_RATE, blocksize=24000, dtype='int16',
                       channels=1, callback=resample_callback):

    while not found_word:
        data = q.get()
        if rec.AcceptWaveform(data):
            result = json.loads(rec.Result())
            text = result.get("text", "")
            if WAKE_WORD in text.lower():
                print("Wake word detected!", flush=True)
                found_word = True
                try:
                    requests.post(f"{BACKEND_URL}/wake", json={"word": WAKE_WORD})
                except Exception as e:
                    print(f"Failed to notify backend: {e}", flush=True)
                break
