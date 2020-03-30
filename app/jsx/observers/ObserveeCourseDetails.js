import React from 'react'
import styled from 'styled-components'

const Card = styled.div`
  border: 1px solid red;
  z-index: 2;
  background: ${props => props.background};
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
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
      <Card background={this.props.color}>I'm loving it. {this.props.enrollment.id}
        <br />
        <a className="back-button" href="#" onClick={this.props.reset_action}>Back</a>
        <p>{this.props.course_details.last_active}</p>
      </Card>
    )
  }
}

export default ObserveeCourseDetails