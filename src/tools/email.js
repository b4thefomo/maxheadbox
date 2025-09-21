import config from '../config.js';

const name = 'sendEmail';
const params = 'email_message';
const description = 'send an email to Simone containing a message';

const execution = async (parameter) => {
  const backendResponse = await fetch(`${config.BACKEND_URL}/email`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ message: parameter }),
  });

  if (!backendResponse.ok) {
    throw new Error(`HTTP error! status: ${backendResponse.status}`);
  }

  const responseContent = await backendResponse.json();
  const outputText = responseContent.message;

  return `Output: "${outputText}"`;
};


export default { name, params, description, execution };