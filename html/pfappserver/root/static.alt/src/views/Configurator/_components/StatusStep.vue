<template>
  <base-step
    :name="$t('Confirmation')"
    icon="check">
    <services-view store-name="$_status"/>
  </base-step>
</template>

<script>
import BaseStep from './BaseStep'
import ServicesView from './ServicesView'

export default {
  name: 'status-step',
  components: {
    BaseStep,
    ServicesView
  }
}
</script>
