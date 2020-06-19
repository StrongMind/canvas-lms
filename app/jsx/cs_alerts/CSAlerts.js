import React from 'react'
import $ from 'jquery'
import I18n from 'i18n!profile'
import 'datatables.net'
import axios from 'axios';

class CSAlerts extends React.Component {
  constructor(props) {
    super(props);

    let alerts = this.props.alerts;

    this.state = {
      alerts: alerts,
      alertType: 'normal',
      bulk_checks: false,
      all_checked: false,
      loading: false,
      dataTable: undefined,
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

      self.removeRow(alert.alert_id)
    }).catch(error => {
      console.log(error)
      $.flashError(I18n.t('failed_to_assign_observers', 'Request failed. Try again.'))
    })
  }

  bulkCheck(target) {
    this.setState({bulk_checks: !this.state.bulk_checks})
    setTimeout(() => {
      $(target).text(this.state.bulk_checks ? "Confirm Deletion" : "Delete Multiple Messages")
      $(".icon-x").toggleClass("hidden", this.state.bulk_checks)
      $(".bulk-delete-checks").toggleClass("hidden", !this.state.bulk_checks)
      $("#delete-column-header").toggleClass("visibility-hidden", !this.state.bulk_checks)
    }, 0)
  }

  removeRow(id) {
    this.state.dataTable.row($(this.refs[`row-${id}`])).remove().draw()
    $(this.refs["alertCount"]).text(this.state.alerts.length)
  }

  componentDidMount() {
    this.initializeDataTable();
  }

  initializeDataTable() {
    this.$el = $(this.el);
    this.setState({dataTable: this.$el.DataTable()});
  }

  componentWillUnmount(){
    this.state.dataTable.destroy(true);
  }

  shouldComponentUpdate() {
    return false;
  }

  renderRows() {
    return this.state.alerts.map(alert => {
      return (
        <tr ref={`row-${alert.alert_id}`}>
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
      <div key={this.state.alertType}>
        <div className="alerts-table-heading">
          <h2>Alerts <span ref="alertCount">{this.state.alerts.length}</span></h2>
          <div className="flex-row-reverse">
            <button className="Button Button--small Button--primary" type="button"
              onClick={(e) => { this.bulkCheck(e.target) }}>
              Delete Multiple Messages
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
              <th id="delete-column-header" className="visibility-hidden">
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