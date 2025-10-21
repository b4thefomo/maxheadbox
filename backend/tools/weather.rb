# heavily vibe-coded because I needed something fast that worked!

require 'sinatra'
require 'net/http'
require 'uri'
require 'json'

def fetch_json(url)
  uri = URI.parse(url)
  response = Net::HTTP.get_response(uri)

  unless response.is_a?(Net::HTTPSuccess)
    puts "Error: HTTP request failed with code #{response.code}"
    return nil
  end

  JSON.parse(response.body)
rescue JSON::ParserError => e
  puts "Error parsing JSON response: #{e.message}"
  nil
rescue StandardError => e
  puts "An error occurred during HTTP request: #{e.message}"
  nil
end

get '/weather/:city' do
  content_type :json

  city_name = URI.encode_www_form_component(params[:city])

  geocoding_url = "https://geocoding-api.open-meteo.com/v1/search?name=#{city_name}"
  location_data = fetch_json(geocoding_url)

  unless location_data && location_data['results'] && !location_data['results'].empty?
    status 404
    return { error: "City '#{params[:city]}' not found." }.to_json
  end

  latitude = location_data['results'][0]['latitude']
  longitude = location_data['results'][0]['longitude']
  display_city = location_data['results'][0]['name']

  weather_forecast_url = "https://api.open-meteo.com/v1/forecast?latitude=#{latitude}&longitude=#{longitude}&current=temperature_2m,weather_code,wind_speed_10m,relative_humidity_2m,apparent_temperature,is_day&temperature_unit=celsius&wind_speed_unit=kmh&timezone=auto"
  weather_data = fetch_json(weather_forecast_url)

  unless weather_data && weather_data['current']
    status 500
    return { error: "Could not retrieve weather for '#{display_city}'." }.to_json
  end

  current_weather = weather_data['current']
  temperature = current_weather['temperature_2m']
  apparent_temperature = current_weather['apparent_temperature']
  wind_speed = current_weather['wind_speed_10m']
  relative_humidity = current_weather['relative_humidity_2m']
  is_day = current_weather['is_day'] == 1 ? 'Yes' : 'No'
  weather_code = current_weather['weather_code']
  weather_description = case weather_code
                        when 0 then 'Clear sky'
                        when 1, 2, 3 then 'Mainly clear, partly cloudy, or overcast'
                        when 45, 48 then 'Fog and depositing rime fog'
                        when 51, 53, 55 then 'Drizzle: Light, moderate, and dense intensity'
                        when 56, 57 then 'Freezing Drizzle: Light and dense intensity'
                        when 61, 63, 65 then 'Rain: Slight, moderate and heavy intensity'
                        when 66, 67 then 'Freezing Rain: Light and heavy intensity'
                        when 71, 73, 75 then 'Snow fall: Slight, moderate, and heavy intensity'
                        when 77 then 'Snow grains'
                        when 80, 81, 82 then 'Rain showers: Slight, moderate, and violent'
                        when 85, 86 then 'Snow showers slight and heavy'
                        when 95 then 'Thunderstorm: Slight or moderate'
                        when 96, 99 then 'Thunderstorm with slight and heavy hail'
                        else 'Unknown'
                        end

  recap_string = <<~WEATHER_STRING
    City: #{display_city}
    Temperature: #{temperature}°C
    Feels Like: #{apparent_temperature}°C
    Description: #{weather_description}
    Wind Speed: #{wind_speed} km/h
    Humidity: #{relative_humidity}%
    Is Day: #{is_day}
  WEATHER_STRING

  {
    weather: recap_string.strip
  }.to_json
end
