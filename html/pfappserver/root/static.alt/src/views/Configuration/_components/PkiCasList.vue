<template>
  <b-card>
    <h4 class="mb-3">{{ $t('Certificate Authorities') }}</h4>
    <b-row align-h="end" align-v="start" class="mb-3">
      <b-col>
        <b-button variant="outline-primary" :to="{ name: 'newPkiCa' }">{{ $t('New Certificate Authority') }}</b-button>
        <pf-button-service service="pfpki" class="ml-1" restart start stop :disabled="isLoading" @start="init" @restart="init"></pf-button-service>
      </b-col>
    </b-row>
    <b-table
      :items="cas"
      :fields="columns"
      @row-clicked="onRowClick"
      hover
      striped
    >
      <template v-slot:empty>
        <pf-empty-table :isLoading="isLoading" :text="$t('Click the button to define a new Certificate Authority.')">{{ $t('No certificate authorities defined') }}</pf-empty-table>
      </template>
      <template v-slot:cell(buttons)="{ item }">
        <span class="float-right text-nowrap">
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clipboard(item)">
            <icon class="mr-1" name="clipboard-list"></icon> {{ $t('Copy Certificate') }}
          </b-button>
          <b-button size="sm" variant="outline-primary" class="mr-1" :to="{ name: 'newPkiProfile', params: { ca_id: item.ID } }">{{ $t('New Profile') }}</b-button>
        </span>
      </template>
    </b-table>
  </b-card>
</template>

<script>
import pfButtonService from '@/components/pfButtonService'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  columns
} from '../_config/pki/ca'

export default {
  name: 'pki-cas-list',
  components: {
    pfButtonService,
    pfEmptyTable
  },
  data () {
    return {
      columns, // ../_config/pki/ca
      cas: []
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_pkis/isCaLoading']
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_pkis/allCas').then(cas => {
        this.cas = cas
      })
    },
    clone (item) {
      this.$router.push({ name: 'clonePkiCa', params: { id: item.ID } })
    },
    clipboard (item) {
      this.$store.dispatch('$_pkis/getCa', item.ID).then(data => {
        try {
          navigator.clipboard.writeText(data.cert).then(() => {
            this.$store.dispatch('notification/info', { message: this.$i18n.t('Certificate copied to clipboard') })
          }).catch(err => {
            this.$store.dispatch('notification/danger', { message: this.$i18n.t('Could not copy certificate to clipboard.') })
          })
        } catch (e) {
          this.$store.dispatch('notification/danger', { message: this.$i18n.t('Clipboard not supported.') })
        }
      })
    },
    onRowClick (item) {
      this.$router.push({ name: 'pkiCa', params: { id: item.ID } })
    }
  },
  created () {
    this.init()
  }
}
</script>
