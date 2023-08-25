import apache from './apache'
import authentication from './authentication'
import dhcp from './dhcp'
import endpoints from './endpoints'
import logs from './logs'
import queue from './queue'
import radius from './radius'
import system from './system'

export default [
  ...system,
  ...radius,
  ...apache,
  ...authentication,
  ...dhcp,
  ...endpoints,
  ...queue,
  ...logs,
]