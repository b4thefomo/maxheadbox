# WebSocket Manager module
# Helper for broadcasting events to connected WebSocket clients

module Core
  class WebSocketManager
    def initialize(sockets, logger)
      @sockets = sockets
      @logger = logger
    end

    def broadcast(event_data)
      return if @sockets.empty?

      message = event_data.to_json
      @sockets.each do |socket|
        begin
          socket.send(message)
        rescue StandardError => e
          @logger.error "[WebSocket] ❌ Error sending to client: #{e.message}"
        end
      end

      @logger.info "[WebSocket] 📤 Broadcast '#{event_data[:event]}' to #{@sockets.length} client(s)"
    end

    def send_to(socket, event_data)
      begin
        socket.send(event_data.to_json)
        @logger.info "[WebSocket] 📤 Sent '#{event_data[:event]}' to client"
      rescue StandardError => e
        @logger.error "[WebSocket] ❌ Error sending to client: #{e.message}"
      end
    end

    def client_count
      @sockets.length
    end

    def add_client(socket)
      @sockets << socket
      @logger.info "[WebSocket] ✅ Client connected (total: #{@sockets.length})"
    end

    def remove_client(socket)
      @sockets.delete(socket)
      @logger.info "[WebSocket] ⚠️  Client disconnected (remaining: #{@sockets.length})"
    end
  end
end
