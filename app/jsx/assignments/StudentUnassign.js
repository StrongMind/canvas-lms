import React from 'react'
import getState from 'redux'
import TokenInput, {Option as ComboboxOption} from 'react-tokeninput'
import StudentExemptions from 'jsx/assignments/StudentExemptions'

class StudentUnassignments extends StudentExemptions {
  constructor(props) {
    super(props)
  }

  filterOverrides() {
    console.log(this.state.options)
    console.log(this.state.overrides)
    return this.state.options.filter(student => !this.state.overrides.includes(student.id))
  }

  mapStateToProps(state) {
    return { overrides: state.overrides.flatMap(override => override['attributes']['student_ids']) }
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
