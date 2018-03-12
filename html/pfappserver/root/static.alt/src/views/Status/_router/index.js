import StatusView from '../'
import Dashboard from '../_components/Dashboard'
import Services from '../_components/Services'

const route = {
  path: '/status',
  name: 'status',
  redirect: '/status/dashboard',
  component: StatusView,
  children: [
    {
      path: 'dashboard',
      component: Dashboard
    },
    {
      path: 'services',
      component: Services
    }
  ]
}

export default route
