const name = 'restart_max';
const params = undefined;
const description = 'performs a restart the entire Max system and refresh the app';

const execution = async () => { location.reload(); };

export default { name, params, description, execution };