import React from 'react'
import $ from 'jquery'
import I18n from 'i18n!profile'
import 'DataTables'
import axios from 'axios';

class CSAlerts extends React.Component {
  constructor(props) {
    super(props);

    let alerts = this.props.alerts;

    this.state = {
      alerts: alerts,
      bulk_checks: false,
      all_checked: false,
      loading: false,
    }
  }
  
  static defaultProps = {
    alerts: [],
  };

  selectAll() {
    let alert_ids = this.state.alerts.map(alert => `alert-${alert.alert_id}`)

    alert_ids.forEach(id => {
      this.refs[id].checked = !this.state.all_checked
    })

    this.setState({all_checked: !this.state.all_checked})
  }

  deleteAlert(alert) {
    let url = `/cs_alerts/${alert.alert_id}`
    let self = this

    axios.delete(url).then(response => {
      self.setState({
        alerts: self.state.alerts.filter(alrt => alrt.alert_id !== alert.alert_id)
      })
    }).catch(error => {
      console.log(error)
      $.flashError(I18n.t('failed_to_assign_observers', 'Request failed. Try again.'))
    })
  }

  componentDidMount() {
    this.$el = $(this.el);
    this.$el.DataTable();
  }

  componentWillUnmount(){
    $(this.el)
    .DataTable()
    .destroy(true);
  }

  renderRows() {
    return this.state.alerts.map(alert => {
      return (
        <tr>
          <td>
            {alert.student_name}
          </td>
          <td>
            <a href={alert.alert_link}>{alert.assignment_name}</a>
          </td>
          <td>
            {alert.course_name}
          </td>
          <td>
            {alert.detail}
          </td>
          <td>
            {alert.updated_at}
          </td>
          <td>
            {alert.description}
          </td>
          <td className="delete-column">
            <i className="icon-x" style={{cursor: "pointer"}} onClick={() => this.deleteAlert(alert)}></i>
            <input className={this.state.bulk_checks ? "bulk-delete-checks" : "hidden bulk-delete-checks"}
              type="checkbox" name="alert_ids[]" value={alert.alert_id} ref={`alert-${alert.alert_id}`} />
          </td>
        </tr>
      )
    })
  }

  render() {
    console.log(this.props.alerts)
    return (
      <div>
        <div className="alerts-table-heading">
          <h2>Alerts {this.state.alerts.length}</h2>
          <div className="flex-row-reverse">
            <button className="Button Button--small Button--primary"
              onClick={() => {this.setState({bulk_checks: !this.state.bulk_checks})}}>
              {this.state.bulk_checks ? "Confirm Deletion" : "Delete Multiple Messages"}
            </button>
            <div className={this.state.loading ? "dot-loader" : "dot-loader hidden"}></div>
          </div>
        </div>

        <table id="alertsTable" ref={el => this.el = el}>
          <thead>
            <tr>
              <th>Student</th>
              <th>Assignment</th>
              <th>Course</th>
              <th>Details</th>
              <th>Time</th>
              <th>Type</th>
              <th id="delete-column-header" className={this.state.bulk_checks ? "" : "visibility-hidden"}>
                <label htmlFor="bulk-delete-select">Select All</label>
                <input id="bulk-delete-select" name="bulk-delete-select" type="checkbox" onChange={this.selectAll.bind(this)} />
              </th>
            </tr>
          </thead>

          <tbody>
            {this.renderRows()}
          </tbody>
        </table>
      </div>
    )
  }
};

export default CSAlerts;