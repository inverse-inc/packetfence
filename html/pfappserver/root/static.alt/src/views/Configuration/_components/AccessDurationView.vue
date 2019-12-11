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
        <span>{{ $t('Access Duration') }}</span>
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
import Vue from 'vue'
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import duration from '@/utils/duration'
import {
  view,
  validators
} from '../_config/accessDuration'

export default {
  name: 'access-duration-view',
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
  computed: {
    meta () {
      return this.$store.getters[`${this.formStoreName}/$meta`]
    },
    form () {
      return this.$store.getters[`${this.formStoreName}/$form`]
    },
    view () {
      return view(this.form, this.meta) // ../_config/accessDuration
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
      this.$store.dispatch('$_bases/optionsGuestsAdminRegistration').then(options => {
        this.$store.dispatch(`${this.formStoreName}/setOptions`, options)
        this.$store.dispatch('$_bases/getGuestsAdminRegistration').then(form => {
          if ('access_duration_choices' in form && form.access_duration_choices.constructor === String) {
            // split and deserialize access_duration_choices
            form.access_duration_choices = form.access_duration_choices.split(',').map((accessDuration) => duration.deserialize(accessDuration))
          }
          this.$store.dispatch(`${this.formStoreName}/setForm`, form)
          this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
        })
      })
    },
    save () {
      let form = JSON.parse(JSON.stringify(this.form)) // dereference
      // serialize and join access_duration_choices
      form.access_duration_choices = form.access_duration_choices.map(accessDuration => duration.serialize(accessDuration)).join(',')
      this.$store.dispatch('$_bases/updateGuestsAdminRegistration', form)
    }
  },
  created () {
    this.init()
  }
}
</script>
