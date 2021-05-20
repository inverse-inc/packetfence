import Vue from 'vue'
import Acl from 'browser-acl'
import VueAcl from 'vue-browser-acl'
import router from '@/router'
import store from '@/store'

// See https://github.com/inverse-inc/packetfence/blob/devel/lib/pf/constants/admin_roles.pm#L22-L206
export const ADMIN_ROLES_ACTIONS = [
  'create',
  'create_overwrite',
  'create_multiple',
  'delete',
  'mark_as_sponsor',
  'read',
  'read_sponsored',
  'set_access_level',
  'set_access_duration',
  'set_bandwidth_balance',
  'set_role',
  'set_tenant_id',
  'set_time_balance',
  'set_unreg_date',
  'trigger_mfa',
  'trigger_portal_mfa',
  'update',
  'write',
  'master'
]

export const aclContext = () => store.getters['session/aclContext']

const acl = new Acl()
acl.$can = (verb, action) => {
  return acl.can(aclContext, verb, action)
}
acl.$some = (verb, actions) => {
  return actions.reduce((can, action) => {
    return can || acl.$can(verb, action)
  }, false)
}
acl.$every = (verb, actions) => {
  return actions.reduce((can, action) => {
    return can && acl.$can(verb, action)
  }, true)
}

export const setupAcl = () => {
  for (const role of aclContext()) {
    let action = ''
    let target = ''
    for (const currentAction of ADMIN_ROLES_ACTIONS) {
      if (role.toLowerCase().endsWith(currentAction)) {
        action = currentAction.replace(/_/g, '-')
        target = role.substring(0, role.length - action.length - 1).toLowerCase()
        break
      }
    }
    if (!target) {
      // eslint-disable-next-line
      console.warn(`No action found for ${role}`)
      action = 'access'
      target = role.toLowerCase()
    }
    // eslint-disable-next-line
    console.debug('configure acl ' + action + ' => ' + target)
    acl.rule(action, target, () => true)
  }
}

export default acl

/**
 * Centralize router ACL failover:
 *
 * vue-broswer-acl is slow and sometimes fails when redirecting/recursing through multiple routes due to ACL failures.
 *
 * eg: routeA (can > fail > redirect) => routeB (can > fail > redirect) => and so on...
**/
const failRoute = (to, from) => {
  let failRoutes = router.options.routes.reduce((routes, section) => {
    if (section.children) // only use sections that have child route(s)
      section.children.map(child => {
        const { meta: { isFailRoute = false } = {} } = child
        if (isFailRoute) // only use route(s) that have isFailRoute set
          routes.push(child)
      })
    return routes
  }, [])
  const failIndex = failRoutes.findIndex(route => route.name === to.name)
  if (failIndex >= 0) // reorder routes
    failRoutes = [...failRoutes.slice(failIndex), ...failRoutes.slice(0, failIndex)] // split and rejoin starting with next
  for (let r = 0; r < failRoutes.length; r++) { // iterate through ordered routes
    const { name, can = () => true } = failRoutes[r]
    if (name !== to.name) { // ignore current routes
      if (can.constructor === Function && can(to, from))
        return { name }
      else {
        const { 0: verb, 1: action } = can.split(' ')
        if (acl.$can(verb, action))
          return { name }
      }
    }
  }
  // panic, no acceptable failover found
  // eslint-disable-next-line
  console.error('Unable to find a permissible route for this users ACL.')
  return { path: '/logout' }
}

Vue.use(VueAcl, aclContext, acl, { caseMode: false, failRoute, router })
