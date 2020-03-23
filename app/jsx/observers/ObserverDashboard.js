import React from 'react'
import styled from 'styled-components'
import ObserveeCard from './ObserveeCard'

const Dashboard = styled.div`
  display: flex;
`

class ObserverDashboard extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      observees: this.props.observees.models,
    }
  }
  
  static defaultProps = {
    observees: [],
  };

  renderObserveeCards() {
    if (!this.state.observees) { return }
    return this.state.observees.map((student, i) => { 
      return (<ObserveeCard key={i} student={student} />) 
    })
  }

  render() {
    return (
      <Dashboard>
        {this.renderObserveeCards()}
      </Dashboard>
    )
  }
}

export default ObserverDashboard
