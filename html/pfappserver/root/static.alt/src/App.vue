<template>
  <div>
    <b-navbar toggleable="md" fixed="top" type="dark" class="navbar-expand-md bg-dark">
      <b-nav-toggle target="navbar"></b-nav-toggle>
      <b-navbar-brand>
        <img src="/static/img/packetfence.white.small.svg"/>
      </b-navbar-brand>
      <b-collapse is-nav id="navbar">
        <b-navbar-nav v-if="isAuthenticated">
          <b-nav-item to="/status" v-can:access.some="[['reports', 'services']]">{{ $t('Status') }}</b-nav-item>
          <b-nav-item to="/reports" v-can:access="'reports'">{{ $t('Reports') }}</b-nav-item>
          <b-nav-item to="/auditing" v-can:read="'auditing'">{{ $t('Auditing') }}</b-nav-item>
          <b-nav-item to="/nodes" v-can:read="'nodes'">{{ $t('Nodes') }}</b-nav-item>
          <b-nav-item to="/users" v-can:read="'users'">{{ $t('Users') }}</b-nav-item>
          <b-nav-item to="/configuration" v-can:read="'configuration_main'">{{ $t('Configuration') }}</b-nav-item>
        </b-navbar-nav>
        <div class="ml-auto"></div>
        <b-badge class="mr-1" v-if="debug" :variant="apiOK? 'success' : 'danger'">API</b-badge>
        <b-badge class="mr-1" v-if="debug" :variant="chartsOK? 'success' : 'danger'">dashboard</b-badge>
        <b-navbar-nav v-if="isAuthenticated">
          <b-nav-item-dropdown class="pf-label" right :text="username">
            <b-dropdown-item-button v-if="$i18n.locale == 'en'" @click="setLanguage('fr')">Français</b-dropdown-item-button>
            <b-dropdown-item-button v-else @click="setLanguage('en')">English</b-dropdown-item-button>
            <b-dropdown-divider></b-dropdown-divider>
            <b-dropdown-item to="/logout">{{ $t('Log out') }}</b-dropdown-item>
          </b-nav-item-dropdown>
        </b-navbar-nav>
      </b-collapse>
      <pf-notification-center :isAuthenticated="isAuthenticated" />
    </b-navbar>
    <b-container fluid class="pt-6">
      <router-view/>
    </b-container>
  </div>
</template>

<script>
import pfNotificationCenter from '@/components/pfNotificationCenter'

export default {
  name: 'app',
  components: {
    pfNotificationCenter
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
    username () {
      return this.$store.state.session.username
    },
    apiOK () {
      return this.$store.state.session.api
    },
    chartsOK () {
      return this.$store.state.session.charts
    }
  },
  methods: {
    setLanguage (lang) {
      this.$store.dispatch('session/setLanguage', { i18n: this.$i18n, lang })
    }
  },
  created () {
    this.$store.dispatch('session/setLanguage', { i18n: this.$i18n, lang: 'en' })
  }
}
</script>

<style src="./styles/global.scss" lang="scss"></style>
