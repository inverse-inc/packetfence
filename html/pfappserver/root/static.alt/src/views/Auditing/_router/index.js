import store from '@/store'
import AuditingView from '../'
import RadiusLogsStore from '../_store/radiuslogs'
import RadiusLogsSearch from '../_components/RadiusLogsSearch'

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
      component: RadiusLogsSearch
    }
  ]
}

export default route
