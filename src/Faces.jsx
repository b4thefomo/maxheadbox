import { Component } from 'react';
import './Faces.css';

const faceImages = import.meta.glob('./assets/faces/*.png', { eager: true, import: 'default' });

const faceMap = {
  love: [
    ['check1', 200],
    ['check2', 200],
    ['check1', 200],
    ['check2', 200],
    ['check1', 200],
    ['check2', 200],
    ['check1', 200],
    ['check2', 200],
    ['check1', 200],
    ['check2', 200],
    ['check1', 200],
    ['check2', 200],
    ['smile_eyes_opened', 400],
    ['smile_eyes_blue', 100],
    ['smile_eyes_pink', 100],
    ['smile_eyes_blue', 100],
    ['smile_eyes_pink', 100],
    ['smile_eyes_blue', 100],
    ['smile_eyes_opened', 400],
    ['smile_eyes_blue', 100],
    ['smile_eyes_pink', 100],
    ['smile_eyes_blue', 100],
    ['smile_eyes_pink', 100],
    ['smile_eyes_blue', 100],
    ['smile_eyes_opened', 400],
    ['smile_eyes_blue', 100],
    ['smile_eyes_pink', 100],
    ['smile_eyes_blue', 100],
    ['smile_eyes_pink', 100],
    ['smile_eyes_blue', 100],
    ['hg-1', 100],
    ['hg-2', 100],
    ['hg-3', 100],
    ['hg-4', 100],
    ['hg-5', 100],
    ['hg-6', 100],
    ['hg-7', 100],
    ['hg-8', 100],
    ['hg-9', 100],
    ['hg-1', 100],
    ['hg-2', 100],
    ['hg-3', 100],
    ['hg-4', 100],
    ['hg-5', 100],
    ['hg-6', 100],
    ['hg-7', 100],
    ['hg-8', 100],
    ['hg-9', 100],
    ['hg-1', 100],
    ['hg-2', 100],
    ['hg-3', 100],
    ['hg-4', 100],
    ['hg-5', 100],
    ['hg-6', 100],
    ['hg-7', 100],
    ['hg-8', 100],
    ['hg-9', 100],
    ['hg-1', 100],
    ['hg-2', 100],
    ['hg-3', 500],
  ],
  reading: [
    ['face_monocle_closed', 150],
    ['face_monocle', 150],
    ['face_monocle_closed', 150],
    ['face_monocle', 150],
    ['face_monocle_closed', 150],
    ['face_monocle', 2000],
  ],
  idle: [
    ['smile_eyes_closed', 100],
    ['smile_eyes_opened', 4000],
    ['smile_eyes_closed', 100],
    ['smile_eyes_opened', 3000],
    ['smile_eyes_closed', 100],
    ['smile_eyes_opened', 100],
    ['smile_eyes_closed', 100],
    ['smile_eyes_opened', 6000],
    ['smile_eyes_closed', 100],
    ['smile_eyes_opened', 100],
    ['smile_eyes_opened', 8000],
  ],
  thinking: [
    ['face_look_left', 200],
    ['face_look_right', 200],
    ['face_look_left', 200],
    ['face_look_right', 200],
    ['face_look_left', 200],
    ['face_look_right', 200],
    ['face_thinking', 1000],
    ['face_weird', 1000],
    ['face_thinking', 1000],
  ],
  dead: [
    ['dead', 1000],
  ],
  sleepy: [
    ['sleep_open', 1000],
    ['sleep_closed', 1000],
  ]
};

class Faces extends Component {
  constructor(props) {
    super(props);

    const { face } = this.props;

    this.state = {
      currentFrame: face,
      frameIndex: 0,
    };

    this.animationTimeout = undefined;
  }

  componentDidMount() {
    this.setupTimeout();
  }

  componentDidUpdate(prevProps) {
    if (prevProps.face !== this.props.face) {
      clearTimeout(this.animationTimeout);

      this.setState({
        currentFrame: this.props.face,
        frameIndex: 0,
      });
    } else {
      this.setupTimeout();
    }
  }

  setupTimeout() {
    if (this.animationTimeout) {
      clearTimeout(this.animationTimeout);
    }

    const { currentFrame, frameIndex } = this.state;
    const duration = faceMap[currentFrame][frameIndex][1];

    this.animationTimeout = setTimeout(() => {
      this.setState({ frameIndex: (frameIndex + 1) % faceMap[currentFrame].length });
    }, duration);
  }

  componentWillUnmount() {
    if (this.animationTimeout) {
      clearTimeout(this.animationTimeout);
    }
  }

  render() {
    const { currentFrame, frameIndex } = this.state;

    const finalImage = faceMap[currentFrame][frameIndex][0];

    const imageSrc = finalImage
      ? faceImages[`./assets/faces/${finalImage}.png`]
      : null;

    return (
      <div className={`faces-container`}>
        <span className='face-float-animation'>
          <img className='face-filter-hue' src={imageSrc} alt={currentFrame} />
        </span>
      </div>
    );
  }
}

export default Faces;