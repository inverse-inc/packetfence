<template>
  <pf-config-view
    :form-store-name="formStoreName"
    :isLoading="isLoading"
    :disabled="isLoading"
    :view="view"
    @save="save"
  >
    <template v-slot:header>
      <h4 class="mb-0">
        {{ $t('SNMP') }}
        <pf-button-help class="ml-1" url="PacketFence_Installation_Guide.html#_snmp_traps_limit" />
      </h4>
    </template>
    <template v-slot:footer>
      <b-card-footer>
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">
          <template>{{ $t('Save') }}</template>
        </pf-button-save>
        <b-button :disabled="isLoading" class="ml-1" variant="outline-secondary" @click="init()">{{ $t('Reset') }}</b-button>
      </b-card-footer>
    </template>
  </pf-config-view>
</template>

<script>
import pfButtonHelp from '@/components/pfButtonHelp'
import pfButtonSave from '@/components/pfButtonSave'
import pfConfigView from '@/components/pfConfigView'
import {
  view,
  validators
} from '../_config/snmpTrap'

export default {
  name: 'snmp-trap-view',
  components: {
    pfButtonHelp,
    pfButtonSave,
    pfConfigView
  },
  props: {
    formStoreName: { // from router
      type: String,
      default: null,
      required: true
    }
  },
  computed: {
    meta () {
      return this.$store.getters[`${this.formStoreName}/$meta`]
    },
    form () {
      return this.$store.getters[`${this.formStoreName}/$form`]
    },
    view () {
      return view(this.form, this.meta) // ../_config/snmpTrap
    },
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    isLoading () {
      return this.$store.getters['$_bases/isLoading']
    },
    isDisabled () {
      return this.invalidForm || this.isLoading
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_bases/optionsSNMPTraps').then(options => {
        this.$store.dispatch(`${this.formStoreName}/setOptions`, options)
      })
      this.$store.dispatch('$_bases/getSNMPTraps').then(form => {
        this.$store.dispatch(`${this.formStoreName}/setForm`, form)
      })
      this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
    },
    save () {
      this.$store.dispatch('$_bases/updateSNMPTraps', this.form)
    }
  },
  created () {
    this.init()
  }
}
</script>
