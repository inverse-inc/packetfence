import store from '@/store'
import StoreModule from './_store'

const TheView = () => import(/* webpackChunkName: "Assistant" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_assistant) {
    store.registerModule('$_assistant', StoreModule)
  }
  next()
}

export default {
  path: '/assistant',
  name: 'assistant',
  component: TheView,
  // 'read chatbot' = CHATBOT_READ, the role the api-frontend enforces on
  // /api/v1/pfchatbot; writes additionally need 'write chatbot'.
  meta: {
    can: 'read chatbot'
  },
  beforeEnter
}
