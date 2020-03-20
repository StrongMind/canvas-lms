import React from 'react'

class ObserveeCard extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      user: this.props.student.attributes.user,
      enrollments: this.props.student.attributes.enrollments
    }
  }

  static defaultProps = {
    student: {},
  };

  render() {
    return (
      <div
       className="observee-card content-box pad-box-mini border border-trbl border-round-b"
       style={{display: 'inline-block', margin: '1rem'}} >
        <p>{this.state.user.name}</p>
      </div>
    )
  }
}

export default ObserveeCard
