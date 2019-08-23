<template>
  <div>
    <b-navbar toggleable="md" fixed="top" type="dark" class="navbar-expand-md bg-dark" :class="{ 'alert-danger': readonlyMode }">
      <b-nav-toggle target="navbar"></b-nav-toggle>
      <b-navbar-brand>
        <img src="/static/img/packetfence.white.small.svg"/>
      </b-navbar-brand>
      <b-collapse is-nav id="navbar">
        <b-navbar-nav v-show="isAuthenticated">
          <b-nav-item v-b-tooltip.hover.bottom.d300 title="Alt + Shift + S" to="/status" :active="$route.path.startsWith('/status')" v-can:read.some="[['reports', 'services']]">{{ $t('Status') }}</b-nav-item>
          <b-nav-item v-b-tooltip.hover.bottom.d300 title="Alt + Shift + R" to="/reports" :active="$route.path.startsWith('/report')" v-can:read="'reports'">{{ $t('Reports') }}</b-nav-item>
          <b-nav-item v-b-tooltip.hover.bottom.d300 title="Alt + Shift + A" to="/auditing" :active="$route.path.startsWith('/auditing')" v-can:read.some="[['radius_log', 'dhcp_option_82', 'dns_log']]">{{ $t('Auditing') }}</b-nav-item>
          <b-nav-item v-b-tooltip.hover.bottom.d300 title="Alt + Shift + N" to="/nodes" :active="$route.path.startsWith('/node')" v-can:read="'nodes'">{{ $t('Nodes') }}</b-nav-item>
          <b-nav-item v-b-tooltip.hover.bottom.d300 title="Alt + Shift + U" to="/users" :active="$route.path.startsWith('/user')" v-can:read="'users'">{{ $t('Users') }}</b-nav-item>
          <b-nav-item v-b-tooltip.hover.bottom.d300 title="Alt + Shift + C" to="/configuration" :active="$route.path.startsWith('/configuration')" v-can:read="'configuration_main'">{{ $t('Configuration') }}</b-nav-item>
        </b-navbar-nav>
        <div class="ml-auto"></div>
        <b-badge class="mr-1" v-if="debug" :variant="apiOK? 'success' : 'danger'">API</b-badge>
        <b-badge class="mr-1" v-if="debug" :variant="chartsOK? 'success' : 'danger'">dashboard</b-badge>
        <b-navbar-nav v-show="isAuthenticated">
          <b-nav-item-dropdown class="pf-label" right>
            <template slot="button-content">
              <icon name="user-circle"></icon> {{ username }}
            </template>
            <b-dropdown-item-button v-if="$i18n.locale == 'en'" @click="setLanguage('fr')">Français</b-dropdown-item-button>
            <b-dropdown-item-button v-else @click="setLanguage('en')">English</b-dropdown-item-button>
            <b-dropdown-divider></b-dropdown-divider>
            <b-dropdown-item to="/logout">{{ $t('Log out') }}</b-dropdown-item>
          </b-nav-item-dropdown>
          <b-nav-item @click="toggleDocumentationViewer" :active="showDocumentationViewer" v-b-tooltip.hover.bottom.d300 title="Alt + Shift + H">
            <icon name="info-circle"></icon>
          </b-nav-item>
          <b-nav-item-dropdown class="pf-label" right no-caret>
            <template slot="button-content">
              <icon-counter name="tools" v-model="isProcessing" variant="bg-dark">
                <icon name="circle-notch" spin>
              </icon-counter>
            </template>
            <b-dropdown-item-button @click="checkup" :disabled="isPerfomingCheckup">
              {{ $t('Perform Checkup') }} <icon class="ml-2" name="circle-notch" spin v-if="isPerfomingCheckup"></icon>
            </b-dropdown-item-button>
            <b-dropdown-item-button @click="fixPermissions" :disabled="isFixingPermissions">
              {{ $t('Fix Permissions') }} <icon class="ml-2" name="circle-notch" spin v-if="isFixingPermissions"></icon>
            </b-dropdown-item-button>
            <b-dropdown-divider></b-dropdown-divider>
            <b-dropdown-item href="/admin/status" target="_blank">{{ $t('Switch to Old Admin') }}</b-dropdown-item>
          </b-nav-item-dropdown>
        </b-navbar-nav>
        <pf-notification-center :isAuthenticated="isAuthenticated" />
      </b-collapse>
    </b-navbar>
    <pf-progress-api></pf-progress-api>
    <!-- Show alert if the database is in read-only mode -->
    <b-container v-if="readonlyMode" class="bg-danger text-white text-center pt-6" fluid>
      <icon class="pr-2" name="lock"></icon> {{ $t('The database is in readonly mode. Not all functionality is available.') }}
    </b-container>
    <b-container :class="[{ 'pt-6': !readonlyMode, 'pf-documentation-container': isAuthenticated }, documentationViewerClass]" fluid>
      <pf-documentation v-show="isAuthenticated">
        <div class="py-1 pl-3" v-show="version">
          <b-form-text v-t="'Packetfence Version'"/> {{ version }}
        </div>
        <div class="py-1 pl-3" v-show="hostname">
          <b-form-text v-t="'Server Hostname'"/> {{ hostname }}
        </div>
      </pf-documentation>
      <router-view/>
    </b-container>
    <!-- Show login form if session expires -->
    <pf-form-login modal></pf-form-login>
  </div>
