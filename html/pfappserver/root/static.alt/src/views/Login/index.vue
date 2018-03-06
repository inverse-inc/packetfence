<template>
    <b-row class="justify-content-md-center mt-3">
        <b-col md="8" lg="6" xl="4">
            <b-form v-on:submit.prevent="login">
                <b-card no-body>
                    <b-card-header v-t="'Login to PacketFence Administration'"></b-card-header>
                    <b-card-body>
                        <b-alert :variant="message.level" :show="message.text">
                            {{ $t(message.text) }}
                        </b-alert>
                        <b-form-group :label="$t('Username')" label-for="username" horizontal>
                            <b-form-input id="username" ref="username" type="text" v-model="username" required></b-form-input>
                        </b-form-group>
                        <b-form-group :label="$t('Password')" label-for="password" horizontal>
                            <b-form-input id="password" type="password" v-model="password" required></b-form-input>
                        </b-form-group>
                    </b-card-body>
                    <b-card-footer>
                        <b-row align-h="end">
                            <b-col cols="9">
                                <b-button type="submit" variant="outline-primary" :disabled="!validForm">{{ $t('Login') }}</b-button>
                            </b-col>
                       </b-row>
                    </b-card-footer>
                </b-card>
            </b-form>
        </b-col>
    </b-row>
</template>

<script>
import store from './_store'

export default {
  name: 'Login',
  data () {
    return {
      username: '',
      password: '',
      submitted: false,
      message: {}
    }
  },
  computed: {
    validForm () {
      return this.username.length > 0 && this.password.length > 0 && !this.$store.getters['$_auth/isLoading']
    }
  },
  created () {
    // Register store module only once
    if (!this.$store.state.$_auth) {
      this.$store.registerModule('$_auth', store)
    }
  },
  mounted () {
    if (this.$route.path === '/logout') {
      this.$store.dispatch('$_auth/logout').then(() => {
        this.message = { level: 'success', text: 'You have logged out' }
      })
    } else if (this.$route.path === '/expire') {
      this.$store.dispatch('$_auth/logout').then(() => {
        this.message = { level: 'warning', text: 'Your session has expired' }
      })
    }
    this.$refs.username.focus()
  },
  methods: {
    login (event) {
      this.submitted = true
      this.message = false
      this.$store.dispatch('$_auth/login', { username: this.username, password: this.password }).then(response => {
        this.$router.push('/nodes')
      }, error => {
        if (error.response) {
          this.message = { level: 'danger', text: error.response.data.message }
        } else if (error.request) {
          this.message = { level: 'danger', text: 'A networking error occurred. Is the API server running?' }
        }
        this.submitted = false
      })
    }
  }
}
</script>
