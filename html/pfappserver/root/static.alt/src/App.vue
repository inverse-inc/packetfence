<template>
  <div>
    <b-navbar toggleable="md" fixed="top" type="dark" class="navbar-expand-md bg-dark">
      <b-nav-toggle target="navbar"></b-nav-toggle>
      <b-navbar-brand>
        <img src="/static/img/packetfence.white.small.svg"/>
      </b-navbar-brand>
      <b-collapse is-nav id="navbar">
        <b-navbar-nav v-if="isAuthenticated">
          <b-nav-item to="/status" v-can:read.some="[['reports', 'services']]">{{ $t('Status') }}</b-nav-item>
          <b-nav-item to="/reports" v-can:read="'reports'">{{ $t('Reports') }}</b-nav-item>
          <b-nav-item to="/auditing" v-can:read="'auditing'">{{ $t('Auditing') }}</b-nav-item>
          <b-nav-item to="/nodes" v-can:read="'nodes'">{{ $t('Nodes') }}</b-nav-item>
          <b-nav-item to="/users" v-can:read="'users'">{{ $t('Users') }}</b-nav-item>
          <b-nav-item to="/configuration" v-can:read="'configuration_main'">{{ $t('Configuration') }}</b-nav-item>
        </b-navbar-nav>
        <div class="ml-auto"></div>
        <b-badge class="mr-1" v-if="debug" :variant="apiOK? 'success' : 'danger'">API</b-badge>
        <b-badge class="mr-1" v-if="debug" :variant="chartsOK? 'success' : 'danger'">dashboard</b-badge>
        <b-navbar-nav v-if="isAuthenticated">
          <b-nav-item-dropdown class="pf-label" right>
            <template slot="button-content">
              <icon name="user-circle"></icon> {{ username }} <span v-if="pfVersion">(v{{ pfVersion }})</span>
            </template>
            <b-dropdown-item-button v-if="$i18n.locale == 'en'" @click="setLanguage('fr')">Français</b-dropdown-item-button>
            <b-dropdown-item-button v-else @click="setLanguage('en')">English</b-dropdown-item-button>
            <b-dropdown-divider></b-dropdown-divider>
            <b-dropdown-item to="/logout">{{ $t('Log out') }}</b-dropdown-item>
          </b-nav-item-dropdown>
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
          </b-nav-item-dropdown>
        </b-navbar-nav>
      </b-collapse>
      <pf-notification-center :isAuthenticated="isAuthenticated" />
    </b-navbar>
    <pf-progress-api></pf-progress-api>
    <b-container fluid class="pt-6">
      <router-view/>
    </b-container>
  </div>
</template>

<script>
import IconCounter from '@/components/IconCounter'
import pfNotificationCenter from '@/components/pfNotificationCenter'
import pfProgressApi from '@/components/pfProgressApi'

export default {
  name: 'app',
  components: {
    IconCounter,
    pfNotificationCenter,
    pfProgressApi
  },
  data () {
    return {
      debug: process.env.VUE_APP_DEBUG
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
    username () {
      return this.$store.state.session.username
    },
    apiOK () {
      return this.$store.state.session.api
    },
    chartsOK () {
      return this.$store.state.session.charts
    },
    pfVersion () {
      return this.$store.getters['system/version']
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
      this.$store.dispatch('session/setLanguage', { i18n: this.$i18n, lang })
    }
  },
  created () {
    this.$store.dispatch('session/setLanguage', { i18n: this.$i18n, lang: 'en' })
    this.$store.dispatch('system/getSummary')
  }
}
</script>

<style src="./styles/global.scss" lang="scss"></style>