</template>

<script>
import IconCounter from '@/components/IconCounter'
import pfDocumentation from '@/components/pfDocumentation'
import pfFormLogin from '@/components/pfFormLogin'
import pfNotificationCenter from '@/components/pfNotificationCenter'
import pfProgressApi from '@/components/pfProgressApi'

export default {
  name: 'app',
  components: {
    IconCounter,
    pfDocumentation,
    pfFormLogin,
    pfNotificationCenter,
    pfProgressApi
  },
  data () {
    return {
      debug: process.env.VUE_APP_DEBUG,
      documentationViewerClass: null
    }
  },
  computed: {
    isAuthenticated () {
      return this.$store.getters['session/isAuthenticated']
    },
    isPerfomingCheckup () {
      return this.$store.getters['config/isLoadingCheckup']
    },
    isFixingPermissions () {
      return this.$store.getters['config/isLoadingFixPermissions']
    },
    isProcessing () {
      return (this.isPerfomingCheckup || this.isFixingPermissions) ? 1 : 0
    },
    readonlyMode () {
      return this.$store.state.system.readonlyMode
    },
    username () {
      return this.$store.state.session.username
    },
    apiOK () {
      return this.$store.state.session.api
    },
    chartsOK () {
      return this.$store.state.session.charts
    },
    altShiftAKey () {
      return this.$store.getters['events/altShiftAKey'] && (this.$can('read', 'radius_log') || this.$can('read', 'dhcp_option_82') || this.$can('read', 'dns_log'))
    },
    altShiftCKey () {
      return this.$store.getters['events/altShiftCKey'] && this.$can('read', 'configuration_main')
    },
    altShiftHKey () {
      return this.$store.getters['events/altShiftHKey']
    },
    altShiftNKey () {
      return this.$store.getters['events/altShiftNKey'] && this.$can('read', 'nodes')
    },
    altShiftRKey () {
      return this.$store.getters['events/altShiftRKey'] && this.$can('read', 'reports')
    },
    altShiftSKey () {
      return this.$store.getters['events/altShiftSKey'] && (this.$can('read', 'reports') || this.$can('read', 'services'))
    },
    altShiftUKey () {
      return this.$store.getters['events/altShiftUKey'] && this.$can('read', 'users')
    },
    version () {
      return this.$store.getters['system/version']
    },
    hostname () {
      return this.$store.getters['system/hostname']
    },
    showDocumentationViewer () {
      return this.$store.getters['documentation/showViewer']
    }
  },
  methods: {
    checkup () {
      this.$store.dispatch('config/checkup').then(items => {
        items.forEach(item => {
          let level
          switch (item.severity) {
            case 'WARNING':
              level = 'warning'
              break
            case 'FATAL':
              level = 'danger'
              break
            default:
              level = 'info'
          }
          this.$store.dispatch(`notification/${level}`, item.message)
        })
      })
    },
    fixPermissions () {
      this.$store.dispatch('config/fixPermissions').then(data => {
        this.$store.dispatch('notification/info', data.message)
      })
    },
    setLanguage (lang) {
      this.$store.dispatch('session/setLanguage', { lang })
    },
    toggleDocumentationViewer () {
      this.$store.dispatch('documentation/toggleViewer')
    }
  },
  created () {
    this.$store.dispatch('session/setLanguage', { lang: 'en' })
  },
  watch: {
    altShiftAKey (pressed) {
      if (pressed) this.$router.push('/auditing')
    },
    altShiftCKey (pressed) {
      if (pressed) this.$router.push('/configuration')
    },
    altShiftHKey (pressed) {
      if (pressed) this.$store.dispatch('documentation/toggleViewer')
    },
    altShiftNKey (pressed) {
      if (pressed) this.$router.push('/nodes')
    },
    altShiftRKey (pressed) {
      if (pressed) this.$router.push('/reports')
    },
    altShiftSKey (pressed) {
      if (pressed) this.$router.push('/status')
    },
    altShiftUKey (pressed) {
      if (pressed) this.$router.push('/users')
    },
    showDocumentationViewer: function (a, b) {
      if (a) { // shown
        this.documentationViewerClass = 'pf-documentation-enter'
      } else {
        this.documentationViewerClass = 'pf-documentation-leave'
        setTimeout(() => {
          this.documentationViewerClass = null
        }, 300) // match the animation duration defined in pfDocumentation.vue
      }
    }
  }
}
</script>

<style src="./styles/global.scss" lang="scss"></style>
