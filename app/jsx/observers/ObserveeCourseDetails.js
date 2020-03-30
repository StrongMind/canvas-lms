import React from 'react'
import styled from 'styled-components'

const Card = styled.div`
  border: 1px solid red;
  z-index: 2;
  background: yellow;
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
    course_details: {}
  };

  render() {
    return (
      <Card>I'm loving it. {this.props.enrollment.id}</Card>
    )
  }
}

export default ObserveeCourseDetails