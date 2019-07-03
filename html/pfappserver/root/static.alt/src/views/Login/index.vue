<template>
    <b-row class="justify-content-md-center mt-3">
        <b-col md="8" lg="6" xl="4">
          <transition name="fade" mode="out-in">
            <pf-form-login @login="login()"></pf-form-login>
        </b-col>
    </b-row>
</template>

<script>
import pfButtonSave from '@/components/pfButtonSave'
import pfFormLogin from '@/components/pfFormLogin'

export default {
  name: 'Login',
  components: {
    pfButtonSave,
    pfFormLogin
  },
  methods: {
    login () {
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
