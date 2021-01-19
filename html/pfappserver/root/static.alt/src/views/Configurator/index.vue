<template>
  <router-view></router-view>
</template>

<script>
import { onBeforeUnmount } from '@vue/composition-api'
import apiCall, { baseURL } from '@/utils/api'

const setup = (props, { emit }) => {

  const requestInterceptor = apiCall.interceptors.request.use((config) => {
    config.baseURL = '/api/v1/configurator/'
    return config;
  })

  const responseInterceptor = apiCall.interceptors.response.use((response) => {
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

  onBeforeUnmount(() => {
    apiCall.interceptors.request.eject(requestInterceptor)
    apiCall.interceptors.response.eject(responseInterceptor)
    apiCall.baseURL = baseURL
  })

  return
}

export default {
  name: 'Configurator',
  setup
}
</script>
