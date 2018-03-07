<template>
  <b-card class="mt-3">
    <div slot="header">
      <h4 v-t="'Services'"></h4>
    </div>
    <b-table small="true" :fields="fields" :items="services">
    </b-table>
  </b-card>
</template>

<script>
import ToggleButton from '@/components/ToggleButton'

export default {
  name: 'Services',
  components: {
    'toggle-button': ToggleButton
  },
  props: {
  },
  computed: {
    services () {
      return this.$store.state.$_status.services.map(s => {
        console.debug(s)
        return { service: s }
      })
    }
  },
  data () {
    return {
      fields: [
        {
          key: 'service',
          label: this.$i18n.t('Service')
        }
      ]
    }
  },
  created () {
    this.$store.dispatch('$_status/getServices')
  }
}
</script>

