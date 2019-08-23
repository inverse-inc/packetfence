<template>
    <b-form @submit.prevent="login">
        <component :is="modal?'b-modal':'b-card'" v-model="showModal"
          static lazy no-close-on-esc no-close-on-backdrop hide-header-close no-body>
            <template v-slot:[headerSlotName]>
                <h4 class="mb-0" v-if="sessionTime" v-t="'Your session will expires soon'"></h4>
                <h4 class="mb-0" v-else v-t="'Login to PacketFence Administration'"></h4>
            </template>
            <component :is="modal?'div':'b-card-body'">
                <b-alert :variant="message.level" :show="message.text" fade>
                    {{ message.text }}
                </b-alert>
                <template v-if="sessionTime == false">
                  <b-form-group :label="$t('Username')" label-for="username" label-cols="4">
                      <b-form-input id="username" type="text" v-model="username" v-focus required :readonly="modal"></b-form-input>
                  </b-form-group>
                  <b-form-group :label="$t('Password')" label-for="password" label-cols="4">
                      <b-form-input id="password" type="password" v-model="password" required></b-form-input>
                  </b-form-group>
                </template>
            </component>
            <template v-slot:[footerSlotName] class="justify-content-start">
                <template v-if="sessionTime">
                  <b-link variant="outline-secondary" @click="logout">{{ $t('Logout now') }}</b-link>
                  <b-button class="ml-2" variant="primary" @click="extendSession()" v-t="'Extend Session'"><b-button>
                </template>
                <template v-else>
                  <b-link variant="outline-secondary" @click="logout" v-if="modal">{{ $t('Use a different username') }}</b-link>
                  <pf-button-save type="submit" class="ml-2" variant="primary" :isLoading="isLoading" :disabled="!validForm">{{ $t('Login') }}</pf-button-save>
                </template>
            </template>
        </component>
    </b-form>
</template>

<script>
import pfButtonSave from '@/components/pfButtonSave'

const EXPIRATION_DELAY = 60 // in seconds

export default {
  name: 'pf-form-login',
  components: {
    pfButtonSave
  },
  data () {
    return {
      username: '',
      password: '',
      message: {},
      showModal: false,
      sessionTime: false,
      sessionTimer: false
    }
  },
  props: {
    modal: {
      type: Boolean,
      default: false
    }
  },
  computed: {
    headerSlotName () {
      return this.modal ? 'modal-header' : 'header'
    },
    footerSlotName () {
      return this.modal ? 'modal-footer' : 'footer'
    },
    isSessionAlive () {
      return this.$store.getters['session/getSessionTime']() !== false
    },
    isLoading () {
      return this.$store.getters['session/isLoading']
    },
    validForm () {
      return this.username.length > 0 && this.password.length > 0 && !this.isLoading
    }
  },
  mounted () {
    if (this.$route.path === '/logout') {
      this.$store.dispatch('session/logout').then(() => {
        this.message = { level: 'info', text: this.$i18n.t('You have logged out') }
      })
    } else if (this.$route.path === '/expire' || this.$route.params.expire) {
      this.$store.dispatch('session/logout').then(() => {
        this.message = { level: 'warning', text: this.$i18n.t('Your session has expired') }
      })
    } else if (this.$store.state.session.username) {
      this.username = this.$store.state.session.username
    }
    if (this.modal) {
      // Watch for session state change from external sources
      this.$watch('isSessionAlive', () => { this.updateSessionTime() })
    }
  },
  methods: {
    login () {
      this.$store.dispatch('session/login', { username: this.username, password: this.password }).then(response => {
        if (this.modal) {
          this.updateSessionTime()
          this.$store.dispatch('notification/status_success', { message: this.$i18n.t('Login successful') })
        }
        this.$emit('login', response)
      }, error => {
        if (error.response) {
          this.message = { level: 'danger', text: error.response.data.message }
        } else if (error.request) {
          this.message = { level: 'danger', text: this.$i18n.t('A networking error occurred. Is the API service running?') }
        }
      })
    },
    extendSession () {
      this.$store.dispatch('session/getTokenInfo').then(() => {
        this.updateSessionTime()
        this.$store.dispatch('notification/info', { message: this.$i18n.t('Your session has been successfully extended.') })
      }, () => {
        this.$store.commit('session/EXPIRED')
      })
    },
    logout () {
      this.$store.dispatch('session/logout').then(() => {
        this.$router.push('/logout')
      })
    },
    updateSessionTime () {
      this.sessionTime = this.$store.getters['session/getSessionTime']()
      this.username = this.$store.state.session.username
      if (this.sessionTime === false) {
        // Token has expired
        this.password = ''
        this.message = { level: 'warning', text: this.$i18n.t('Your session has expired') }
        this.showModal = !!this.$store.state.session.token
        clearTimeout(this.sessionTimer)
      } else {
        if (this.sessionTime < EXPIRATION_DELAY) {
          // Token will expire soon
          this.showModal = true
          this.message = { level: 'warning', text: this.$i18n.t('Your session will expire in {seconds} seconds', { seconds: this.sessionTime > 0 ? this.sessionTime : 0 }) }
          this.sessionTimer = setTimeout(this.updateSessionTime, 1000) // update message every second
        } else {
          // Check back later
          this.showModal = false
          this.sessionTimer = setTimeout(this.updateSessionTime, (this.sessionTime - EXPIRATION_DELAY) * 1000)
        }
      }
    }
  }
}
</script>
