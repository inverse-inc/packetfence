<template>
  <div :class="{ 'w-saas': isSaas, 'wo-saas': !isSaas }">
    <b-navbar toggleable="md" fixed="top" type="dark" class="navbar-expand-md bg-dark" :class="{ 'alert-danger': warnings.length > 0 }">
      <b-nav-toggle target="navbar"></b-nav-toggle>
      <b-navbar-brand>
        <img src="@/assets/packetfence.white.small.svg"/>
      </b-navbar-brand>
      <b-collapse is-nav id="navbar">
        <b-navbar-nav v-show="isAuthenticated">
          <b-nav-item v-b-tooltip.hover.bottom.d300 title="Alt + Shift + S" to="/status" :active="$route.path.startsWith('/status')" v-if="canRoute('/status')">{{ $t('Status') }}</b-nav-item>
          <b-nav-item v-b-tooltip.hover.bottom.d300 title="Alt + Shift + R" to="/reports" :active="$route.path.startsWith('/report')" v-if="canRoute('/reports')">{{ $t('Reports') }}</b-nav-item>
          <b-nav-item v-b-tooltip.hover.bottom.d300 title="Alt + Shift + A" to="/auditing" :active="$route.path.startsWith('/auditing')"  v-if="canRoute('/auditing')">{{ $t('Auditing') }}</b-nav-item>
          <b-nav-item v-b-tooltip.hover.bottom.d300 title="Alt + Shift + N" to="/nodes" :active="$route.path.startsWith('/node')" v-if="canRoute('/nodes')">{{ $t('Nodes') }}</b-nav-item>
          <b-nav-item v-b-tooltip.hover.bottom.d300 title="Alt + Shift + U" to="/users" :active="$route.path.startsWith('/user')" v-if="canRoute('/users')">{{ $t('Users') }}</b-nav-item>
          <b-nav-item v-b-tooltip.hover.bottom.d300 title="Alt + Shift + C" to="/configuration" :active="$route.path.startsWith('/configuration')" v-if="canRoute('/configuration')">{{ $t('Configuration') }}</b-nav-item>
        </b-navbar-nav>
        <b-nav-text class="ml-auto">
          <b-badge class="mr-1" v-if="isDebug" :variant="apiOK === true? 'success' : apiOK === false? 'danger' : 'warning'">API</b-badge>
          <b-badge class="mr-1" v-if="isDebug" :variant="chartsOK === true? 'success' : chartsOK === false? 'danger' : 'warning'">dashboard</b-badge>
        </b-nav-text>
        <b-navbar-nav v-show="isConfiguratorActive" class="pl-2">
          <b-nav-item-dropdown right no-caret v-if="isDebug">
            <template v-slot:button-content>
              <icon name="ellipsis-v"></icon>
            </template>
            <b-dropdown-item-button v-if="$i18n.locale == 'en'" @click="setLanguage('fr')">Français</b-dropdown-item-button>
            <b-dropdown-item-button v-else @click="setLanguage('en')">English</b-dropdown-item-button>
            <b-dropdown-divider></b-dropdown-divider>
            <b-dropdown-item to="/login">{{ $t('Login to Administration') }}</b-dropdown-item>
          </b-nav-item-dropdown>
        </b-navbar-nav>
        <b-navbar-nav v-show="isAuthenticated">
          <b-nav-item-dropdown right>
            <template v-slot:button-content>
              <icon name="user-circle"></icon> {{ username }}
            </template>
            <b-dropdown-item-button v-if="isDebug && $i18n.locale == 'en'" @click="setLanguage('fr')">Français</b-dropdown-item-button>
            <b-dropdown-item-button v-else-if="isDebug" @click="setLanguage('en')">English</b-dropdown-item-button>
            <b-dropdown-item to="/preferences">{{ $t('Preferences') }}</b-dropdown-item>
            <b-dropdown-divider></b-dropdown-divider>
            <b-dropdown-item to="/logout">{{ $t('Log out') }}</b-dropdown-item>
          </b-nav-item-dropdown>
          <b-nav-item @click="toggleDocumentationViewer" :active="showDocumentationViewer" v-b-tooltip.hover.bottom.d300 title="Alt + Shift + H">
            <icon name="question-circle"></icon>
          </b-nav-item>
        </b-navbar-nav>
        <app-notifications :isAuthenticated="isAuthenticated || isConfiguratorActive" />
      </b-collapse>
    </b-navbar>
    <app-api-progress />
    <!-- Show alert if the database is in read-only mode and/or the configurator is enabled -->
    <b-container v-if="warnings.length > 0" class="bg-danger text-white text-center pt-6" fluid>
      <div class="py-2" v-for="(warning, index) in warnings" :key="index">
        <icon class="pr-2" :name="warning.icon"></icon> {{ warning.message }}
        <b-button v-if="warning.to" size="sm" variant="outline-light" class="ml-2" :to="warning.to">{{ warning.toLabel }}</b-button>
      </div>
    </b-container>
    <b-container :class="[{ 'pt-6': warnings.length === 0, 'documentation-container': isAuthenticated }, documentationViewerClass]" fluid>
      <app-documentation v-show="isAuthenticated">
        <div class="py-1 pl-3" v-show="version">
          <b-form-text v-t="'Packetfence Version'"/> {{ version }}
        </div>
        <div class="py-1 pl-3" v-show="gitCommitId">
          <b-form-text v-t="'GIT Commit ID'"/> <b-link :href="`https://github.com/inverse-inc/packetfence/commit/${gitCommitId}`" target="_blank">{{ gitCommitId }}</b-link>
        </div>
        <div class="py-1 pl-3" v-show="hostname">
          <b-form-text v-t="'Server Hostname'"/> {{ hostname }}
        </div>
      </app-documentation>
    </b-container>
    <!-- Router -->
    <router-view data-router-view="true" class="px-3" />
    <!-- Show login if session expires -->
    <app-login modal />
    <!-- Show notifications late in DOM for z-index above b-modal -->
    <app-notification-toasts />
  </div>
