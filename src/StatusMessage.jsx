import './StatusMessage.css';

function StatusMessage({ message }) {
  return (
    <div className='status-message-container'>
      <span className={`status-message-text`}>{message}</span>
    </div>
  );
}

export default StatusMessage;