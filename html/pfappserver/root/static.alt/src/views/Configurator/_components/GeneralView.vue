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
        <span>{{ $t('General') }}</span>
      </h4>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import {
  view,
  validators
} from '@/views/Configuration/_config/general'

export default {
  name: 'general-view',
  components: {
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
      return view(this.form, this.meta) // ../_config/general
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
      this.$store.dispatch('$_bases/optionsGeneral').then(options => {
        this.$store.dispatch(`${this.formStoreName}/setOptions`, options)
      })
      this.$store.dispatch('$_bases/getGeneral').then(form => {
        this.$store.dispatch(`${this.formStoreName}/setForm`, form)
      })
      this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
    },
    save () {
      this.$store.dispatch('$_bases/updateGeneral', this.form)
    }
  },
  created () {
    this.init()
  }
}
</script>
