import { Lexer } from 'streaming-json';
import get from 'lodash/get';
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
  onFinishStream
) => {
  let uiStateChanged = false;
  let isEmotionDefined = false;
  let aggregatedMessage = '';

  const lexer = new Lexer();
  const feelings = get(systemPrompt, 'conversation.format.properties.feeling.enum', []);

  for await (const part of response) {
    if (part?.message?.content) {
      lexer.AppendString(part.message.content);
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

    if (!isEmotionDefined && 'feeling' in lexerOutput && feelings.includes(lexerOutput.feeling)) {
      isEmotionDefined = true;
      setReaction(lexerOutput.feeling);

      break;
    }
  }

  onFinishStream(aggregatedMessage);
};

export default { toggleFullscreen, processStreamResponse, speak };
