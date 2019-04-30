import React from 'react'
import ReactDOM from 'react-dom'
class ExcludeStudents extends React.Component {
    constructor(props) {
        super(props)
        this.state = {
            students: 
                {
                    1: {id: 1, name: 'Chris Young'},
                    2: {id: 2, name: 'Andy Rosenberg'},
                    3: {id: 3, name: 'John VanBuskirk'}
                }
            ,
            exceptions: { 2: {id: 2, name: 'Andy Rosenberg'} }
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
            Object.keys(this.state.students).map((key) => 
                this.renderStudentListItem(this.state.students[key])
            )
        )
    }

    handleStudentClick(e) {
        console.log(e.target.getAttribute('data-student-id'))
    }
  
    render() {
        return(    
            <ul>
                { this.renderStudentList() }
            </ul>
        )
    }
}

export default ExcludeStudents