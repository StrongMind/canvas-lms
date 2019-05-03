import React from 'react'
import ReactDOM from 'react-dom'
import TokenInput, {Option as ComboboxOption} from 'react-tokeninput'

class ExcludeStudents extends React.Component {
    constructor(props) {
        super(props)
        this.state = this.lmsData(props)

        this.handleInput = this.handleInput.bind(this)
        this.renderComboboxOptions = this.renderComboboxOptions.bind(this)
        this.handleTokenAdd = this.handleTokenAdd.bind(this)
        this.handleTokenRemove = this.handleTokenRemove.bind(this)
        this.filterTags = this.filterTags.bind(this)
    }

    lmsData(props){
      return {
        input: '',
        loading: false,
        options: [],
        students: props['students'],
        exceptions: props['excludes']
      }
    }

    // Use this to set test state if you aren't connecting to
    // Data from the server
    fixture(){
      return {
        input: '',
        loading: false,
        options: [],
        students: 
          [
            { name: 'chris', id: 1},
            { name: 'conrad', id: 4},
            { name: 'joe', id: 2},
            { name: 'pete', id: 3}
          ],
        exceptions: 
          [
            { name: 'pete', id: 3 }
          ]
      }
    }

    names(){
      return this.state.students.map(student => {
        return student.name
      }).filter(function(name) {
        return !this.state.exceptions.find(stu => stu.name === name)
      }.bind(this))
    }

    handleInput(userInput) {
      this.setState({
        input: userInput,
        loading: true,
        options: []
      })
      setTimeout(function () {
        this.filterTags(this.state.input)
        this.setState({
          loading: false
        })
      }.bind(this), 500)
    }

    findStudentName(userInput){
      var filter = new RegExp('^'+userInput, 'i');
      return this.names().find(function(name) {
        return filter.test(name)
      })
    }

    filterTags(userInput) {
      if (userInput === '') return this.setState({options: []});
      this.setState({
        options: this.names().filter(function(name) {
          return new RegExp('^'+userInput, 'i').test(name);
        })
      });
    }

    handleTokenAdd(token) {
      var studentName = this.findStudentName(token);
      if(!studentName) return
      var student = this.state.students.find((element) => element.name === studentName)
      this.setState({exceptions: [...this.state.exceptions, student]})
    }

    handleTokenRemove(token) {
      this.setState({exceptions: this.state.exceptions.filter(function(student) { 
        return student.id !== token.id
      })});
    }

    renderComboboxOptions(){
      return this.state.options.map(function(name) {
        return (
          <ComboboxOption
            key={name} 
            value={name}
            isFocusable={name.length > 1}
          >{name}</ComboboxOption>
        );
      });
    }

    rowStyle() {
      return({
        'border': '1px solid #ccc',
        'borderRadius': '5px',
        'borderBottomLeftRadius': 0,
        'borderBottomRightRadius': 0,
        'borderBottom': 'none'
      })
    };

    containerStyle(){
      return({
        borderBottom: '1px solid #ccc',
        padding: '15px'
      })
    }
    
    render() {
        var options = this.state.options.length ?
        this.renderComboboxOptions() : [];

        this.props.syncWithBackbone(this.state.exceptions)
        if(!this.state.exceptions){return <ul></ul>}
        if(!this.state.students){return <ul></ul>}

        return(
          <div style={this.rowStyle()}>
            <div style={this.containerStyle()}>
              <div id="excuse-label" class="ic-Label" title="Excuse these students" aria-label="Excuse these students">
                Exempt these students
              </div>
              <TokenInput
                  menuContent = {options}
                  selected    = {this.state.exceptions}
                  onInput     = {this.handleInput}
                  onSelect    = {this.handleTokenAdd}
                  onRemove    = {this.handleTokenRemove}
                  value       = {true}
                  ref         = "TokenInput"
              />
            </div>
          </div>
        )
    }
}

export default ExcludeStudents