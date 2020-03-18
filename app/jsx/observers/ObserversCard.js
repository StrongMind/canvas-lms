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

class ObserversCard extends React.Component {
  static propTypes = {
    observees: arrayOf(observers),
  };

  static defaultProps = {
    sort: 'sis_course_id',
    order: 'asc',
    roles: [],
  };

  constructor () {
    super()
    this.state = {
      sections: [],
    }
  }

  componentWillMount () {
    // this.props.courses.forEach((course) => {
    //   axios
    //       .get(`/api/v1/courses/${course.id}/sections`)
    //       .then((response) => {
    //         this.setState({
    //           sections: this.state.sections.concat(response.data)
    //         })
    //       })
    // })
  }

  render () {
    // const sort = this.props.sort
    // const order = this.props.order

    // const courseLabel = I18n.t('Course')
    // const idLabel = I18n.t('SIS ID')
    // const teacherLabel = I18n.t('Teacher')
    // const enrollmentsLabel = I18n.t('Enrollments')
    // const subaccountLabel = I18n.t('Sub-Account')

    // let courseTip
    // let idTip
    // let teacherTip
    // let enrollmentsTip
    // let subaccountTip

    // let courseArrow = ''
    // let idArrow = ''
    // let teacherArrow = ''
    // let enrollmentsArrow = ''
    // let subaccountArrow = ''

    // if (sort === 'course_name') {
    //   idTip = I18n.t('Click to sort by SIS ID ascending')
    //   teacherTip = I18n.t('Click to sort by teacher ascending')
    //   enrollmentsTip = I18n.t('Click to sort by enrollments ascending')
    //   subaccountTip = I18n.t('Click to sort by subaccount ascending')
    //   if (order === 'asc') {
    //     courseTip = I18n.t('Click to sort by name descending')
    //     courseArrow = <IconArrowDownSolid />
    //   } else {
    //     courseTip = I18n.t('Click to sort by name ascending')
    //     courseArrow = <IconArrowUpSolid />
    //   }
    // } else if (sort === 'sis_course_id') {
    //   courseTip = I18n.t('Click to sort by name ascending')
    //   teacherTip = I18n.t('Click to sort by teacher ascending')
    //   enrollmentsTip = I18n.t('Click to sort by enrollments ascending')
    //   subaccountTip = I18n.t('Click to sort by subaccount ascending')
    //   if (order === 'asc') {
    //     idTip = I18n.t('Click to sort by SIS ID descending')
    //     idArrow = <IconArrowDownSolid />
    //   } else {
    //     idTip = I18n.t('Click to sort by SIS ID ascending')
    //     idArrow = <IconArrowUpSolid />
    //   }
    // } else if (sort === 'teacher') {
    //   courseTip = I18n.t('Click to sort by name ascending')
    //   idTip = I18n.t('Click to sort by SIS ID ascending')
    //   enrollmentsTip = I18n.t('Click to sort by enrollments ascending')
    //   subaccountTip = I18n.t('Click to sort by subaccount ascending')
    //   if (order === 'asc') {
    //     teacherTip = I18n.t('Click to sort by teacher descending')
    //     teacherArrow = <IconArrowDownSolid />
    //   } else {
    //     teacherTip = I18n.t('Click to sort by teacher ascending')
    //     teacherArrow = <IconArrowUpSolid />
    //   }
    // } else if (sort === 'enrollments') {
    //   courseTip = I18n.t('Click to sort by name ascending')
    //   idTip = I18n.t('Click to sort by SIS ID ascending')
    //   teacherTip = I18n.t('Click to sort by teacher ascending')
    //   subaccountTip = I18n.t('Click to sort by subaccount ascending')
    //   if (order === 'asc') {
    //     enrollmentsTip = I18n.t('Click to sort by enrollments descending')
    //     enrollmentsArrow = <IconArrowDownSolid />
    //   } else {
    //     enrollmentsTip = I18n.t('Click to sort by enrollments ascending')
    //     enrollmentsArrow = <IconArrowUpSolid />
    //   }
    // } else if (sort === 'subaccount') {
    //   courseTip = I18n.t('Click to sort by name ascending')
    //   idTip = I18n.t('Click to sort by SIS ID ascending')
    //   teacherTip = I18n.t('Click to sort by teacher ascending')
    //   enrollmentsTip = I18n.t('Click to sort by enrollments ascending')
    //   if (order === 'asc') {
    //     subaccountTip = I18n.t('Click to sort by subaccount descending')
    //     subaccountArrow = <IconArrowDownSolid />
    //   } else {
    //     subaccountTip = I18n.t('Click to sort by subaccount ascending')
    //     subaccountArrow = <IconArrowUpSolid />
    //   }
    // }

    return (
      <div className="observee-card">
        <p>I'm being observed! #nointerruption</p>
      </div>
    )
  }
  }

export default ObserversCard
