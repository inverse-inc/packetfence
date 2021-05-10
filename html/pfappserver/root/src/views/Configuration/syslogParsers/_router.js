import store from '@/store'
import StoreModule from './_store'

const TheList = () => import(/* webpackChunkName: "Configuration" */ '../_components/SyslogParsersList')
const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const useRouter = $router => {
 return {
    goToCollection: () => $router.push({ name: 'syslogParsers' }),
    goToItem: params => $router
      .push({ name: 'syslogParser', params })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: params => $router.push({ name: 'cloneSyslogParser', params }),
  }
}

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_syslog_parsers)
    store.registerModule('$_syslog_parsers', StoreModule)
  next()
}

export default [
  {
    path: 'pfdetect',
    name: 'syslogParsers',
    component: TheList,
    props: (route) => ({ query: route.query.query }),
    beforeEnter
  },
  {
    path: 'pfdetect/new/:syslogParserType',
    name: 'newSyslogParser',
    component: TheView,
    props: (route) => ({ isNew: true, syslogParserType: route.params.syslogParserType }),
    beforeEnter
  },
  {
    path: 'pfdetect/:id',
    name: 'syslogParser',
    component: TheView,
    props: (route) => ({ id: route.params.id }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_syslog_parsers/getSyslogParser', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'pfdetect/:id/clone',
    name: 'cloneSyslogParser',
    component: TheView,
    props: (route) => ({ id: route.params.id, isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_syslog_parsers/getSyslogParser', to.params.id).then(() => {
        next()
      })
    }
  }
]
