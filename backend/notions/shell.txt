# careful with this one :)

require 'json'
require 'open3'

post '/shell' do
  request_payload = JSON.parse(request.body.read)
  command = request_payload['command']

  begin
    output, status = Open3.capture2(command)
  rescue StandardError => e
    output = "Shell Error: #{e}"
  end

  content_type :json
  { message: command }.to_json
end