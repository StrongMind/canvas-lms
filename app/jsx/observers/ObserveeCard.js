import React from 'react'

class ObserveeCard extends React.Component {
  static defaultProps = {
    student: {},
  };

  render() {
    return (
      <div className="observee-card">
        <p>I am being observed! #NoInterruptions</p>
      </div>
    )
  }
}

export default ObserveeCard
