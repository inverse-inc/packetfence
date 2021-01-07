import store from '@/store'
import StoreModule from './_store'

const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/ScansTabs')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_wmi_rules)
    store.registerModule('$_wmi_rules', StoreModule)
  next()
}

export default [
  {
    path: 'scans/wmi_rules',
    name: 'wmiRules',
    component: TheTabs,
    props: (route) => ({ tab: 'wmi_rules', query: route.query.query }),
    beforeEnter
  },
  {
    path: 'scans/wmi_rules/new',
    name: 'newWmiRule',
    component: TheView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'scans/wmi_rule/:id',
    name: 'wmiRule',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_wmi_rules/getWmiRule', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'scans/wmi_rule/:id/clone',
    name: 'cloneWmiRule',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_wmi_rules/getWmiRule', to.params.id).then(() => {
        next()
      })
    }
  }
]
