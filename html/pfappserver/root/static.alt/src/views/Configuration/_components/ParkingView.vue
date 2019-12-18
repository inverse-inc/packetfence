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
        {{ $t('Parking') }}
        <pf-button-help class="ml-1" url="PacketFence_Installation_Guide.html#_parked_devices" />
      </h4>
    </template>
    <template v-slot:footer>
      <b-card-footer>
        <pf-button-save :disabled="isDisabled" :isLoading="isLoading">
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
} from '../_config/parking'

export default {
  name: 'parking-view',
  components: {
    pfButtonHelp,
    pfButtonSave,
    pfConfigView
  },
  props: {
    formStoreName: {
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
      return view(this.form, this.meta) // ../_config/parking
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
      this.$store.dispatch('$_bases/optionsParking').then(options => {
        this.$store.dispatch(`${this.formStoreName}/setOptions`, options)
      })
      this.$store.dispatch('$_bases/getParking').then(form => {
        this.$store.dispatch(`${this.formStoreName}/setForm`, form)
      })
      this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
    },
    save () {
      this.$store.dispatch('$_bases/updateParking', this.form)
    }
  },
  created () {
    this.init()
  }
}
</script>
