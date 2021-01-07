<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
    >
      <template v-slot:pageHeader>
        <b-card-header>
          <h4 class="mb-0">{{ $t('Certificate Authorities') }}</h4>
        </b-card-header>
      </template>
      <template v-slot:buttonAdd>
        <b-button variant="outline-primary" :to="{ name: 'newPkiCa' }">{{ $t('New Certificate Authority') }}</b-button>
        <pf-button-service service="pfpki" class="ml-1" restart start stop :disabled="isLoading"></pf-button-service>
      </template>
      <template v-slot:emptySearch="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No certificate authorities found') }}</pf-empty-table>
      </template>
      <template v-slot:cell(buttons)="item">
        <span class="float-right">
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
          <b-button size="sm" variant="outline-primary" class="mr-1 text-nowrap" @click.stop.prevent="clipboard(item)">{{ $t('Copy Certificate') }}</b-button>
          <b-button size="sm" variant="outline-primary" class="mr-1 text-nowrap" :to="{ name: 'newPkiProfile', params: { ca_id: item.ID } }">{{ $t('New Template') }}</b-button>
        </span>
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfButtonService from '@/components/pfButtonService'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  config
} from '../_config/pki/ca'

export default {
  name: 'pki-cas-list',
  components: {
    pfButtonService,
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      config: config(this)
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_pkis/isLoading']
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'clonePkiCa', params: { id: item.ID } })
    },
    clipboard (item) {
      this.$store.dispatch('$_pkis/getCa', item.ID).then(ca => {
        try {
          navigator.clipboard.writeText(ca.cert).then(() => {
            this.$store.dispatch('notification/info', { message: this.$i18n.t('<code>{cn}</code> certificate copied to clipboard', ca) })
          }).catch(() => {
            this.$store.dispatch('notification/danger', { message: this.$i18n.t('Could not copy <code>{cn}</code> certificate to clipboard.', ca) })
          })
        } catch (e) {
          this.$store.dispatch('notification/danger', { message: this.$i18n.t('Clipboard not supported.') })
        }
      })
    }
  }
}
</script>
