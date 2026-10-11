// alarms already notified in this session (url => value), kept when the notifications are cleared
const notifiedAlarms = new Map()

export const alarmLabel = alarm => {
  const { chart = '', family, component, summary, name = '' } = alarm
  if (summary)
    return summary
  // netdata < 2.0 had a family, netdata >= 2.0 has a component instead
  const group = family || component
  const prefix = (chart.split('.')[0] || name).replace(/_/g, ' ')
  return (group) ? `${prefix} - ${group}` : prefix
}

const escapeHtml = text => String(text).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c])

export const notifyAlarm = ($store, hostname, url, alarm) => {
  const label = escapeHtml(alarmLabel(alarm))
  const value = alarm.value_string
  let status = alarm.status.toLowerCase()
  switch (status) {
    case 'warning':
      break
    case 'critical':
      status = 'danger'
      break
    default:
      status = 'info'
  }
  const key = `${hostname}:${url}`
  if (notifiedAlarms.get(key) === value)
    return
  notifiedAlarms.set(key, value)
  const previousNotification = $store.state.notification.all.find(notification => {
    return notification.url === url && notification.value === value
  })
  if (!previousNotification) {
    $store.dispatch(`notification/${status}`, {
      message: `<span class="font-weight-normal">${hostname}</span> ${label}`,
      url,
      value
    })
  }
}
