import store from '@/store'
import StoreModule from './_store'
import { analytics } from './config'

const TheView = () => import(/* webpackChunkName: "Configuration" */ './_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_certificates)
    store.registerModule('$_certificates', StoreModule)
  next()
}

export default [
  {
    path: 'certificates',
    redirect: 'certificate/http'
  },
  {
    path: 'certificate/:id',
    name: 'certificate',
    component: TheView,
    meta: {
      ...analytics
    },
    props: (route) => ({ id: route.params.id }),
    beforeEnter
  }
]
