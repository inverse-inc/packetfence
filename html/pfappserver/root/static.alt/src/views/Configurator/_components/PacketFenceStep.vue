<template>
  <base-step
    :name="$t('Configure PacketFence')"
    icon="cogs">
    <database-view form-store-name="formDatabase" />
    <general-view form-store-name="formGeneral" />
    <alerting-view form-store-name="formAlerting" />
  </base-step>
</template>

<script>
import FormStore from '@/store/base/form'
import BaseStep from './BaseStep'
import DatabaseView from './DatabaseView'
import GeneralView from './GeneralView'
import AlertingView from './AlertingView'

export default {
  name: 'packetfence-step',
  components: {
    BaseStep,
    DatabaseView,
    GeneralView,
    AlertingView
  },
  beforeMount () {
    if (!this.$store.state.formDatabase) { // Register store module only once
      this.$store.registerModule('formDatabase', FormStore)
    }
    if (!this.$store.state.formGeneral) { // Register store module only once
      this.$store.registerModule('formGeneral', FormStore)
    }
    if (!this.$store.state.formAlerting) { // Register store module only once
      this.$store.registerModule('formAlerting', FormStore)
    }
  }
}
</script>
