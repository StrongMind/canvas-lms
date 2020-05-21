import React from 'react'
import styled from 'styled-components'
import axios from 'axios'
import parseLinkHeader from 'jsx/shared/helpers/parseLinkHeader'
import IcInput from 'jsx/account_course_user_search/IcInput'

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
  &:hover, &.active {
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
      users: [],
      first: collection.urls.first,
      previous: collection.urls.prev,
      next: collection.urls.next,
      current: collection.urls.current,
      observer: {},
      observees: [],
      currentObserversObservees: [],
      step: 1,
      searchTerm: '',
    }
  }
  
  static defaultProps = {
    users: [],
  };

  restart() {
    this.setState({
      observer: {},
      observees: [],
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

  filterUsers() {
    let observer_id = this.state.observer.id
    if (this.state.step === 1 || !observer_id) { return this.state.users }
    return this.state.users.filter(user => {
      return user.id !== observer_id && !this.state.currentObserversObservees.some(obs => obs.id === user.id)
    })
  }

  assign(user) {
    if (this.state.step === 2) {
      this.setState({observees: this.state.observees.concat(user)})
    } else {
      this.setState({observer: user})
    }
  }

  isActive(user) {
    return (user.id === this.state.observer.id || this.state.observees.some(obs => obs.id === user.id))
  }
  
  renderUsers() {
    return this.filterUsers().map(user => {
      let clsname = this.isActive(user) ? "active" : ""
      return (
        <ListUser className={clsname} onClick={(() => this.assign(user))}>{user.name}</ListUser>
      )
    });
  }

  incrementStep() {
    if (this.state.step === 1 && this.state.observer.id) {
      this.getCurrentObservees().then(() => {
        this.setState({step: this.state.step + 1})
      })
    } else {
      this.setState({step: this.state.step + 1})
    }
  }

  decrementStep() {
    this.setState({step: this.state.step - 1})
  }

  searchInput() {
    return (
      <IcInput type="search" placeholder="Enter the name of the user you would like to search."
        ref="userSearch" onKeyUp={e => this.filterBySearch(e.target.value)}></IcInput>
    )
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
        {this.searchInput()}
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
        <h1>Choose Observees for {this.state.observer.name}</h1>
        {this.searchInput()}
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

  filterBySearch(search_term) {
    this.state.searchTerm = search_term
    return axios.get(this.state.first + `&search_term=${this.state.searchTerm}&assign_observers=true`).then(response => {
      this.parseResponseLinks(response)
    })
  }
  
  getCurrentObservees() {
    return axios.get(`${ENV.BASE_URL}/api/v1/users/${this.state.observer.id}/observees`).then(response => {
      this.setState({currentObserversObservees: response.data})
    })
  }
  
  submitObserver() {
    let observer_id = this.state.observer.id
    if (!observer_id) { return false }
    axios.post(
      `${ENV.BASE_URL}/api/v1/users/${observer_id}/bulk_create_observees`,
      { observee_ids: this.state.observees.map(obs => obs.id) }
    ).then(response => {
      console.log(response)
    })
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
