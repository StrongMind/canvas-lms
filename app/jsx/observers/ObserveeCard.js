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
        <img src={this.state.user.avatar_image_source}></img>
        <p>
          {
            this.state.enrollments.map(enr => {
              return (
                <span>
                  <p>{enr.course_name}</p>
                  <p>{enr.score ? enr.score.final_score : null}</p>
                </span>
              )
            })
          }
        </p>
      </div>
    )
  }
}

export default ObserveeCard
