import React from 'react'

class CSAlerts extends React.Component {
  constructor(props) {
    super(props);

    let alerts = this.props.users;

    this.state = {
      alerts: alerts,
    }
  }
  
  static defaultProps = {
    alerts: [],
  };

  render() {
    return (
      <div>
        I BE RENDERED YARRRR!
      </div>
    )
  }
};

export default CSAlerts;