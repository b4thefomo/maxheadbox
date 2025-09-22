function speak(backendURL, text) {
  fetch(`${backendURL}/speak`, {
    method: 'POST',
    body: JSON.stringify({ content: text }),
  }).catch(err => {
    console.error('Error calling /speak:', err);
  });
}

const toggleFullscreen = () => {
  if (!document.fullscreenElement) {
    document.documentElement.requestFullscreen();
  } else {
    if (document.exitFullscreen) {
      document.exitFullscreen();
    }
  }
};

// I absolutely hate this I will rewrite it or use something else
const processStreamResponse = async (
  response,
  setResponseOnScreen,
  setReaction,
  changeUIState,
  addAggregatedResponseChunk,
  onFinishStream
) => {
  let jsonBuffer = '';
  let collectingMessage = false;
  let messageComplete = false;
  let uiStateChanged = false;
  let emotionSet = false;

  for await (const part of response) {
    const newContent = part.message.content;
    addAggregatedResponseChunk(newContent);
    jsonBuffer += newContent;

    if (!collectingMessage && !messageComplete) {
      const messageMatch = jsonBuffer.match(/"message"\s*:\s*"/);
      if (messageMatch) {
        collectingMessage = true;
        // Slice the buffer to start right after "message": "
        jsonBuffer = jsonBuffer.slice(messageMatch.index + messageMatch[0].length);
      }
    }

    if (collectingMessage) {
      let i = 0;
      while (i < jsonBuffer.length) {
        // Change the UI only once when the first character arrives
        if (!uiStateChanged) {
          changeUIState();
          uiStateChanged = true;
        }

        const char = jsonBuffer[i];

        // Check for the unescaped closing quote to end the message
        if (char === '"' && jsonBuffer[i - 1] !== '\\') {
          messageComplete = true;
          collectingMessage = false;
          i++; // Consume the final quote
          onFinishStream();
          break; // Exit the character loop for this chunk
        } else {
          // Stream the character to the UI
          setResponseOnScreen(prev => [...prev, char]);
        }
        i++;
      }
      // Trim the processed characters from the buffer
      jsonBuffer = jsonBuffer.slice(i);
    }

    if (messageComplete && !emotionSet) {
      const emotionMatch = jsonBuffer.match(/"feeling"\s*:\s*"([^"]+)"/);
      if (emotionMatch && emotionMatch[1]) {
        const emotion = emotionMatch[1];
        setReaction(emotion);
        emotionSet = true;
      }
    }
  }
};

export default { toggleFullscreen, processStreamResponse, speak };
