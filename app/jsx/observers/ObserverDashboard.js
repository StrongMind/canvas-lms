// import preventDefault from 'compiled/fn/preventDefault'
// import IconArrowUpSolid from 'instructure-icons/lib/Solid/IconArrowUpSolid'
// import IconArrowDownSolid from 'instructure-icons/lib/Solid/IconArrowDownSolid'
// import Typography from 'instructure-ui/lib/components/Typography'
// import Tooltip from 'instructure-ui/lib/components/Tooltip'
import React from 'react'
import PropTypes from 'prop-types'
// import $ from 'jquery'
// import I18n from 'i18n!account_course_user_search'
// import axios from 'axios'
// import CoursesListRow from './CoursesListRow'

const { arrayOf } = PropTypes

class ObserverDashboard extends React.Component {
  static defaultProps = {
    observees: [],
  };

  constructor () {
    super()
    this.state = {
      sections: [],
    }
  }

  render () {
    // const sort = this.props.sort
    // const order = this.props.order

    return (
      <div className="observer-dashboard">
        <p>I'm being observed! #nointerruption</p>
      </div>
    )
  }
  }

export default ObserverDashboard
