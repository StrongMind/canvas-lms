import React from 'react'
import TokenInput, {Option as ComboboxOption} from 'react-tokeninput'
import StudentExemptions from 'jsx/assignments/StudentExemptions'
import OverrideStudentStore from "jsx/due_dates/OverrideStudentStore";

class StudentUnassignments extends StudentExemptions {
  constructor(props) {
    super(props)
    this.state.filteredStudents = this.filterOverrides()
  }

  componentDidMount() {
    this.setState({
      overrides: OverrideStudentStore.getCurrentOverrides()
    })
  }

  filterOverrides() {
    return this.state.options.filter(student => !this.state.overrides.includes(student.id))
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