</template>

<script>
import AppApiProgress from '@/components/AppApiProgress'
import AppDocumentation from '@/components/AppDocumentation'
import AppLogin from '@/components/AppLogin'
import AppNotifications from '@/components/AppNotifications'
import AppNotificationToasts from '@/components/AppNotificationToasts'
import IconCounter from '@/components/IconCounter'

const components = {
  AppApiProgress,
  AppDocumentation,
  AppLogin,
  AppNotifications,
  AppNotificationToasts,
  IconCounter
}

import { computed, ref, watch } from '@vue/composition-api'
import useEvent from '@/composables/useEvent'
import i18n from '@/utils/locale'

const setup = (props, context) => {

  const { root: { $can, $router, $store } = {} } = context

  const isDebug = process.env.VUE_APP_DEBUG === 'true'
  const isSaas = computed(() => $store.getters['system/isSaas'])

  const documentationViewerClass = ref(null)
  const showDocumentationViewer = computed(() => $store.getters['documentation/showViewer'])
  watch(showDocumentationViewer, (a) => {
    if (a) // shown
      documentationViewerClass.value = 'documentation-enter'
    else {
      documentationViewerClass.value = 'documentation-leave'
      setTimeout(() => {
        documentationViewerClass.value = null
      }, 300) // match the animation duration defined in pfDocumentation.vue
    }
  })
  const toggleDocumentationViewer = () => {
    $store.dispatch('documentation/toggleViewer')
  }

  const isAuthenticated = computed(() => $store.getters['session/isAuthenticated'])
  const isConfiguratorActive = computed(() => $store.state.session.configuratorActive)
  const warnings = computed(() => {
    let warnings = []
    if ($store.getters['system/readonlyMode']) {
      warnings.push({
        icon: 'lock',
        message: i18n.t('The database is in readonly mode. Not all functionality is available.')
      })
    }
    if ($store.getters['session/configuratorEnabled']) {
      warnings.push({
        icon: 'door-open',
        message: i18n.t('The configurator is enabled. You should disable it if your PacketFence configuration is completed.'),
        to: '/configuration/advanced',
        toLabel: i18n.t('Go to configuration')
      })
    }
    return warnings
  })

  const apiOK = computed(() => $store.state.session.api)
  const chartsOK = computed(() => $store.state.session.charts)
  const gitCommitId = computed(() => $store.getters['system/git_commit_id'])
  const hostname = computed(() => $store.getters['system/hostname'])
  const username = computed(() => $store.state.session.username)
  const version = computed(() => $store.getters['system/version'])

  // show nav links conditionally,
  //  instead of using redundant "v-can"
  //  we utilize the routes meta can instead.
  const canRoute = (path) => {
    const { options: { routes } = {} } = $router
    let route = routes.find(route => route.path === path)
    if (route) {
      const { meta: { can = () => false } = {} } = route
      if (can.constructor === Function)
        return can()
      const [ verb, action ] = can.spit(' ')
      return $can(verb, action)
    }
    return false
  }

  const setLanguage = lang => {
    $store.dispatch('session/setLanguage', { lang })
  }

  // get navigator language
  let navigatorLanguage = window.navigator.language.split(/-/)[0]
  if (!['en', 'fr'].includes(navigatorLanguage))
    navigatorLanguage = 'en'

  // load language from user preferences
  const settings = ref({ language: navigatorLanguage })
  const token = computed(() => $store.state.session.token)
  watch(token, () => {
    if (!token.value)
      return setLanguage(navigatorLanguage)
    $store.dispatch('preferences/get', 'settings')
      .then(() => {
        settings.value = $store.state.preferences.cache['settings'] || { language: navigatorLanguage }
      })
      .finally(() => {
        const { language } = settings.value
        if (language)
          setLanguage(language)
        else
          setLanguage(navigatorLanguage)
      })
  }, { immediate: true })

  useEvent('keydown', e => {
    const { altKey = false, shiftKey = false, keyCode = false } = e
    if (altKey && shiftKey) {
      switch (true) {
        case keyCode === 65 && canRoute('/auditing'): // A
          e.preventDefault()
          $router.push('/auditing')
            .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
          break
        case keyCode === 67 && canRoute('/configuration'): // C
          e.preventDefault()
          $router.push('/configuration')
            .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
          break
        case keyCode === 72: // H
          e.preventDefault()
          $store.dispatch('documentation/toggleViewer')
            .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
          break
        case keyCode === 78 && canRoute('/nodes'): // N
          e.preventDefault()
          $router.push('/nodes')
            .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
          break
        case keyCode === 82 && canRoute('/reports'): // R
          e.preventDefault()
          $router.push('/reports')
            .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
          break
        case keyCode === 83 && canRoute('/status'): // S
          e.preventDefault()
          $router.push('/status')
            .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
          break
        case keyCode === 85 && canRoute('/users'): // U
          e.preventDefault()
          $router.push('/users')
            .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
          break
        default:
          break
      }
    }
  })

  return {
    isDebug,
    isSaas,
    isAuthenticated,
    isConfiguratorActive,
    warnings,
    canRoute,
    apiOK,
    chartsOK,
    gitCommitId,
    hostname,
    username,
    version,

    // user preferences
    settings,
    setLanguage,

    // documentation
    documentationViewerClass,
    showDocumentationViewer,
    toggleDocumentationViewer,
  }
}

// @vue/component
export default {
  name: 'app',
  inheritAttrs: false,
  components,
  setup
}
</script>

<style src="./styles/global.scss" lang="scss"></style>
