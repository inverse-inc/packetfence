<template>
  <base-step
    :name="$t('Fingerbank on-boarding')"
    icon="fingerprint"
    :is-loading="isLoading"
    @next="save">
    <fingerbank-view form-store-name="formFingerbank" ref="fingerbank" />
  </base-step>
</template>

<script>
import BaseStep from './BaseStep'
import FingerbankView from './FingerbankView'

export default {
  name: 'fingerbank-step',
  components: {
    BaseStep,
    FingerbankView
  },
  data () {
    return {
      isLoading: false
    }
  },
  methods: {
    save (nextRouteName) {
      this.$router.push({ name: nextRouteName })
    }
  }
}
</script>
