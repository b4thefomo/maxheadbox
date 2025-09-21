import config from '../config.js';

const name = 'get_weather';
const params = 'city';
const description = 'return the weather for a certain city.';

const execution = async (parameter) => {
  const city = parameter;
  const backendResponse = await fetch(`${config.BACKEND_URL}/weather/${city}`, {
    method: "GET"
  });

  if (!backendResponse.ok) {
    throw new Error(`HTTP error! status: ${backendResponse.status}`);
  }

  const weatherData = await backendResponse.json();
  const weather = weatherData.weather;

  return `Here is the weather data: ${weather}`;
};

export default { name, params, description, execution };