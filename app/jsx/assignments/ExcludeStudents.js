import React from 'react'
import ReactDOM from 'react-dom'
class ExcludeStudents extends React.Component {
    constructor(props) {
        super(props)
        this.state = {
            students: 
                [
                    {id: 1, name: 'Chris Young'},
                    {id: 2, name: 'Andy Rosenberg'},
                    {id: 3, name: 'John VanBuskirk'}
                ],
            exceptions: [
                [ {id: 2, name: 'Andy Rosenberg'} ]
            ]
        }
        this.handleStudentClick = this.handleStudentClick.bind(this)
    }
    
    renderStudentListItem(item) {
        return(
            <li>
                <input type="checkbox" data-student-id={item.id} checked={this.state.exceptions[item.id]} onClick={this.handleStudentClick}></input>
                &nbsp;
                <span>{item.name}</span>
            </li> 
        )
    }

    renderStudentList () {
        return (
            this.state.students.map((item) => 
                this.renderStudentListItem(item)
            )
        )
    }

    handleStudentClick(e) {
        var studentID = e.target.getAttribute('data-student-id')        
        var myStudent = this.state.students.find((student) => { 
            return student.id == studentID
        })
        
        this.setState(
            { exceptions: [...this.state.exceptions, myStudent] }
        )
    }
  
    render() {
        console.log(this.state)
        return(
            <ul>
                { this.renderStudentList() }
            </ul>
        )
    }
}

export default ExcludeStudents