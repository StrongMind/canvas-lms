import React from 'react'
import ReactDOM from 'react-dom'
import TokenInput, {Option as ComboboxOption} from 'react-tokeninput'

class ExcludeStudents extends React.Component {
    constructor(props) {
        super(props)
        this.state = this.fixture()
        this.handleInput = this.handleInput.bind(this)
        this.renderComboboxOptions = this.renderComboboxOptions.bind(this)
        this.handleTokenAdd = this.handleTokenAdd.bind(this)
        this.handleTokenRemove = this.handleTokenRemove.bind(this)
        this.filterTags = this.filterTags.bind(this)
    }

    lmsData(){
      return {
        students: 
            ENV['ALL_STUDENTS'],
        exceptions: [
            ENV['EXCLUDED_STUDENTS']
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

    handeFocus() {
      console.log('HandleFocus')
    }

    handleTokenAdd(token) {
      var studentName = this.findStudentName(token);
      if(!studentName) return
      var student = this.state.students.find(function(element){
        return element.name === studentName
      })
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
  
    render() {
        var options = this.state.options.length ?
        this.renderComboboxOptions() : [];

        return(
            <ul>
                <TokenInput
                    menuContent = {options}
                    selected    = {this.state.exceptions}
                    onFocus     = {this.handleFocus}
                    onInput     = {this.handleInput}
                    onSelect    = {this.handleTokenAdd}
                    onRemove    = {this.handleTokenRemove}
                    value       = {true}
                    ref         = "TokenInput"
                />
            </ul>
        )
    }
}

export default ExcludeStudents