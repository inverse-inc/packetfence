<template>
  <pf-config-view
    :formStoreName="formStoreName"
    :isLoading="isLoading"
    :disabled="isLoading"
    :view="view"
    @save="save"
  >
    <template v-slot:header>
      <h4 class="mb-0">
        <span>{{ $t('Active Active') }}</span>
      </h4>
    </template>
    <template v-slot:footer>
      <b-card-footer>
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading" class="mr-1">
          <template>{{ $t('Save') }}</template>
        </pf-button-save>
        <b-button :disabled="isLoading" class="mr-1" variant="outline-secondary" @click="init()">{{ $t('Reset') }}</b-button>
      </b-card-footer>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import {
  view,
  validators
} from '../_config/activeActive'

export default {
  name: 'active-active-view',
  components: {
    pfConfigView,
    pfButtonSave
  },
  props: {
    formStoreName: { // from router
      type: String,
      default: null,
      required: true
    }
  },
  data () {
    return {
      options: {}
    }
  },
  validations () {
    return {
      form: this.formValidations
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
      return view(this.form, this.meta) // ../_config/activeActive
    },
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    isLoading () {
      return this.$store.getters['$_bases/isLoading']
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_bases/optionsActiveActive').then(options => {
        this.$store.dispatch(`${this.formStoreName}/setOptions`, options)
        this.$store.dispatch('$_bases/getActiveActive').then(form => {
          this.$store.dispatch(`${this.formStoreName}/setForm`, form)
          this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
        })
      })
    },
    save () {
      this.$store.dispatch('$_bases/updateActiveActive', this.form)
    }
  },
  created () {
    this.init()
  }
}
</script>
