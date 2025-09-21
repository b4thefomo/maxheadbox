import config from '../config.js';

const name = 'timenow';
const params = undefined;
const description = 'return the current date and time';

const execution = async () => {
  const backendResponse = await fetch(`${config.BACKEND_URL}/sysinfo`, {
    method: "GET"
  });

  if (!backendResponse.ok) {
    throw new Error(`HTTP error! status: ${backendResponse.status}`);
  }

  const sysInfoData = await backendResponse.json();
  const timeNow = sysInfoData.date_time;

  return `Here is the Date and current time: ${timeNow}`;
};

export default { name, params, description, execution };