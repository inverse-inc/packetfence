<template>
  <div>
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
          <b-badge class="mr-1" v-if="debug" :variant="apiOK === true? 'success' : apiOK === false? 'danger' : 'warning'">API</b-badge>
          <b-badge class="mr-1" v-if="debug" :variant="chartsOK === true? 'success' : chartsOK === false? 'danger' : 'warning'">dashboard</b-badge>
        </b-nav-text>
        <b-navbar-nav v-show="isConfiguratorActive" class="pl-2">
          <b-nav-item-dropdown right no-caret>
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
            <b-dropdown-item-button v-if="$i18n.locale == 'en'" @click="setLanguage('fr')">Français</b-dropdown-item-button>
            <b-dropdown-item-button v-else @click="setLanguage('en')">English</b-dropdown-item-button>
            <b-dropdown-divider></b-dropdown-divider>
            <b-dropdown-item to="/logout">{{ $t('Log out') }}</b-dropdown-item>
          </b-nav-item-dropdown>
          <b-nav-item-dropdown right v-if="tenant && tenant.id === 0">
            <template v-slot:button-content>
              <icon name="layer-group"></icon> {{ tenant_mask_name }}
            </template>
            <b-dropdown-header>{{ $t('Tenants') }}</b-dropdown-header>
            <b-dropdown-item-button v-for="tenant in tenants" :key="tenant.id"
              :active="+tenant_id_mask === +tenant.id"
              :disabled="+tenant_id_mask === 0 && +tenant.id === 0"
              @click="setTenantIdMask(tenant.id)"
            >{{ tenant.name }}</b-dropdown-item-button>
          </b-nav-item-dropdown>
          <b-nav-text v-else-if="tenant">
            <icon name="layer-group"></icon> {{ tenant.name }}
          </b-nav-text>
          <b-nav-item @click="toggleDocumentationViewer" :active="showDocumentationViewer" v-b-tooltip.hover.bottom.d300 title="Alt + Shift + H">
            <icon name="question-circle"></icon>
          </b-nav-item>
          <b-nav-item-dropdown right no-caret>
            <template v-slot:button-content>
              <icon-counter name="tools" v-model="isProcessing" variant="bg-dark">
                <icon name="circle-notch" spin></icon>
              </icon-counter>
            </template>
            <b-dropdown-item-button @click="checkup" :disabled="isPerfomingCheckup">
              {{ $t('Perform Checkup') }} <icon class="ml-2" name="circle-notch" spin v-if="isPerfomingCheckup"></icon>
            </b-dropdown-item-button>
            <b-dropdown-item-button @click="fixPermissions" :disabled="isFixingPermissions">
              {{ $t('Fix Permissions') }} <icon class="ml-2" name="circle-notch" spin v-if="isFixingPermissions"></icon>
            </b-dropdown-item-button>
          </b-nav-item-dropdown>
        </b-navbar-nav>
        <pf-notification-center :isAuthenticated="isAuthenticated || isConfiguratorActive" />
      </b-collapse>
    </b-navbar>
    <pf-progress-api/>
    <!-- Show alert if the database is in read-only mode and/or the configurator is enabled -->
    <b-container v-if="warnings.length > 0" class="bg-danger text-white text-center pt-6" fluid>
      <div class="py-2" v-for="(warning, index) in warnings" :key="index">
        <icon class="pr-2" :name="warning.icon"></icon> {{ warning.message }}
        <b-button v-if="warning.to" size="sm" variant="outline-light" class="ml-2" :to="warning.to">{{ warning.toLabel }}</b-button>
      </div>
    </b-container>
    <b-container :class="[{ 'pt-6': warnings.length === 0, 'pf-documentation-container': isAuthenticated }, documentationViewerClass]" fluid>
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
    isConfiguratorActive () {
      return this.$store.state.session.configuratorActive
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
    warnings () {
      const warnings = []
      if (this.$store.getters['system/readonlyMode']) {
        warnings.push({
          icon: 'lock',
          message: this.$i18n.t('The database is in readonly mode. Not all functionality is available.')
        })
      }
      if (this.$store.getters['session/configuratorEnabled']) {
        warnings.push({
          icon: 'door-open',
          message: this.$i18n.t('The configurator is enabled. You should disable it if your PacketFence configuration is completed.'),
          to: '/configuration/advanced',
          toLabel: this.$i18n.t('Go to configuration')
        })
      }
      return warnings
    },
    username () {
      return this.$store.state.session.username
    },
    tenant () {
      return this.$store.state.session.tenant
    },
    tenant_id_mask () {
      return this.$store.getters['session/tenantIdMask']
    },
    tenant_mask_name () {
      const tenant = this.tenants.find(tenant => {
        return +tenant.id === +this.tenant_id_mask
      })
      const { name } = tenant || {}
      return name || this.$i18n.t('Unknown')
    },
    tenants () {
      return this.$store.state.session.tenants
    },
    apiOK () {
      return this.$store.state.session.api
    },
    chartsOK () {
      return this.$store.state.session.charts
    },
    altShiftAKey () {
      return this.$store.getters['events/altShiftAKey']
    },
    altShiftCKey () {
      return this.$store.getters['events/altShiftCKey']
    },
    altShiftHKey () {
      return this.$store.getters['events/altShiftHKey']
    },
    altShiftNKey () {
      return this.$store.getters['events/altShiftNKey']
    },
    altShiftRKey () {
      return this.$store.getters['events/altShiftRKey']
    },
    altShiftSKey () {
      return this.$store.getters['events/altShiftSKey']
    },
    altShiftUKey () {
      return this.$store.getters['events/altShiftUKey']
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
    // show nav links conditionally,
    //  instead of using redundant "v-can"
    //  we utilize the routes meta can instead.
    canRoute (path) {
      const { options: { routes } = {} } = this.$router
      let route = routes.find(route => route.path === path)
      if (route) {
        const { meta: { can = () => false } = {} } = route
        if (can.constructor === Function) {
          return can()
        }
        const [ verb, action ] = can.spit(' ')
        return this.$can(verb, action)
      }
      return false
    },
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
    },
    setTenantIdMask (tenant_id) {
      if (tenant_id === this.tenant_id_mask) {
        this.$store.dispatch('session/setTenantIdMask', this.tenant.id) // reset to default
      }
      else {
        this.$store.dispatch('session/setTenantIdMask', tenant_id)
      }
      this.$router.push('/reset') // reset
    }
  },
  created () {
    let lang = window.navigator.language.split(/-/)[0]
    if (!['en', 'fr'].includes(lang)) {
      lang = 'en'
    }
    this.$store.dispatch('session/setLanguage', { lang })
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
    showDocumentationViewer: function (a) {
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
