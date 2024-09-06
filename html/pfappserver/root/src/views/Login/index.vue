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

  // workaround: vue-router3 history not accessible w/ vue-composition-api
  const previousRoute = ref(null)
  const setPreviousRoute = route => {
    if (['/login', '/logout', '/expire'].includes(route.path)) {
      route.path = '/'
    }
    previousRoute.value = route
  }

  const onLogin = () => {
    loginSuccessful.value = true
    // Don't redirect to /login nor /logout
    if (previousRoute.value.path &&
      previousRoute.value.path !== '/login' &&
      previousRoute.value.path !== '/logout') {
      $router.replace(previousRoute.value)
    } else {
      $router.replace('/') // Go to the default/catch-all route
    }
  }

  return {
    loginSuccessful,
    onLogin,
    setPreviousRoute
  }
}

// @vue/component
export default {
  name: 'Login',
  components,
  setup,
  // workaround: vue-router3 history not accessible w/ vue-composition-api
  beforeRouteEnter(to, from, next) {
    next(vm => vm.setPreviousRoute(from))
  }
}
</script>
