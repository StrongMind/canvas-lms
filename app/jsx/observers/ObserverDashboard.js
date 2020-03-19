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
    return this.state.observees.map((student, i) => { 
      console.log("hello")
      return (<ObserveeCard key={i} student={student} />) 
    })
  }

  render() {
    console.log(this.props.observees.models)
    return (
      <div className="observer-dashboard">
        <p>HI EVERYONE</p>
        {this.renderObserveeCards()}
      </div>
    )
  }
}

export default ObserverDashboard
