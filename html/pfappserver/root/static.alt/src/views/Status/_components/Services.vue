<template>
  <b-card class="mt-3" no-body>
    <b-card-header>
      <h4 v-t="'Services'"></h4>
    </b-card-header>
    <div class="card-body">
    <b-table small="true" :fields="fields" :items="services">
      <template slot="state" slot-scope="service">
        <toggle-button
         :value="service.item.enabled"
         :sync="true"
         :disabled="service.item.loading"
         width="90" class="d-inline-block"
         :labels="{ checked: 'enabled', unchecked: 'disabled' }"></toggle-button>
        <toggle-button
         :value="service.item.alive"
         :sync="true"
         :disabled="service.item.loading"
         width="90" class="d-inline-block"
         :labels="{ checked: 'running', unchecked: 'stopped' }"
         :color="{ unchecked: '#be2125' }"></toggle-button>
      </template>
    </b-table>
    </div>
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
      return this.$store.state.$_status.services
    }
  },
  data () {
    return {
      fields: [
        {
          key: 'state',
          label: this.$i18n.t('State')
        },
        {
          key: 'name',
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

