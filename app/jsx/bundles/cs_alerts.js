import $ from 'jquery'
import React from 'react'
import ReactDOM from 'react-dom'
import CSAlerts from 'jsx/cs_alerts/CSAlerts'
import axios from 'axios'

const $el = document.getElementById('cs-alerts-container')

ReactDOM.render(
  <CSAlerts
    alerts={[]}
  />,
  $el
)