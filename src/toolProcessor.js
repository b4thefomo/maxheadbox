const toolModules = import.meta.glob('./tools/*.js', { eager: true });

export const getToolsList = () => {
  return Object.values(toolModules).reduce((acc, module) => {
    if (Array.isArray(module.default)) {
      module.default.forEach(tool => {
        if (tool.name && tool.execution) {
          acc[tool.name] = {
            name: tool.name,
            execution: tool.execution,
            params: tool.params,
            description: tool.description
          };
        }
      });
    } else if (module.default?.name && module.default?.execution) {
      acc[module.default.name] = {
        name: module.default.name,
        execution: module.default.execution,
        params: module.default.params,
        description: module.default.description
      };
    }
    return acc;
  }, {});
};

export const processTool = async (tool) => {
  const parameter = tool.parameter || '';
  const functionName = tool.function || '';

  try {
    const toolsMap = getToolsList();
    const matchingTool = toolsMap[functionName];

    if (matchingTool) {
      const toolFunction = matchingTool.execution;
      const result = await toolFunction(parameter);
      return result;
    }

    return undefined;
  } catch (error) {
    console.error('Error handling request:', error);
    throw error;
  }
};
