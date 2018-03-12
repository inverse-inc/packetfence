import LoginView from '../'

const route = {
  path: '/',
  alias: ['/login', '/logout', '/expire'],
  name: 'login',
  component: LoginView
}

export default route
