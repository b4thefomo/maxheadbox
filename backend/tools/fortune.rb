get '/fortune' do
  fortune_text = Open3.capture2('fortune')[0]

  return {
    text: fortune_text,
  }.to_json
rescue StandardError => e
  return { error: "Failed to get fortune command output: #{e.message}" }.to_json
end