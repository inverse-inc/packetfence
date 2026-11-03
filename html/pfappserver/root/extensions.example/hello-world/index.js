/**
 * Example admin UI extension, see ../../extensions/README.md
 *
 * Not built by default. To try it:
 *   PF_UI_EXTENSIONS=$PWD/extensions.example/hello-world npm run build
 */
import 'vue-awesome/icons/flask'
import acl from '@/utils/acl'
import store from '@/store'
import i18n from '@/utils/locale'
import helloWorldStore from './store'
import helloWorldTemporaryStore from './store/temporary'

const TheView = () => import(/* webpackChunkName: "ext-hello-world" */ './components/TheView')
const TheSection = () => import(/* webpackChunkName: "ext-hello-world" */ './components/TheSection')
const TheConfigurationView = () => import(/* webpackChunkName: "ext-hello-world" */ './components/TheConfigurationView')

// set to true to see how an extension replaces a core route and its sidebar item
const OVERRIDE_EXAMPLE = false

// lazy registration of a temporary ($_) store module, unregistered on logout
const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_hello_world)
    store.registerModule('$_hello_world', helloWorldTemporaryStore)
  next()
}

export default {
  apiVersion: 1,

  routes: [
    // a new top-level view
    {
      path: '/hello',
      name: 'helloWorld',
      component: TheView,
      meta: {
        can: () => acl.$can('read', 'system')
      }
    },
    // under existing views, at any depth
    { parent: 'configuration', path: 'hello_world', name: 'helloWorldSection', component: TheSection },
    { parent: 'configuration', path: 'hello_world/settings', name: 'helloWorldSettings', component: TheConfigurationView, props: () => ({ title: i18n.t('Hello World Settings') }), beforeEnter },
    { parent: 'configuration', path: 'hello_world/integration', name: 'helloWorldIntegration', component: TheConfigurationView, props: () => ({ title: i18n.t('Hello World Integration') }), beforeEnter },
    { parent: '/configuration', path: 'pki/hello', name: 'helloWorldPki', component: TheConfigurationView, props: () => ({ title: i18n.t('Hello World PKI') }), beforeEnter },
    { parent: 'status', path: 'hello', name: 'statusHelloWorld', component: TheView, meta: { can: 'read system' } },
    // a static route goes before the dynamic siblings (Reports ':id(...)'), or use before/after a sibling
    { parent: 'reports', path: 'hello', name: 'reportsHelloWorld', component: TheView },
    // the same name and path as a core route: replaces it
    ...((OVERRIDE_EXAMPLE)
      ? [{ parent: 'configuration', path: 'kafka', name: 'kafka', component: TheConfigurationView, props: () => ({ title: i18n.t('Kafka (overridden)') }), beforeEnter }]
      : []
    )
  ],

  sidebar: {
    configuration: ({ i18n }) => ([
      // into an existing section, after an existing item
      { parent: '/configuration/integration', after: '/configuration/firewalls', item: { name: i18n.t('Hello World Integration'), path: '/configuration/hello_world/integration' } },
      // into an existing group (the untranslated group name) of an existing section
      { parent: '/configuration/integration', group: 'PKI', item: { name: i18n.t('Hello World PKI'), path: '/configuration/pki/hello' } },
      // a new section, before an existing one
      {
        before: '/configuration/system_configuration',
        item: {
          name: i18n.t('Hello World'),
          path: '/configuration/hello_world',
          icon: 'flask',
          collapsable: true,
          items: [
            { name: i18n.t('Settings'), path: '/configuration/hello_world/settings' }
          ]
        }
      },
      // the same path as a core item: replaces it
      ...((OVERRIDE_EXAMPLE)
        ? [{ item: { name: i18n.t('Kafka (overridden)'), path: '/configuration/kafka' } }]
        : []
      )
    ]),
    status: ({ i18n }) => ([
      { item: { name: i18n.t('Hello World'), path: '/status/hello', can: 'read system' } }
    ]),
    reports: ({ i18n }) => ([
      { item: { name: i18n.t('Hello World'), path: '/reports/hello' } }
    ])
  },

  navbar: [
    { name: 'Hello World', to: '/hello' }
  ],

  // global store module, must implement $RESET (called on logout)
  storeModules: {
    helloWorld: helloWorldStore
  },

  install (Vue) {
    Vue.prototype.$helloWorld = true
  }
}
