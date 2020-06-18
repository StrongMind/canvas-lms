import React from 'react';
import Griddle from 'griddle-react';

const data = [
  {
    "id": 0,
    "name": "Mayer Leonard",
    "city": "Kapowsin",
    "state": "Hawaii",
    "country": "United Kingdom",
    "company": "Ovolo",
    "favoriteNumber": 7
  },
  {
    "id": 1,
    "name": "Koch Becker",
    "city": "Johnsonburg",
    "state": "New Jersey",
    "country": "Madagascar",
    "company": "Eventage",
    "favoriteNumber": 2
  },
]

class CSAlerts extends React.Component {
  constructor(props) {
    super(props);

    let alerts = this.props.alerts;

    this.state = {
      alerts: alerts,
      bulk_checks: false,
      all_checked: false,
      loading: false,
    }
  }

  render() {
    return (
      <div>
        <Griddle data={this.state.alerts} />
      </div>
    )
  }
}

export default CSAlerts;