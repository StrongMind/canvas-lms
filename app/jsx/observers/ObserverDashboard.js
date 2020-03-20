import React from 'react'
import ObserveeCard from './ObserveeCard'

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
      <div className="observer-dashboard">
        {this.renderObserveeCards()}
      </div>
    )
  }
}

export default ObserverDashboard
