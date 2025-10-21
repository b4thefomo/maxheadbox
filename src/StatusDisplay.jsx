import './StatusDisplay.css';

const statusConfig = {
  idle: {
    emoji: '😊',
    text: 'Hey there!',
    color: '#4CAF50'
  },
  sleepy: {
    emoji: '😴',
    text: 'Resting...',
    color: '#9E9E9E'
  },
  dead: {
    emoji: '❌',
    text: 'Error',
    color: '#F44336'
  },
  reading: {
    emoji: '📖',
    text: 'Processing...',
    color: '#2196F3'
  },
  love: {
    emoji: '❤️',
    text: 'Got it!',
    color: '#E91E63'
  },
  thinking: {
    emoji: '🤔',
    text: 'Thinking...',
    color: '#FF9800'
  },
  recording: {
    emoji: '🎤',
    text: 'Listening...',
    color: '#F44336'
  },
  speaking: {
    emoji: '💬',
    text: 'Speaking...',
    color: '#4CAF50'
  }
};

function StatusDisplay({ status = 'idle' }) {
  const config = statusConfig[status] || statusConfig.idle;

  return (
    <div className="status-display">
      <div className="status-emoji" style={{ color: config.color }}>
        {config.emoji}
      </div>
      <div className="status-text" style={{ color: config.color }}>
        {config.text}
      </div>
    </div>
  );
}

export default StatusDisplay;
