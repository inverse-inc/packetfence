import { reset as resetVuexStore } from '@/store'
import { useStore as usePreferencesStore } from '@/views/Configuration/_store/preferences'
import LoginView from '../'

const route = {
  path: '/login',
  alias: ['/logout', '/expire'],
  name: 'login',
  component: LoginView,
  beforeEnter: (to, from, next) => {
    usePreferencesStore().reset()
    resetVuexStore()
    next()
  }
}

export default route
