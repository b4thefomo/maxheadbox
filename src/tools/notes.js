import config from '../config.js';

const saveNoteName = 'save_note';
const getNotesName = 'get_notes';
const clearNotesName = 'clear_notes';

const saveNoteParams = 'noteText';
const getNotesParams = undefined;
const clearNotesParams = undefined;

const saveNoteDescription = 'save notes content on file.';
const getNotesDescription = 'get all notes previously saved on file.';
const clearNotesDescription = 'delete the content of all my notes from file.';

const saveNoteExecution = async (parameter) => {
  const formData = new URLSearchParams();
  formData.append('note', parameter);

  const noteResponse = await fetch(`${config.BACKEND_URL}/save-note`, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded"
    },
    body: formData.toString()
  });

  if (!noteResponse.ok) {
    throw new Error(`HTTP error! status: ${noteResponse.status}`);
  }

  const responseData = await noteResponse.json();
  return responseData.message;
};

const clearNotesExecution = async () => {
  const noteResponse = await fetch(`${config.BACKEND_URL}/clear-notes`, {
    method: "POST",
  });

  if (!noteResponse.ok) {
    throw new Error(`HTTP error! status: ${noteResponse.status}`);
  }

  const responseData = await noteResponse.json();
  return responseData.message;
};

const getNotesExecution = async () => {
  const notesResponse = await fetch(`${config.BACKEND_URL}/notes`, {
    method: "GET"
  });

  if (!notesResponse.ok) {
    throw new Error(`HTTP error! status: ${notesResponse.status}`);
  }

  const responseData = await notesResponse.json();
  return `Notes: "${responseData.text}"\n`;
};

export default [
  { name: saveNoteName, params: saveNoteParams, description: saveNoteDescription, execution: saveNoteExecution },
  { name: getNotesName, params: getNotesParams, description: getNotesDescription, execution: getNotesExecution },
  { name: clearNotesName, params: clearNotesParams, description: clearNotesDescription, execution: clearNotesExecution },
];