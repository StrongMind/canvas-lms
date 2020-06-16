import React from 'react'

class CSAlerts extends React.Component {
  constructor(props) {
    super(props);

    let alerts = this.props.alerts;

    this.state = {
      alerts: alerts,
    }
  }
  
  static defaultProps = {
    alerts: [],
  };

  render() {
    console.log(this.props.alerts)
    return (
      <div>
        I BE RENDERED YARRRR!
      </div>
    )
  }
};

export default CSAlerts;