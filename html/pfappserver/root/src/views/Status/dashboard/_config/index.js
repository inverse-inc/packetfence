import authentication from './authentication'
import dhcp from './dhcp'
import endpoints from './endpoints'
import logs from './logs'
import portal from './portal'
import queue from './queue'
import radius from './radius'
import system from './system'

export default [
  ...system,
  ...radius,
  ...authentication,
  ...dhcp,
  ...endpoints,
  ...portal,
  ...queue,
  ...logs
]