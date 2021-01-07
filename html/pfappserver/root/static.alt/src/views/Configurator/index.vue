<template>
  <router-view></router-view>
</template>

<script>
import apiCall from '@/utils/api'

export default {
  name: 'Configurator',
  data () {
    return {
      requestInterceptor: null,
      responseInterceptor: null
    }
  },
  created () {
    this.requestInterceptor = apiCall.interceptors.request.use((config) => {
      config.baseURL = '/api/v1/configurator/'
      return config;
    });
    this.responseInterceptor = apiCall.interceptors.response.use((response) => {
      return response
    }, (error) => {
      const { response: { status = false, data: { message = null } = {} } = {} } = error
      if (message) {
        if (status === 401 && /configurator is turned off/.test(message)) {
          this.$router.push({ name: 'login' })
        }
      }
      return Promise.reject(error)
    })
  },
  beforeUnmount () {
    apiCall.interceptors.request.eject(this.requestInterceptor)
    apiCall.interceptors.response.eject(this.responseInterceptor)
  }
}
</script>
