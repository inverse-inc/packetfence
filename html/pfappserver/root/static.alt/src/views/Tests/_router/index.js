import store from '@/store'
import TestsStore from '../_store/tests'

const TestsView = () => import(/* webpackChunkName: "Auditing" */ '../')
const Test001 = () => import(/* webpackChunkName: "Auditing" */ '../_components/Test001')

const route = {
  path: '/tests',
  name: 'tests',
  redirect: '/tests/test001',
  component: TestsView,
  meta: {
    transitionDelay: 300 * 2 // See _transitions.scss => $slide-bottom-duration
  },
  beforeEnter: (to, from, next) => {
    if (!store.state.tests) {
      // Register store module only once
      store.registerModule('tests', TestsStore)
    }
    next()
  },
  children: [
    {
      path: 'test001',
      name: 'test001',
      component: Test001,
      props: (route) => ({ storeName: '$_tests', query: route.query.query }),
      meta: {
      }
    }
  ]
}

export default route
