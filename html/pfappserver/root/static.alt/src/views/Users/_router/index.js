import UsersView from '../'
import UsersSearch from '../_components/UsersSearch'
import UserView from '../_components/UserView'

const route = {
  path: '/users',
  name: 'users',
  redirect: '/users/search',
  component: UsersView,
  children: [
    {
      path: 'search',
      component: UsersSearch
    },
    {
      path: '/user/:pid',
      name: 'user',
      component: UserView,
      props: true
    }
  ]
}

export default route
