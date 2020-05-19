import React from 'react'
import styled from 'styled-components'

class AssignObservers extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      users: this.props.users,
    }
  }
  
  static defaultProps = {
    users: [],
  };

  render() {
    return (
      <h1>I AM A REACT COMPONENT DURR</h1>
    )
  }
}

export default AssignObservers
