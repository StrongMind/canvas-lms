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
      previous: collection.urls.previous,
      next: collection.urls.next,
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
      next: links.next
    })
  }

  renderUsers() {
    return this.state.users.map(user => {
      return (
        <p>{(user.attributes || user).name}</p>
      )
    });
  }

  render() {
    return (
      <Card>
        {this.renderUsers()}
        <footer>
          <Previous onClick={this.clickPrevious.bind(this)}><a>Previous</a></Previous>
          <Next onClick={this.clickNext.bind(this)}><a>Next</a></Next>
        </footer>
      </Card>
    )
  }
}

export default AssignObservers
