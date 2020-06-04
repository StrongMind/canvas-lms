import React from 'react'
import styled from 'styled-components'
import ObserveeCard from './ObserveeCard'
import ObserverZeroState from './ObserverZeroState'
import axios from 'axios'

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
  margin: 0 -0.75rem;
`

class ObserverDashboard extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      observees: this.props.observees.models,
      showProgressGrades: ENV.show_progress_grades
    }
  }
  
  static defaultProps = {
    observees: [],
  };

  updateProgressGradeSetting() {
    let self = this
    let value = self.refs.showProgressGrades.checked
    console.log(self.refs.showProgressGrades.value)

    axios.post(
      `api/v1/users/${ENV.current_user.id}/toggle_progress_grade`,
      {show_progress_grades: value}
    ).then((response) => {
      console.log(response)
      self.setState({showProgressGrades: response.data.show_progress_grades})
    })
  }

  renderObserveeCards() {
    if (!this.state.observees.length) { return (<ObserverZeroState></ObserverZeroState>) }
    return this.state.observees.map((student, i) => { 
      return (<CardWrapper><ObserveeCard key={i} student={student} showProgressGrades={this.state.showProgressGrades} /></CardWrapper>) 
    })
  }

  render() {
    return (
      <Dashboard>
        <label>CLICK ME TO CHANGE GRADE SETTING</label>
        <input type="checkbox" checked={this.state.showProgressGrades}
          ref="showProgressGrades" onChange={this.updateProgressGradeSetting.bind(this)} />
        {this.renderObserveeCards()}
      </Dashboard>
    )
  }
}

export default ObserverDashboard
