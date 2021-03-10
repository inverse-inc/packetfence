import store from '@/store'
import BasesStoreModule from '../bases/_store'

const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/MainTabs')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_bases) {
    store.registerModule('$_bases', BasesStoreModule)
  }
  next()
}

export default [
  {
    path: 'alerting',
    name: 'alerting',
    component: TheTabs,
    props: (route) => ({ tab: 'alerting', query: route.query.query }),
    beforeEnter
  }
]
