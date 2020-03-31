import React from 'react'
import styled from 'styled-components'

const Card = styled.div`
  box-sizing: border-box;
  background: #f5f5f6;
  color: #212329;
  z-index: 2;
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  overflow-y: scroll;

  .course-title {
    padding: 0.5rem;
    display: flex;
    align-items: center;
    justify-content: flex-start;
    border-bottom: 5px solid ${props => props.course_color};

    h4 {
      font-weight: bold;
      font-size: 18px;
      flex-grow: 1;
      padding: 0 0.5rem;
      width: 100%;
    }

    i {
      &:before {
        color: #212329;
        font-size: 14px;
      }
    }
  }

  p {
    text-align: center;
  }

  span {
    font-size: 12px;
    
    &.title {
      font-weight: bold;
    }
  }

  .course-teachers {
    color: #696969;
    font-style: italic;
    font-weight: bold;
    
    span {
      font-weight: normal;
    }
  }

  .course-score {
    font-family: "Montserrat", sans-serif; 
    font-size: 30px;
    font-weight: bold;
    color: #006ba6;
  }

  .submission-date, .last-active {
    span {
      display: block;
    }
  }
`

class ObserveeCourseDetails extends React.Component {
  constructor(props) {
    super(props);
  }

  static defaultProps = {
    enrollment: {},
    color: "",
    score: "",
    course_details: {}
  };

  render() {
    return (
      <Card course_color={this.props.color}>
        <div className="course-title">
          <a className="back-button" href="#" onClick={this.props.reset_action}>
            <i className="icon-arrow-open-left"></i>
          </a>
          <h4>{this.props.enrollment.course_name}</h4>
        </div>
        <p className="course-teachers">
          <span className="title">Teachers: </span>
          {this.props.course_details.teachers.join()}
        </p>
        <p className="course-score">{this.props.score}</p>
        <p className="submission-date">
          <span className="title">Date of last submission:</span>
          <span>{this.props.course_details.last_submission}</span>
        </p>
        <p className="last-active">
          <span className="title">Days since last active:</span>
          <span>{this.props.course_details.last_active}</span>
        </p>
      </Card>
    )
  }
}

export default ObserveeCourseDetails