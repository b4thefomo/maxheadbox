import config from '../config.js';

const name = 'get_fortune';
const params = undefined;
const description = 'execute fortune command in the CLI';

const execution = async () => {
  const fortuneResponse = await fetch(`${config.BACKEND_URL}/fortune`, {
    method: "GET"
  });

  if (!fortuneResponse.ok) {
    throw new Error(`HTTP error! status: ${fortuneResponse.status}`);
  }

  const fortune = await fortuneResponse.json();

  return `Fortune: '${fortune.text}'\n`;
};

export default { name, params, description, execution };