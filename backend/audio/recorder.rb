# Audio recording module
# Handles microphone recording with silence detection

require 'shell words'

module Audio
  class Recorder
    attr_reader :pid, :filepath

    def initialize(recordings_dir, logger)
      @recordings_dir = recordings_dir
      @logger = logger
      @pid = nil
      @filepath = nil
    end

    def recording?
      !!@pid
    end

    def start
      if recording?
        raise StandardError, 'Recording is already in progress.'
      end

      filename = 'recording.wav'
      @filepath = File.join(@recordings_dir, filename)

      # Add timeout to force stop after 10 seconds, with aggressive silence detection
      command = "timeout 10 sox -t alsa hw:0,0 -c 1 -r 16000 #{Shellwords.escape(@filepath)} gain 20 silence 1 0.3 2% 1 2.0 2%"

      @logger.info "[Recording] 🎤 Starting new recording..."
      @pid = Process.spawn(command)
      @logger.info "[Recording] ✅ Started (PID: #{@pid}) file: #{@filepath}"

      {
        message: 'Recording started.',
        filename: filename,
        filepath: @filepath,
        pid: @pid
      }
    end

    def stop
      unless recording?
        raise StandardError, 'No recording is currently in progress.'
      end

      begin
        # Send SIGINT (Ctrl+C) to gracefully stop the recording process
        Process.kill('INT', @pid)
        @logger.info "Sent SIGINT to PID #{@pid}."
        @pid = nil

        { message: 'Manual stop initiated.' }
      rescue Errno::ESRCH
        @logger.info "Process #{@pid} not found. It might have already finished or crashed."
        @pid = nil
        raise StandardError, 'Recording process already finished or not found.'
      end
    end

    def wait_for_completion(on_complete_callback)
      return unless @pid

      Thread.new do
        start_time = Time.now
        @logger.info "[Recording] Waiting for process #{@pid} to finish..."
        Process.wait(@pid)
        duration = (Time.now - start_time).round(2)
        file_size = File.exist?(@filepath) ? (File.size(@filepath) / 1024.0).round(1) : 0
        @logger.info "[Recording] ⏹️  Finished after #{duration}s, file size: #{file_size}KB"

        on_complete_callback.call(@filepath) if File.exist?(@filepath)

        @pid = nil
        @filepath = nil
      end
    end

    def test_record
      if recording?
        raise StandardError, 'Recording is already in progress.'
      end

      filename = 'test_recording.wav'
      filepath = File.join(@recordings_dir, filename)

      # Simple 5-second recording without silence detection, with volume boost
      command = "timeout 5 sox -t alsa hw:0,0 -c 1 -r 16000 #{Shellwords.escape(filepath)} gain 20"

      @logger.info "Starting test recording for 5 seconds..."
      pid = Process.spawn(command)
      @pid = pid
      @filepath = filepath

      # Wait for recording to finish
      Process.wait(pid)
      @pid = nil
      @logger.info "Test recording finished."

      {
        filepath: filepath,
        exists: File.exist?(filepath)
      }
    end

    def cleanup
      if @pid
        begin
          Process.kill('TERM', @pid)
          @logger.info "Stopped recording process #{@pid}."
        rescue Errno::ESRCH
          # Process already finished
        end
        @pid = nil
      end
    end
  end
end
