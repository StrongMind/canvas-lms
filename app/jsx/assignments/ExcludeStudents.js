import React from 'react'
import ReactDOM from 'react-dom'
class ExcludeStudents extends React.Component {
    constructor(props) {
        super(props)
        this.state = {
            students: ['Chris Young']
        }
    }
  
    render() {
        return(    
            <div>
                { this.state.students.map((item,key) => <div>{item}</div>) }
            </div>
        )
    }
}

export default ExcludeStudents