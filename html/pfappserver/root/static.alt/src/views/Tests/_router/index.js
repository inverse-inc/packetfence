import store from '@/store'
import FormStore from '@/store/base/form'

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
  children: [
    {
      path: 'test001',
      name: 'test001',
      component: Test001,
      props: (route) => ({ storeName: 'tests', query: route.query.query }),
      beforeEnter: (to, from, next) => {
        if (!store.state.tests) {
          // Register store module only once
          store.registerModule('tests', FormStore)
        }
        next()
      }
    }
  ]
}

export default route
