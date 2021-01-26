<template>
    <b-row class="justify-content-md-center mt-3">
        <b-col md="8" lg="6" xl="4">
          <transition name="fade" mode="out-in">
            <pf-form-login @login="login()" v-show="!loginSuccessful"></pf-form-login>
          </transition>
        </b-col>
    </b-row>
</template>

<script>
import pfFormLogin from '@/components/pfFormLogin'

export default {
  name: 'Login',
  components: {
    pfFormLogin
  },
  data () {
    return {
      loginSuccessful: false
    }
  },
  methods: {
    login () {
      this.loginSuccessful = true
      // Don't redirect to /login nor /logout
      if (this.$route.params.previousPath &&
        this.$route.params.previousPath !== '/login' &&
        this.$route.params.previousPath !== '/logout') {
        this.$router.push(this.$route.params.previousPath)
      } else {
        this.$router.push('/') // Go to the default/catch-all route
      }
    }
  }
}
</script>
