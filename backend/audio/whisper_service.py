from fastapi import FastAPI
from pydantic import BaseModel
from faster_whisper import WhisperModel
import uvicorn
import json
import os

app = FastAPI()
# Upgraded to base.en for better accuracy (tiny.en was too aggressive)
model = WhisperModel("base.en", compute_type="int8")

class TranscriptionRequest(BaseModel):
    file_path: str

@app.get("/")
async def root():
    return {"message": "Whisper up and running!"}

@app.post("/transcribe")
async def transcribe(request_data: TranscriptionRequest):
    file_path = request_data.file_path
    
    if not os.path.exists(file_path):
        return {"error": f"File not found at path: {file_path}"}
    
    try:
        segments, _ = model.transcribe(
            file_path,
            word_timestamps=True,
            beam_size=5,
            best_of=5,
            vad_filter=True,
            vad_parameters={"min_silence_duration_ms": 500}
        )
        # Filter out hallucinated single-character segments
        data = [
            {"start": seg.start, "end": seg.end, "text": seg.text}
            for seg in segments
            if len(seg.text.strip()) > 1  # Skip ".", " ", etc.
        ]
        return data
    except Exception as e:
        return {"error": f"Transcription failed: {str(e)}"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)