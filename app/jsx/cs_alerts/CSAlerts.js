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
    }
  }
  
  static defaultProps = {
    alerts: [],
  };

  deleteAlert(alert) {
    let url = `/cs_alerts/${alert.alert_id}`
    let self = this

    axios.delete(url).then(response => {
      self.setState({
        alerts: self.state.alerts.filter(alrt => alrt.alert_id !== alert.alert_id)
      })
    }).catch(error => {
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
            <input className="hidden bulk-delete-checks" type="checkbox" name="alert_ids[]" value={alert.alert_id} />
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
              <button className="Button Button--small Button--primary" id="bulk-delete-btn">Delete Multiple Messages</button>
              <button className="Button Button--small Button--danger hidden" id="bulk-delete-confirm"
              data-url='<%= bulk_delete_cs_alerts_path %>'>Confirm Deletion</button>
              <div className="dot-loader hidden"></div>
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
              <th id="delete-column-header" className="visibility-hidden">
                <label htmlFor="bulk-delete-select">Select All</label>
                <input id="bulk-delete-select" name="bulk-delete-select" type="checkbox" />
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