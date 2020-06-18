import React from 'react'
import ReactDOM from 'react-dom'
import CSAlerts from 'jsx/cs_alerts/CSAlerts2'
import axios from 'axios'

const $el = document.getElementById('cs-alerts-container')
let alerts = []

axios.get("/cs_alerts/teacher_alerts").then((response) => {
  alerts = response.data
  ReactDOM.render(
    <CSAlerts
      alerts={alerts}
    />,
    $el
  )
})
