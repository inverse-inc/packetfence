import i18n from '@/utils/locale'
import store from '@/store'
import StoreModule from './_store'

const TheSearch = () => import(/* webpackChunkName: "Auditing" */ './_components/TheSearch')
const TheView = () => import(/* webpackChunkName: "Auditing" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_admin_api_audit_logs) {
    store.registerModule('$_admin_api_audit_logs', StoreModule)
  }
  next()
}

export default [
  {
    path: 'admin_api_audit_logs/search',
    name: 'admin_api_audit_logs',
    component: TheSearch,
    meta: {
      can: 'read admin_api_audit_log',
      isFailRoute: true
    },
    beforeEnter
  },
  {
    path: 'admin_api_audit_log/:id',
    name: 'admin_api_audit_log',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_admin_api_audit_logs/getItem', to.params.id).then(() => {
        next()
      }).catch(() => { // `mac` does not exist
        store.dispatch('notification/danger', { message: i18n.t('Admin Audit Log <code>{id}</code> does not exist or is not available for this tenant.', to.params) })
        next({ name: 'admin_api_audit_logs' })
      })
    },
    meta: {
      can: 'read admin_api_audit_log'
    }
  }
]