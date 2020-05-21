import React from 'react'
import styled from 'styled-components'
import axios from 'axios'
import parseLinkHeader from 'jsx/shared/helpers/parseLinkHeader'
import IcInput from 'jsx/account_course_user_search/IcInput'
import IconUserSolid from 'instructure-icons/lib/Solid/IconUserSolid'
import IconGroupSolid from 'instructure-icons/lib/Solid/IconGroupSolid'
import IconCheckSolid from 'instructure-icons/lib/Solid/IconCheckSolid'
import IconEndSolid from 'instructure-icons/lib/Solid/IconEndSolid'

const Card = styled.div`
  border: 1px solid #D7D7D7;
  border-radius: 4px;
  box-shadow: 0 2px 5px rgba(0,0,0,0.3);
  text-align: center;
  height: 100%;
  width: 100%;
  max-width: 760px;
  position: relative;
  overflow-x: hidden;

  h3 {
    font-family: 'Open Sans', sans-serif;
    font-weight: 600;
    letter-spacing: 0.2px;
  }

  fieldset {
    min-width: 50%;
  }

  label {
    font-family: 'Open Sans', sans-serif;
    font-size: 12px;
    margin-right: 10px;
  }

  .card-content {
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 2rem;
  }

  .descriptive-text {
    color: #5e5e5e;
    font-size: 12px;
    font-style: italic;
    font-family: 'Open Sans', sans-serif;
    margin-top: 0;
  }

  .ic-Form-control {
    display: inline-block;
    width: 70%;
  }
`

const Step = styled.div`
  display: flex;
  align-items: center;
  justify-content: center;
  height: 32px;
  width: 32px;
  background: #5CA0C6;
  border-radius: 100%;

  &.active-step {
    background: #006ba6;
  }

  > * {
    color: #ffffff;
    font-size: 16px;
  }
`

const Icon = styled.div`
  display: flex;
  align-items: center;
  justify-content: center;
  height: 48px;
  width: 48px;
  background: #006ba6;
  border-radius: 100%;
  margin-bottom: 0.5rem;

  > * {
    color: #ffffff;
    font-size: 24px;
  }
`

const Pill = styled.div`
  background: #006ba6;
  display: flex;
  align-items: center;
  padding: 0.25rem 0.5rem;
  border-radius: 25px;

  > * {
    color: #ffffff;
  }
  
  p {
    font-family: 'Open Sans', sans-serif;
    font-size: 12px;
    font-weight: 600;
    margin-right: 10px;
    margin-top: 0;
    margin-bottom: 0;
  }

  svg {
    font-size: 10px;
  }
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
  &.btn-block:not(.start-over-button) {
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
      observeesToAdd: [],
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
      observeesToAdd: [],
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
      this.setState({observeesToAdd: this.state.observeesToAdd.concat(user)})
    } else {
      this.setState({observer: user})
    }
  }

  isActive(user) {
    if (this.state.step === 1) {
      return user.id === this.state.observer.id 
    } else if (this.state.step === 2) {
      return this.state.observeesToAdd.some(obs => obs.id === user.id)
    }
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
      <fieldset>
        <label>Find a user:</label>
        <IcInput type="search" placeholder="Search"
          ref="userSearch" onKeyUp={e => this.filterBySearch(e.target.value)}></IcInput>
      </fieldset>
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
      case 4:
        return this.stepFour()
      default:
        return this.stepOne()
    }
  }
  
  stepOne() {
    return (
      <div className="card-content">
        <Icon>
          <IconUserSolid/>
        </Icon>
        <h3>Choose an Observer</h3>
        <p className="descriptive-text">This is the person that will be observing multiple students at one time.</p>
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
      <div className="card-content">
        <Icon>
          <IconGroupSolid/>
        </Icon>
        <h3>Choose Observees for {this.state.observer.name}</h3>
        {this.state.observeesToAdd.map(obs => {
          return (
            <Pill>
              <p>{obs.name}</p>
              <IconEndSolid/>
            </Pill>
          )
        })}
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
      <div className="card-content">
        <Icon>
          <IconCheckSolid/>
        </Icon>
        <div>
          <h1>Observer:</h1>
          <h5>{this.state.observer.name}</h5>
        </div>
        <div>
          <h3>Observees:</h3>
          {this.state.observeesToAdd.map(obs => {
            return (<p>{obs.name}</p>)
          })}
        </div>
      </div>
    )
  }

  stepFour() {
    return (
      <div>
        <div>
          <h2>Congratulations! You assigned {this.state.observeesToAdd.length} observees to {this.state.observer.name}.</h2>
        </div>
      </div>
    )
  }

  setPreviousStepButton() {
    if (this.state.step === 4) {
      return (
        <Button className="btn btn-block start-over-button btn-primary" onClick={this.restart.bind(this)}>Start Over</Button>
      )
    } else {
      return (
        <Button className="btn btn-block btn-secondary" onClick={this.decrementStep.bind(this)} disabled={this.state.step === 1}>Prev Step</Button>
      )
    }
  }
  
  setNextStepButton() {
    if (this.state.step === 4) {
      return
    } else if (this.state.step === 3) {
      return (
        <Button className="btn btn-block btn-primary" onClick={this.submitObserver.bind(this)}>Submit</Button>
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
      { observee_ids: this.state.observeesToAdd.map(obs => obs.id) }
    ).then(response => {
      this.setState({step: 4})
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
