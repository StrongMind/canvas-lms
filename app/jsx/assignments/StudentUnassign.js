import React from 'react'
import TokenInput, {Option as ComboboxOption} from 'react-tokeninput'
import StudentExemptions from 'jsx/assignments/StudentExemptions'
import OverrideStudentStore from "jsx/due_dates/OverrideStudentStore";

class StudentUnassignments extends StudentExemptions {
  constructor(props) {
    super(props)
  }

  componentDidMount() {
    this.setState({
      overrides: OverrideStudentStore.getCurrentOverrides()
    })
  }

  componentWillReceiveProps(nextProps) {
    console.log('received props')
    const { currentOverrides } = nextProps
    if (currentOverrides !== this.state.overrides) {
      this.setState({
        overrides: currentOverrides
      })
    }
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
    console.log(this.filterOverrides())
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
