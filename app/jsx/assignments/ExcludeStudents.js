import React from 'react'
import ReactDOM from 'react-dom'
import TokenInput, {Option as ComboboxOption} from 'react-tokeninput'

class ExcludeStudents extends React.Component {
    constructor(props) {
        super(props)
        this.state = {
            students: 
                ENV['ALL_STUDENTS'],
            exceptions: [
                ENV['EXCLUDED_STUDENTS']
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

    handleInput() {
      console.log('hi');
    }

    handeFocus() {
      console.log('Hey');
    }

    handleTokenAdd() {
      console.log('Howdy');
    }

    handleTokenRemove() {
      console.log("Bye");
    }
  
    render() {
        console.log(this.state)
        return(
            <ul>
                { this.renderStudentList() }
                <TokenInput
                    selected            = {ENV['EXCLUDED_STUDENTS']}
                    onFocus             = {this.handleFocus}
                    onInput             = {this.handleInput}
                    onSelect            = {this.handleTokenAdd}
                    onRemove            = {this.handleTokenRemove}
                    value               = {true}
                    ref                 = "TokenInput"
                />
            </ul>
        )
    }
}

export default ExcludeStudents