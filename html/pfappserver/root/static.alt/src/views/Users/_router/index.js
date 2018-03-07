import UsersView from '../'
import UsersSearch from '../_components/UsersSearch'

const route = {
  path: '/users',
  name: 'users',
  redirect: '/users/search',
  component: UsersView,
  children: [
    {
      path: 'search',
      component: UsersSearch
    }
  ]
}

export default route
