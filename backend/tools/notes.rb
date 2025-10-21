require 'json'

NOTES_FILE = File.expand_path('~/Desktop/notes.txt').freeze

post '/save-note' do
  note_text = params['note']

  dir = File.dirname(NOTES_FILE)
  Dir.mkdir(dir) unless Dir.exist?(dir)

  File.open(NOTES_FILE, 'a+') do |file|
    file.puts(note_text + "\n")
  end

  return { message: 'successfully saved the note!' }.to_json
end

post '/clear-notes' do
  dir = File.dirname(NOTES_FILE)
  Dir.mkdir(dir) unless Dir.exist?(dir)

  File.truncate(NOTES_FILE, 0);

  return { message: 'Successfully cleared all notes!' }.to_json
end

get '/notes' do
  File.write(NOTES_FILE, '') unless File.exist?(NOTES_FILE)

  notes = File.read(NOTES_FILE)
  return notes.empty? ? { text: 'No notes found.' }.to_json : { text: notes }.to_json
rescue StandardError => e
  return { error: "Failed to retrieve notes: #{e.message}" }.to_json
end
