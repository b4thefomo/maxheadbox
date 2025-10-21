import { useState, useEffect, useRef } from 'react';
import './App.css';

const BACKEND_URL = import.meta.env.VITE_BACKEND_URL || 'http://192.168.1.47:4567';
const WS_URL = import.meta.env.VITE_WEBSOCKET_URL || 'ws://192.168.1.47:4567';
const OLLAMA_URL = import.meta.env.VITE_OLLAMA_URL || 'http://192.168.1.47:11434';

function SimpleApp() {
  const [state, setState] = useState('idle'); // idle, recording, processing, speaking, error
  const [transcript, setTranscript] = useState('');
  const [response, setResponse] = useState('');
  const [error, setError] = useState('');
  const wsRef = useRef(null);

  // Connect WebSocket and auto-start recording
  useEffect(() => {
    console.log('[SimpleApp] Initializing WebSocket connection to:', WS_URL);
    const ws = new WebSocket(`${WS_URL}/ws`);

    ws.onopen = () => {
      console.log('[WebSocket] ✅ Connected successfully');
      // Auto-start recording after 2 seconds
      setTimeout(() => {
        console.log('[SimpleApp] Auto-starting first recording...');
        startRecording();
      }, 2000);
    };

    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      console.log('[WebSocket] 📨 Message received:', JSON.stringify(data));

      if (data.event === 'recording_finished') {
        const transcribedText = data.output?.trim() || '';
        console.log('[Transcription] Result:', transcribedText.length > 0 ? `"${transcribedText}"` : '(empty - silence detected)');
        setTranscript(transcribedText);

        // Only call LLM if we got actual text
        if (transcribedText.length > 0) {
          console.log('[Flow] Transcription detected → Calling LLM');
          setState('processing');
          getLLMResponse(transcribedText);
        } else {
          // No speech detected, restart recording immediately
          console.log('[Flow] No speech detected → Restarting recording in 1s');
          setState('idle');
          setTimeout(() => {
            startRecording();
          }, 1000);
        }
      } else if (data.event === 'recording_error') {
        console.error('[WebSocket] ❌ Recording error:', data.error);
        setError(data.error || 'Recording failed');
        setState('error');
        setTimeout(() => {
          setState('idle');
          startRecording();
        }, 3000);
      }
    };

    ws.onerror = (err) => {
      console.error('[WebSocket] ❌ Error:', err);
      setError('Connection error');
      setState('error');
    };

    ws.onclose = () => {
      console.warn('[WebSocket] ⚠️  Connection closed, reloading page in 3s...');
      setTimeout(() => window.location.reload(), 3000);
    };

    wsRef.current = ws;

    return () => ws.close();
  }, []);

  const startRecording = async () => {
    try {
      console.log('[Recording] 🎤 Starting new recording...');
      setState('recording');
      setTranscript('');
      setResponse('');
      setError('');

      const response = await fetch(`${BACKEND_URL}/start_recording`, {
        method: 'POST',
      });

      if (!response.ok) {
        throw new Error('Failed to start recording');
      }

      const data = await response.json();
      console.log('[Recording] ✅ Started successfully, file:', data.filepath);
    } catch (err) {
      console.error('[Recording] ❌ Error starting recording:', err);
      setError(err.message);
      setState('error');
    }
  };

  const getLLMResponse = async (text) => {
    try {
      console.log('[LLM] 💬 Calling Ollama with prompt:', text);
      setState('speaking');

      const startTime = Date.now();
      const response = await fetch(`${OLLAMA_URL}/api/generate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: 'gemma3:1b',
          prompt: `You are a helpful voice assistant. Answer this question concisely: ${text}`,
          stream: false,
        }),
      });

      if (!response.ok) {
        throw new Error('LLM request failed');
      }

      const data = await response.json();
      const elapsed = ((Date.now() - startTime) / 1000).toFixed(2);
      console.log(`[LLM] ✅ Response received in ${elapsed}s:`, data.response.substring(0, 100) + '...');
      setResponse(data.response);
      setState('idle');

      // Auto-start next recording after 5 seconds (give time to read response)
      console.log('[Flow] Waiting 5s before next recording...');
      setTimeout(() => {
        startRecording();
      }, 5000);
    } catch (err) {
      console.error('[LLM] ❌ Error getting response:', err);
      setError(err.message);
      setState('error');
      setTimeout(() => {
        setState('idle');
        startRecording();
      }, 3000);
    }
  };

  const handleTap = () => {
    if (state === 'idle' || state === 'error') {
      startRecording();
    }
  };

  const getStatusMessage = () => {
    switch (state) {
      case 'idle':
        return 'Ready - Speak now!';
      case 'recording':
        return 'Listening...';
      case 'processing':
        return 'Transcribing...';
      case 'speaking':
        return 'Thinking...';
      case 'error':
        return `Error: ${error}`;
      default:
        return 'Ready';
    }
  };

  return (
    <div className="simple-app" onClick={handleTap}>
      <div className="status-section">
        <div className="status-icon">
          {state === 'idle' && '😊'}
          {state === 'recording' && '🎤'}
          {state === 'processing' && '🤔'}
          {state === 'speaking' && '💬'}
          {state === 'error' && '❌'}
        </div>
        <div className="status-message">{getStatusMessage()}</div>
      </div>

      {transcript && (
        <div className="transcript-section">
          <div className="label">You said:</div>
          <div className="text">{transcript}</div>
        </div>
      )}

      {response && (
        <div className="response-section">
          <div className="label">Response:</div>
          <div className="text">{response}</div>
        </div>
      )}
    </div>
  );
}

export default SimpleApp;
