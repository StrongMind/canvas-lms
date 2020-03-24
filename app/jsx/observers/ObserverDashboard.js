import React from 'react'
import styled from 'styled-components'
import ObserveeCard from './ObserveeCard'

const CardWrapper = styled.div`
  max-width: 32%;
  width: 100%;
  margin-right: 10px;

  &:nth-of-type(3n) {
    margin-right: 0;
  }
`

const Dashboard = styled.div`
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
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
