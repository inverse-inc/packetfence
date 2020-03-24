<template>
  <router-view></router-view>
</template>

<script>
import apiCall from '@/utils/api'

export default {
  name: 'Configurator',
  data () {
    return {
      requestInterceptor: null
    }
  },
  methods: {
  },
  created () {
    this.requestInterceptor = apiCall.interceptors.request.use((config) => {
      config.baseURL = '/api/v1/configurator/'
      return config;
    });
  },
  beforeDestroy () {
    apiCall.interceptors.request.eject(this.requestInterceptor)
  }
}
</script>
