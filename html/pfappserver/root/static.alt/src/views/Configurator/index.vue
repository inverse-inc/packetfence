<template>
  <router-view></router-view>
</template>

<script>
import apiCall from '@/utils/api'

export default {
  name: 'Configurator',
  data () {
    return {
    }
  },
  methods: {
  },
  created () {
    apiCall.interceptors.request.use((config) => {
      config.baseURL = '/api/v1/configurator/'
      return config;
    });
  }
}
</script>
