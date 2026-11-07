/**
 * The ACL of a plugin manifest, the JSON form of the acl.$can, acl.$some and
 * acl.$every of the core views:
 *
 *   "read syslog"                               acl.$can('read', 'syslog')
 *   { "some": ["read syslog", "read system"] }  any of them
 *   { "every": ["read syslog", "update syslog"] } all of them
 *
 * "some" and "every" can be nested. Used by menu.can (sidebar item and routes),
 * api.<create|update|delete>.can (the method is not offered) and the can of the
 * form fields and tabs (hidden). The API still enforces the admin roles.
 *
 * The rules are checked with the $can helper vue-browser-acl installs (the same
 * rules as acl.$can): this module cannot import '@/utils/acl', which imports
 * the router this module is loaded by.
 */
import Vue from 'vue'

const $can = (verb, target) => {
  const helper = Vue.prototype.$can
  return (typeof helper === 'function') ? !!helper(verb, target) : false
}

export const can = expression => {
  if (expression === undefined || expression === null)
    return true
  if (typeof expression === 'string') {
    const [ verb, target ] = expression.split(' ')
    return $can(verb, target)
  }
  if (Array.isArray(expression.some))
    return expression.some.some(can)
  if (Array.isArray(expression.every))
    return expression.every.every(can)
  return false // unknown form: deny
}

export default can
