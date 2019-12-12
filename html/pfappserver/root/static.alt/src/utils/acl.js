import Vue from 'vue'
import Acl from 'browser-acl'
import VueAcl from 'vue-browser-acl'
import router from '@/router'
import store from '@/store'

// See https://github.com/inverse-inc/packetfence/blob/devel/lib/pf/constants/admin_roles.pm#L22-L206
const ADMIN_ROLES_ACTIONS = [
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
  'update',
  'write'
]

export const aclContext = () => store.state.session.roles

const acl = new Acl()
acl.$can = (verb, action) => {
  return acl.can(aclContext, verb, action)
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

Vue.use(VueAcl, aclContext, acl, { caseMode: false, router })