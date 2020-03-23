import React from 'react'
import styled from 'styled-components'

const Card = styled.div`
  border: 1px solid #D7D7D7;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  width: 100%;

  .observee-info {
    text-align: center;
    width: 100%;
    padding: 1rem 0;
    border-bottom: 1px solid #d7d7d7;
    
    p {
      color: #006ba6;
      font-size: 14px;
      font-weight: bold;
    }

    img {
      width: 50px;
      height: 50px;
      border-radius: 100%;
      border: 1px solid #d7d7d7;
      overflow: hidden;
    }
  }

  .observee-courses {
    width: 100%;

    p {
      font-size: 12px;
      box-sizing: border-box;
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0 1rem;
      width: 100%;

      .course-name {
        color: #1e1e1e;

        &:hover {
          color: #1e1e1e;
          text-decoration: underline;
        }
      }

      .course-score {
        font-weight: bold;
      }
    }
  }
`

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

  formatScore(score) {
    return score + '%';
  }

  render() {
    return (
      <Card>
        <div className="observee-info">
          <img src={this.state.user.avatar_image_url}></img>
          <p>{this.state.user.name}</p>
        </div>
        <div className="observee-courses">
            {
              this.state.enrollments.map(enr => {
                return (
                  <p>
                    <a className="course-name" href={'/courses/' + enr.course_id}>{enr.course_name}</a>
                    <span className="course-score">{this.formatScore(enr.score) ? this.formatScore(enr.score.final_score) : null}</span>
                  </p>
                )
              })
            }
        </div>
      </Card>
    )
  }
}

export default ObserveeCard
