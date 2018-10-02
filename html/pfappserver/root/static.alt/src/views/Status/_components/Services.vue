<template>
  <b-card class="mt-3" no-body>
    <b-card-header>
      <h4 v-t="'Services'"></h4>
    </b-card-header>
    <div class="card-body">
    <b-table small="true" :fields="fields" :items="services">
      <template slot="state" slot-scope="service">
        <pf-form-toggle
         :value="service.item.enabled"
         :disabled="service.item.loading"
         width="90" class="d-inline-block"
         :labels="{ checked: 'enabled', unchecked: 'disabled' }"></pf-form-toggle>
        <pf-form-toggle
         :value="service.item.alive"
         :disabled="service.item.loading"
         width="90" class="d-inline-block"
         :labels="{ checked: 'running', unchecked: 'stopped' }"
         :color="{ unchecked: '#be2125' }"></pf-form-toggle>
      </template>
    </b-table>
    </div>
  </b-card>
</template>

<script>
import pfFormToggle from '@/components/pfFormToggle'

export default {
  name: 'Services',
  components: {
    'pf-form-toggle': pfFormToggle
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
