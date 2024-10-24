import apache from './apache'
import authentication from './authentication'
import dhcp from './dhcp'
import endpoints from './endpoints'
import haproxy from './haproxy'
import logs from './logs'
import queue from './queue'
import radius from './radius'
import system from './system'
import virtualization from './virtualization'

export default [
  ...system,
  ...radius,
  ...apache,
  ...authentication,
  ...dhcp,
  ...endpoints,
  ...haproxy,
  ...queue,
  ...logs,
  ...virtualization,
]