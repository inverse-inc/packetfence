<template>
    <b-row class="justify-content-md-center mt-3">
        <b-col md="8" lg="6" xl="4">
            <b-form @submit.prevent="login">
                <b-card no-body>
                    <b-card-header>
                      <h4 class="mb-0" v-t="'Login to PacketFence Administration'"></h4>
                    </b-card-header>
                    <b-card-body>
                        <b-alert :variant="message.level" :show="message.text" fade>
                            {{ message.text }}
                        </b-alert>
                        <b-form-group :label="$t('Username')" label-for="username" label-cols="4">
                            <b-form-input id="username" ref="username" type="text" v-model="username" v-autofocus required></b-form-input>
                        </b-form-group>
                        <b-form-group :label="$t('Password')" label-for="password" label-cols="4">
                            <b-form-input id="password" type="password" v-model="password" required></b-form-input>
                        </b-form-group>
                    </b-card-body>
                    <b-card-footer>
                        <pf-button-save type="submit" variant="primary" :isLoading="isLoading" :disabled="!validForm">{{ $t('Login') }}</pf-button-save>
                    </b-card-footer>
                </b-card>
            </b-form>
        </b-col>
    </b-row>
</template>

<script>
import pfButtonSave from '@/components/pfButtonSave'

export default {
  name: 'Login',
  components: {
    pfButtonSave
  },
  directives: {
    autofocus: {
      inserted: (el) => {
        el.focus()
      }
    }
  },
  data () {
    return {
      username: '',
      password: '',
      submitted: false,
      message: {}
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_auth/isLoading']
    },
    validForm () {
      return this.username.length > 0 && this.password.length > 0 && !this.isLoading
    }
  },
  mounted () {
    if (this.$route.path === '/logout') {
      this.$store.dispatch('$_auth/logout').then(() => {
        this.message = { level: 'info', text: this.$i18n.t('You have logged out') }
      })
    } else if (this.$route.path === '/expire' || this.$route.params.expire) {
      this.$store.dispatch('$_auth/logout').then(() => {
        this.message = { level: 'warning', text: this.$i18n.t('Your session has expired') }
      })
    }
    this.$refs.username.focus()
  },
  methods: {
    login () {
      this.submitted = true
      this.message = false
      this.$store.dispatch('$_auth/login', { username: this.username, password: this.password }).then(response => {
        // Don't redirect to /login nor /logout
        if (this.$route.params.previousPath &&
          this.$route.params.previousPath !== '/login' &&
          this.$route.params.previousPath !== '/logout') {
          this.$router.push(this.$route.params.previousPath)
        } else {
          this.$router.push('/') // Go to the default/catch-all route
        }
      }, error => {
        if (error.response) {
          this.message = { level: 'danger', text: error.response.data.message }
        } else if (error.request) {
          this.message = { level: 'danger', text: this.$i18n.t('A networking error occurred. Is the API service running?') }
        }
        this.submitted = false
      })
    }
  }
}
</script>
