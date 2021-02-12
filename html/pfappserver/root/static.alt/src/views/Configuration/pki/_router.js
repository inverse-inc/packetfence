import store from '@/store'
import StoreModule from './_store'

const TheTabs = () => import(/* webpackChunkName: "Configuration" */ '../_components/PkisTabs')
const PkiCaView = () => import(/* webpackChunkName: "Configuration" */ './cas/_components/TheView')
const PkiProfileView = () => import(/* webpackChunkName: "Configuration" */ './profiles/_components/TheView')
const PkiCertView = () => import(/* webpackChunkName: "Configuration" */ './certs/_components/TheView')
const PkiRevokedCertView = () => import(/* webpackChunkName: "Configuration" */ './revokedCerts/_components/TheView')

export const beforeEnter = (to, from, next = () => {}) => {
  if (!store.state.$_pkis)
    store.registerModule('$_pkis', StoreModule)
  next()
}

export default [
  {
    path: 'pki',
    name: 'pki',
    component: TheTabs,
    props: (route) => ({ tab: 'pkiCas', query: route.query.query }),
    beforeEnter
  },
  {
    path: 'pki/cas',
    name: 'pkiCas',
    component: TheTabs,
    props: (route) => ({ tab: 'pkiCas', query: route.query.query }),
    beforeEnter
  },
  {
    path: 'pki/cas/new',
    name: 'newPkiCa',
    component: PkiCaView,
    props: () => ({ isNew: true }),
    beforeEnter
  },
  {
    path: 'pki/ca/:id',
    name: 'pkiCa',
    component: PkiCaView,
    props: (route) => ({ id: String(route.params.id).toString() }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_pkis/getCa', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'pki/ca/:id/clone',
    name: 'clonePkiCa',
    component: PkiCaView,
    props: (route) => ({ id: String(route.params.id).toString(), isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_pkis/getCa', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'pki/profiles',
    name: 'pkiProfiles',
    component: TheTabs,
    props: (route) => ({ tab: 'pkiProfiles', query: route.query.query }),
    beforeEnter
  },
  {
    path: 'pki/ca/:ca_id/profiles/new',
    name: 'newPkiProfile',
    component: PkiProfileView,
    props: (route) => ({ ca_id: String(route.params.ca_id).toString(), isNew: true }),
    beforeEnter
  },
  {
    path: 'pki/profile/:id',
    name: 'pkiProfile',
    component: PkiProfileView,
    props: (route) => ({ id: String(route.params.id).toString() }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_pkis/getProfile', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'pki/profile/:id/clone',
    name: 'clonePkiProfile',
    component: PkiProfileView,
    props: (route) => ({ id: String(route.params.id).toString(), isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_pkis/getProfile', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'pki/certs',
    name: 'pkiCerts',
    component: TheTabs,
    props: (route) => ({ tab: 'pkiCerts', query: route.query.query }),
    beforeEnter
  },
  {
    path: 'pki/profile/:profile_id/certs/new',
    name: 'newPkiCert',
    component: PkiCertView,
    props: (route) => ({ profile_id: String(route.params.profile_id).toString(), isNew: true }),
    beforeEnter
  },
  {
    path: 'pki/cert/:id',
    name: 'pkiCert',
    component: PkiCertView,
    props: (route) => ({ id: String(route.params.id).toString() }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_pkis/getCert', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'pki/cert/:id/clone',
    name: 'clonePkiCert',
    component: PkiCertView,
    props: (route) => ({ id: String(route.params.id).toString(), isClone: true }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_pkis/getCert', to.params.id).then(() => {
        next()
      })
    }
  },
  {
    path: 'pki/revokedcerts',
    name: 'pkiRevokedCerts',
    component: TheTabs,
    props: (route) => ({ tab: 'pkiRevokedCerts', query: route.query.query }),
    beforeEnter
  },
  {
    path: 'pki/revokedcert/:id',
    name: 'pkiRevokedCert',
    component: PkiRevokedCertView,
    props: (route) => ({ id: String(route.params.id).toString() }),
    beforeEnter: (to, from, next) => {
      beforeEnter()
      store.dispatch('$_pkis/getRevokedCert', to.params.id).then(() => {
        next()
      })
    }
  }
]
