<template>
  <pf-config-view
    :form-store-name="formStoreName"
    :isLoading="isLoading"
    :disabled="isLoading"
    :view="view"
    @close="close"
  >
    <template v-slot:header>
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="d-inline mb-0">
        <span v-html="$t('Revoked Certificate')"></span>
      </h4>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import {
  view,
  validators
} from '../_config/pki/revokedCert'

export default {
  name: 'pki-revoked-cert-view',
  components: {
    pfConfigView
  },
  props: {
    formStoreName: { // from router
      type: String,
      default: null,
      required: true
    },
    id: { // from router
      type: [String, Number],
      default: null
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
      return view(this.form, this.meta) // ../_config/pki/revokedCert
    },
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    isLoading () {
      return this.$store.getters['$_pkis/isLoading']
    },
    escapeKey () {
      return this.$store.getters['events/escapeKey']
    },
    profiles: { // mutating this property will re-evaluate view() and validators()
      get () {
        const { meta: { profiles = [] } = {} } = this
        return profiles
      },
      set (newValue) {
        this.$set(this.meta, 'profiles', newValue)
      }
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_pkis/allProfiles').then(profiles => {
        this.profiles = profiles.sort((a, b) => { // sort profiles
          return (a.ca_name === b.ca_name)
            ? a.name.localeCompare(b.name)
            : a.ca_name.localeCompare(b.ca_name)
        })
      })
      const { profiles } = this
      this.$store.dispatch(`${this.formStoreName}/setMeta`, { profiles })
      this.$store.dispatch(`${this.formStoreName}/clearForm`)
      this.$store.dispatch('$_pkis/getRevokedCert', this.id).then(form => {
        this.$store.dispatch(`${this.formStoreName}/setForm`, form)
      })
      this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
    },
    close () {
      this.$router.push({ name: 'pkiRevokedCerts' })
    }
  },
  created () {
    this.init()
  },
  watch: {
    id: {
      handler: function () {
        this.init()
      }
    },
    escapeKey (pressed) {
      if (pressed) this.close()
    }
  }
}
</script>
