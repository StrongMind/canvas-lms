import React from 'react'
import styled from 'styled-components'
import axios from 'axios'
import parseLinkHeader from 'jsx/shared/helpers/parseLinkHeader'

const Card = styled.div`
  border: 1px solid #D7D7D7;
  border-radius: 4px;
  box-shadow: 0 2px 5px rgba(0,0,0,0.3);
  text-align: center;
  min-height: 360px;
  height: 100%;
  width: 100%;
  position: relative;
  overflow-x: hidden;
`

const ListUser = styled.p`
  &:hover {
    background: #00314C;
    cursor: pointer;
    color: #ffffff;
  }
`

const Previous = styled.span`
  float: left;
  cursor: pointer;
`

const Next = styled.span`
  float: right;
  cursor: pointer;
`

class AssignObservers extends React.Component {
  constructor(props) {
    super(props);

    let collection = this.props.users;

    this.state = {
      users: collection.models,
      urls: collection.urls,
      previous: collection.urls.prev,
      next: collection.urls.next,
      current: collection.urls.current,
      observer: {},
      observees: [],
      step: 1,
    }
  }
  
  static defaultProps = {
    users: [],
  };

  clickPrevious() {
    if (this.state.previous) {
      axios.get(this.state.previous).then(response => {
        this.parseResponseLinks(response);
      })
    }
  }

  clickNext() {
    if (this.state.next) {
      axios.get(this.state.next).then(response => {
        this.parseResponseLinks(response);
      })
    }
  }

  parseResponseLinks(response) {
    let links = parseLinkHeader(response)

    this.setState({
      users: response.data,
      previous: links.prev,
      next: links.next,
      current: links.current,
    })
  }

  assign(user) {
    if (this.state.step === 2) {
      this.state.observees.push(user)
    } else {
      this.setState({observer: user})
    }

    setTimeout(() => { 
      console.log(this.state.observer);
      console.log(this.state.observees);
      }, 500 
    )
  }

  setName(user) {
    if (user.attributes) {
      return user.attributes.name
    } else {
      return user.name
    }
  }

  setObserverName() {
    return this.setName(this.state.observer)
  }

  renderUsers() {
    return this.state.users.map(user => {
      return (
        <ListUser onClick={(() => this.assign(user))}>{this.setName(user)}</ListUser>
      )
    });
  }

  incrementStep() {
    this.setState({step: this.state.step + 1})
    setTimeout(() => { console.log(this.state.step), 500 })
  }

  chooseStep() {
    switch (this.state.step) {
      case 1:
        return this.stepOne()
      case 2:
        return this.stepTwo()
      case 3:
        return this.stepThree()
      default:
        return this.stepOne()
    }
  }
  
  stepOne() {
    return (
      <div>
        <h1>Choose an Observer</h1>
        {this.renderUsers()}
        <footer>
          <Previous onClick={this.clickPrevious.bind(this)}><a>Previous</a></Previous>
          <Next onClick={this.clickNext.bind(this)}><a>Next</a></Next>
        </footer>
      </div>
    )
  }

  stepTwo() {
    return (
      <div>
        <h1>Choose Observees for {this.setObserverName()}</h1>
        {this.renderUsers()}
        <footer>
          <Previous onClick={this.clickPrevious.bind(this)}><a>Previous</a></Previous>
          <Next onClick={this.clickNext.bind(this)}><a>Next</a></Next>
        </footer>
      </div>
    )
  }

  stepThree() {
    return (
      <div>
        <h1>Observer: {this.setObserverName()}</h1>
        <div>
          <h3>Observees:</h3>
          {this.state.observees.map(obs => {
            return (<p>{this.setName(obs)}</p>)
          })}
        </div>
        <button className="btn btn-block">Set Observer</button>
      </div>
    )
  }
  
  render() {
    return (
      <div>
        <Card>
          {this.chooseStep()}
        </Card>
        <button className="btn btn-block btn-primary" onClick={this.incrementStep.bind(this)}>Next Step</button>
      </div>
    )
  }
}

export default AssignObservers
