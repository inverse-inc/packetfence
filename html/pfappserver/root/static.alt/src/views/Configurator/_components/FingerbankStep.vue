<template>
  <base-step
    :name="$t('Fingerbank on-boarding')"
    icon="fingerprint">
    <fingerbank-view form-store-name="formFingerbank" />
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
  }
}
</script>
