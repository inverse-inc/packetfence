<template>
  <b-row class="justify-content-md-center mt-3">
    <b-col md="8" lg="6" xl="4">
      <transition name="fade" mode="out-in">
        <app-login @login="onLogin" v-show="!loginSuccessful" />
      </transition>
    </b-col>
  </b-row>
</template>

<script>
import AppLogin from '@/components/AppLogin'
const components = {
  AppLogin
}

import { ref } from '@vue/composition-api'
const setup = (props, context) => {

  const { root: { $router } = {} } = context

  const loginSuccessful = ref(false)

  const onLogin = () => {
    loginSuccessful.value = true
    const uri = localStorage.getItem('last_uri')
    localStorage.removeItem('last_uri')
    if (uri && !['/', '/login', '/logout', '/expire'].includes(uri)
        && !/^\/configurator\//.test(uri)) {
      $router.replace(uri)
    } else {
      $router.replace('/') // Go to the default/catch-all route
    }
  }

  return {
    loginSuccessful,
    onLogin
  }
}

// @vue/component
export default {
  name: 'Login',
  components,
  setup,
}
</script>
