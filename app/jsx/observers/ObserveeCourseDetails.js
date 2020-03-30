import React from 'react'
import styled from 'styled-components'

const Card = styled.div`
  box-sizing: border-box;
  background: #f5f5f6;
  z-index: 2;
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;

  .course-title {
    padding: 0.5rem;
    display: flex;
    align-items: center;
    justify-content: flex-start;
    border-bottom: 5px solid ${props => props.course_color};

    h4 {
      font-weight: bold;
      font-size: 16px;
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

    p {
      text-align: center;
    }

    span {
      font-size: 12px;
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
        <p>Teachers:</p>
        {
          this.props.course_details.teachers.map(teacher => {
            return <span>{teacher}</span>
          })
        }
      </Card>
    )
  }
}

export default ObserveeCourseDetails