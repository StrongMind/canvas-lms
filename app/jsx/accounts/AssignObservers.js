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

const Button = styled.button`
  &.btn-block {
    width: 50%;
    display: inline-block;
  }
`

class AssignObservers extends React.Component {
  constructor(props) {
    super(props);

    let collection = this.props.users;

    this.state = {
      users: collection.models.map(model => model.attributes),
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

  restart() {
    this.setState({
      observer: {},
      observees: {},
      step: 1,
    })
  }

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

  filteredUsers() {
    let observer_id = this.state.observer.id
    if (!observer_id) { return this.state.users }
    return this.state.users.filter(user => user.id != observer_id)
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

  renderUsers(users) {
    return users.map(user => {
      return (
        <ListUser onClick={(() => this.assign(user))}>{user.name}</ListUser>
      )
    });
  }

  incrementStep() {
    this.setState({step: this.state.step + 1})
  }

  decrementStep() {
    this.setState({step: this.state.step - 1})
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
        {this.renderUsers(this.state.users)}
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
        <h1>Choose Observees for {this.state.observer.name}</h1>
        {this.renderUsers(this.filteredUsers())}
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
        <div>
          <h1>Observer:</h1>
          <h5>{this.state.observer.name}</h5>
        </div>
        <div>
          <h3>Observees:</h3>
          {this.state.observees.map(obs => {
            return (<p>{obs.name}</p>)
          })}
        </div>
      </div>
    )
  }

  setPreviousStepButton() {
    if (this.state.step === 3) {
      return (
        <Button className="btn btn-block btn-secondary" onClick={this.restart.bind(this)}>Start Over</Button>
      )
    } else {
      return (
        <Button className="btn btn-block btn-secondary" onClick={this.decrementStep.bind(this)} disabled={this.state.step === 1}>Prev Step</Button>
      )
    }
  }
  
  setNextStepButton() {
    if (this.state.step === 3) {
      return (
        <Button className="btn btn-block btn-primary" onClick={this.submitObserver.bind(this)}>Finish</Button>
      )
    } else {
      return (
        <Button className="btn btn-block btn-primary" onClick={this.incrementStep.bind(this)} disabled={!this.state.observer.id}>Next Step</Button>
      )
    }
  }

  submitObserver() {
    console.log("We Deed It!")
  }
  
  render() {
    return (
      <div>
        <Card>
          {this.chooseStep()}
        </Card>
       <div>
         {this.setPreviousStepButton()}
         {this.setNextStepButton()}
       </div>
      </div>
    )
  }
}

export default AssignObservers
