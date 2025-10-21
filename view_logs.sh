#!/bin/bash
# Simple log viewer for Max Headbox

echo "==================================="
echo "📊 MAX HEADBOX LIVE LOGS"
echo "==================================="
echo ""

# Function to get Ruby backend logs via journalctl or ps
get_ruby_logs() {
    # Find the Ruby process and get its output
    RUBY_PID=$(pgrep -f "ruby server.rb" | head -1)
    if [ -n "$RUBY_PID" ]; then
        echo "📍 Ruby backend (PID: $RUBY_PID) - last 20 lines from stdout:"
        # Try to get logs from the process
        tail -20 /proc/$RUBY_PID/fd/1 2>/dev/null || echo "(stdout not available)"
    else
        echo "❌ Ruby backend not running"
    fi
}

echo "🔴 RUBY BACKEND LOGS (last 15 lines):"
echo "-----------------------------------"
ssh gbade@192.168.1.47 'pgrep -f "ruby server.rb" > /dev/null && journalctl -n 15 --no-pager -t ruby 2>/dev/null || ps aux | grep "[r]uby server.rb"'
echo ""

echo "🌐 BROWSER CONSOLE (Chromium remote debugging):"
echo "-----------------------------------"
echo "To view browser console logs, open on your Mac:"
echo "  chromium --remote-debugging-port=9222"
echo "  Then navigate to: chrome://inspect"
echo ""

echo "📝 RECORDING STATUS:"
echo "-----------------------------------"
ssh gbade@192.168.1.47 'ls -lth /dev/shm/whisper_recordings/ | head -3'
echo ""

echo "🔄 LIVE TAIL (press Ctrl+C to stop):"
echo "-----------------------------------"
echo "Monitoring Ruby backend output..."
ssh gbade@192.168.1.47 'tail -f /proc/$(pgrep -f "ruby server.rb" | head -1)/fd/1 2>/dev/null || echo "Cannot access Ruby process output. Backend may be redirecting to /dev/null"'
