import React from 'react'
import styled from 'styled-components'
import ObserveeCard from './ObserveeCard'

const CardWrapper = styled.div`
  flex-basis: 33.33%;
  width: 100%;
  padding: 0.75rem;
  box-sizing: border-box;
  position: relative;
`

const Dashboard = styled.div`
  display: flex;
  flex-flow: row wrap;
  justify-content: flex-start;
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
      return (<CardWrapper><ObserveeCard key={i} student={student} /></CardWrapper>) 
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
