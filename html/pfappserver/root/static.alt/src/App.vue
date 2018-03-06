<template>
  <div>
    <b-navbar toggleable="md" fixed="top" type="dark" class="navbar-expand-md bg-dark">
      <b-nav-toggle target="navbar"></b-nav-toggle>
      <b-navbar-brand>
        <img src="/static/img/packetfence.white.small.svg"/>
      </b-navbar-brand>
      <b-collapse is-nav id="navbar" v-if="isAuthenticated">
        <b-navbar-nav>
          <b-nav-item to="/status" v-can:access.some="[['reports', 'services']]">{{ $t('Status') }}</b-nav-item>
          <b-nav-item href="#" v-can:access="'reports'">{{ $t('Reports') }}</b-nav-item>
          <b-nav-item to="/nodes" v-can:read="'nodes'">{{ $t('Nodes') }}</b-nav-item>
          <b-nav-item to="/users" v-can:read="'users'">{{ $t('Users') }}</b-nav-item>
          <b-nav-item href="#" v-can:read="'configuration_main'">{{ $t('Configuration') }}</b-nav-item>
        </b-navbar-nav>
      </b-collapse>
      <b-badge class="mr-1" :variant="apiOK? 'success' : 'danger'">API</b-badge>
      <b-badge class="mr-1" :variant="chartsOK? 'success' : 'danger'">dashboard</b-badge>
      <b-navbar-nav right v-if="isAuthenticated">        
        <b-nav-item-dropdown right :text="username">
          <b-dropdown-item to="/logout">{{ $t('Log out') }}</b-dropdown-item>
        </b-nav-item-dropdown>
      </b-navbar-nav>
    </b-navbar>
    <b-container fluid class="mt-5 pt-3">
      <router-view/>
    </b-container>
  </div>
</template>

<script>
export default {
  name: 'App',
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
  created () {
    let token = this.$store.state.session.token
    if (token) {
      // Validate token by fetching token info
      this.$store.dispatch('session/update', token)
    } else {
      // No token -- go back to login
      this.$router.push('/')
    }
  }
}
</script>

<style src="./styles/global.scss" lang="scss"></style>