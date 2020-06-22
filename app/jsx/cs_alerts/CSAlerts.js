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
      bulk_checks: false,
      all_checked: false,
      deletable_ids: [],
      loading: false,
      dataTable: undefined,
    }
  }
  
  static defaultProps = {
    alerts: [],
  };

  selectAll() {
    this.setState({all_checked: !this.state.all_checked}, this.domSelectAll)
  }

  domSelectAll() {
    $("label[for=bulk-delete-select]").text(
      this.state.all_checked ? `Deselect All (${this.state.alerts.length} Selected)` : `Select All (${this.state.deletable_ids.length} Selected)`
    );
    if (this.state.all_checked) {
      $(':checkbox:visible').prop({checked: true, disabled: true})
    } else {
      $(':checkbox:visible').get().forEach(box => {
        let bool = this.state.deletable_ids.includes($(box).val())
        $(box).prop({checked: bool, disabled: false})
      })
    }

    $('#bulk-delete-select').prop({disabled: false})
  }

  toggleDeletable(alert) {
    let deletable_ids = this.state.deletable_ids
    let index = deletable_ids.indexOf(alert.alert_id)

    if (index !== -1) {
      deletable_ids.splice(index, 1)
    } else {
      deletable_ids.push(alert.alert_id)
    }

    this.setState({deletable_ids: deletable_ids}, () => {
      $("label[for=bulk-delete-select]").text(
        `Select All (${this.state.deletable_ids.length} Selected)`
      )
    })
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

  bulkCheck() {
    this.setState({bulk_checks: !this.state.bulk_checks}, this.toggleBulkHidden)
  }

  toggleBulkHidden() {
    $("#bulk-delete-btn").text(this.state.bulk_checks ? "Go Back" : "Delete Multiple Messages")
    $(".icon-x").toggleClass("hidden", this.state.bulk_checks)
    $(".bulk-delete-checks").toggleClass("hidden", !this.state.bulk_checks)
    $('#bulk-delete-confirm').toggleClass("hidden", !this.state.bulk_checks)
    $("#delete-column-header").toggleClass("visibility-hidden", !this.state.bulk_checks)

    this.domSelectAll()
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
    let self = this;
    this.setState({dataTable: this.$el.DataTable({
        "fnDrawCallback": self.toggleBulkHidden.bind(self)
      })
    });
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
              type="checkbox" name="alert_ids[]" value={alert.alert_id} onChange={() => this.toggleDeletable(alert)} />
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
            <button id="bulk-delete-btn" className="Button Button--small Button--primary" type="button"
              onClick={this.bulkCheck.bind(this)}>
              Delete Multiple Messages
            </button>

            <button className="Button Button--small Button--danger hidden" id="bulk-delete-confirm">
              Confirm Deletion
            </button>
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