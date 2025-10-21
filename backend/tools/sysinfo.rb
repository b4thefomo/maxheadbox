get '/sysinfo' do
  date_time = Time.now.strftime('%Y-%m-%d %H:%M:%S')
  cpu_temp_out, status = Open3.capture2('vcgencmd measure_temp')
  cpu_temperature = status.success? ? cpu_temp_out.match(/[0-9.]+/)[0] : 'N/A'

  uptime_out, status = Open3.capture2('uptime')
  uptime = status.success? ? uptime_out.strip : 'N/A'

  return {
    date_time: date_time,
    cpu_temperature: cpu_temperature,
    uptime: uptime
  }.to_json
rescue StandardError => e
  return { error: "Failed to get system info: #{e.message}" }.to_json
end