import store from '@/store'
import RadiusLogsStore from '../_store/radiuslogs'
import RadiusLogsSearch from '../_components/RadiusLogsSearch'

const AuditingView = () => import(/* webpackChunkName: "RadiusLogs" */ '../')
const RadiusLogView = () => import(/* webpackChunkName: "RadiusLogs" */ '../_components/RadiusLogView')

const route = {
  path: '/auditing',
  name: 'auditing',
  redirect: '/auditing/radiuslogs/search',
  component: AuditingView,
  meta: { transitionDelay: 300 * 2 }, // See _transitions.scss => $slide-bottom-duration
  beforeEnter: (to, from, next) => {
    if (!store.state.$_radiuslogs) {
      // Register store module only once
      store.registerModule('$_radiuslogs', RadiusLogsStore)
    }
    next()
  },
  children: [
    {
      path: 'radiuslogs/search',
      name: 'radiuslogs',
      component: RadiusLogsSearch
    },
    {
      path: 'radiuslog/:id',
      name: 'radiuslog',
      component: RadiusLogView,
      props: (route) => ({ storeName: '$_radiuslogs', id: route.params.id }),
      beforeEnter: (to, from, next) => {
        store.dispatch('$_radiuslogs/getItem', to.params.id).then(radiuslog => {
          next()
        })
      },
      meta: {
        can: 'read radius_log'
      }

    }
  ]
}

export default route
