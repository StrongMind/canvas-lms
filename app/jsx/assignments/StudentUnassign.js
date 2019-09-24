import React from 'react'
import TokenInput, {Option as ComboboxOption} from 'react-tokeninput'
import StudentExemptions from 'jsx/assignments/StudentExemptions'
import OverrideStudentStore from "jsx/due_dates/OverrideStudentStore";

class StudentUnassignments extends StudentExemptions {
  constructor(props) {
    super(props)
    this.filterTags = this.filterTags.bind(this)
  }

  componentDidMount() {
    this.setState({
      overrides: OverrideStudentStore.getCurrentOverrides()
    })
  }

  filterTags(userInput) {
    this.setState({
      overrides: OverrideStudentStore.getCurrentOverrides()
    })

    if (userInput === '') return this.setState({options: []});
    this.setState({
      options: this.names().filter((name) =>
        new RegExp('^'+userInput, 'i').test(name)
      )
    })
  }

  lmsData(props){
    return {
      input: '',
      loading: false,
      options: [],
      students: props['students'],
      exemptions: props['exemptions'],
      overrides: []
    }
  }

  filterOverrides() {
    let filteredArray = this.state.students.filter(student => !this.state.overrides.includes(student.id))
    return filteredArray.map(students => students.name)
  }

  renderComboboxOptions() {
    if (this.filterOverrides().length) {
      return this.filterOverrides().map((name) => {
        var student = this.findStudent(name)
        return (
          <ComboboxOption
            key={student.id}
            value={student.name}
            isFocusable={student.name.length > 1}
          >{student.name}</ComboboxOption>
        )
      })
    } else if (this.state.input && !this.state.loading) {
      return (
        [
          <ComboboxOption key="No results found" value="No results found">
            No results found
          </ComboboxOption>
        ]
      )
    } else {
      return []
    }
  }
}

export default StudentUnassignments
