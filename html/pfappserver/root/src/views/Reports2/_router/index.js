import acl from '@/utils/acl'
import store from '@/store'
import TheIndex from '../'
import StoreModule from '../_store'

const TheView = () => import(/* webpackChunkName: "Reports" */ '../_components/TheView')

const route = {
  path: '/reports2',
  name: 'reports2',
  redirect: '/reports2/os',
  component: TheIndex,
  meta: {
    can: () => acl.$some('read', ['reports']), // has ACL for 1+ children
    isFailRoute: true,
    transitionDelay: 300 * 2 // See _transitions.scss => $slide-bottom-duration
  },
  beforeEnter: (to, from, next) => {
    if (!store.state.$_reports) {
      // Register store module only once
      store.registerModule('$_reports', StoreModule)
    }
    next()
  },
  children: [
    {
      path: ':id([a-zA-Z0-9]+[a-zA-Z0-9-_/:]+[a-zA-Z0-9]+)/',
      name: 'report',
      component: TheView,
      props: route => ({ id: route.params.id }),
      meta: {
        can: 'read reports'
      }
    }
  ]
}

export default route
