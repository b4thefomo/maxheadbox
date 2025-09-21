import config from '../config.js';

const name = 'get_cpu_temperature';
const params = undefined;
const description = 'return the temperature of the CPU';

const execution = async () => {
  const backendResponse = await fetch(`${config.BACKEND_URL}/sysinfo`, {
    method: "GET"
  });

  if (!backendResponse.ok) {
    throw new Error(`HTTP error! status: ${backendResponse.status}`);
  }

  const sysInfoData = await backendResponse.json();
  const cpuTemperature = sysInfoData.cpu_temperature;
  const uptime = sysInfoData.uptime;

  return `The CPU temperature is currently running at: ${cpuTemperature}. And uptime command result is: ${uptime}. Tell the user these exact values!`;
};

export default { name, params, description, execution };