import { Lexer } from 'streaming-json';
import systemPrompt from './systemPrompt';

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

function getTrailingDiff(str1, str2) {
  if (str2.startsWith(str1)) {
    return str2.substring(str1.length);
  }
  return str2;
}

const processStreamResponse = async (
  response,
  setResponseOnScreen,
  setReaction,
  changeUIState,
  addAggregatedResponseChunk,
  onFinishStream
) => {
  let uiStateChanged = false;
  let isEmotionDefined = false;
  let finishedMessageStream = false;
  let aggregatedMessage = '';

  const lexer = new Lexer();
  const feelings = systemPrompt?.conversation?.format?.properties?.feeling?.enum ?? [];

  for await (const part of response) {
    const newContent = part.message.content;
    addAggregatedResponseChunk(newContent);

    if (newContent) {
      lexer.AppendString(newContent);
    }

    const lexerOutput = JSON.parse(lexer.CompleteJSON());

    if ('message' in lexerOutput && lexerOutput.message) {
      if (!uiStateChanged) {
        changeUIState();
        uiStateChanged = true;
      }

      const diff = getTrailingDiff(aggregatedMessage, lexerOutput.message);
      if (diff) {
        aggregatedMessage = lexerOutput.message;
        setResponseOnScreen(prev => [...prev, diff]);
      }
    }

    if (!finishedMessageStream && Object.keys(lexerOutput).length > 1) {
      onFinishStream(aggregatedMessage);
      finishedMessageStream = true;
    }

    if (!isEmotionDefined && 'feeling' in lexerOutput && feelings.includes(lexerOutput.feeling)) {
      isEmotionDefined = true;
      setReaction(lexerOutput.feeling);

      break;
    }
  }

  // occasionally small models add garbage at the end like extra spaces
  // and /t characters that's why I break immediately after getting the feeling
  // and then close the JSON manually here to the last chunk
  addAggregatedResponseChunk('"}');
};

export default { toggleFullscreen, processStreamResponse, speak };
