const name = 'calc_sum';
const params = "a, b";
const description = 'calculate the sum of two numbers e.g. calc_sum(1, 2)';

const execution = async (_backend_url, params) => {
  return params.split(",").reduce((acc, num) => acc + Number(num), 0);
};

export default { name, params, description, execution };