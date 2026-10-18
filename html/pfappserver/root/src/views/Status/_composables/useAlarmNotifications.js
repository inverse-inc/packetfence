import escape from 'lodash/escape'

// alarms already notified in this session (host:url => value), kept when the notifications are cleared
const notifiedAlarms = new Map()
let subscribed = false

export const alarmLabel = alarm => {
  const { chart = '', family, component, summary, name = '' } = alarm
  if (summary)
    return summary
  // netdata < 2.0 had a family, netdata >= 2.0 has a component instead
  const group = family || component
  const prefix = (chart.split('.')[0] || name).replace(/_/g, ' ')
  return (group) ? `${prefix} - ${group}` : prefix
}

// forget the notified alarms when the session ends (logout), not when the notifications are cleared
const subscribeToSession = $store => {
  if (subscribed)
    return
  subscribed = true
  $store.subscribe(({ type }) => {
    if (['session/TOKEN_DELETED', 'session/$RESET'].includes(type))
      notifiedAlarms.clear()
  })
}

export const notifyAlarm = ($store, hostname, url, alarm) => {
  subscribeToSession($store)
  const label = escape(alarmLabel(alarm))
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
      message: `<span class="font-weight-normal">${escape(hostname)}</span> ${label}`,
      url,
      value
    })
  }
}

// notify the raised alarms of a host, and forget the ones that are no longer raised
// so they are notified again if they come back
export const notifyHostAlarms = ($store, hostname, alarms = {}) => {
  Object.keys(alarms).forEach(url => notifyAlarm($store, hostname, url, alarms[url]))
  const prefix = `${hostname}:`
  Array.from(notifiedAlarms.keys()).forEach(key => {
    if (key.startsWith(prefix) && !(key.slice(prefix.length) in alarms))
      notifiedAlarms.delete(key)
  })
}
