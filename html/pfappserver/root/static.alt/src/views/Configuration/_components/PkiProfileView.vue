<template>
  <pf-config-view
    :form-store-name="formStoreName"
    :isLoading="isLoading"
    :disabled="isLoading"
    :isNew="isNew"
    :isClone="isClone"
    :view="view"
    @close="close"
    @create="create"
  >
    <template v-slot:header>
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="d-inline mb-0">
        <span v-if="!isNew && !isClone" v-html="$t('Profile')"></span>
        <span v-else-if="isClone" v-html="$t('Clone Profile')"></span>
        <span v-else>{{ $t('New Profile') }}</span>
      </h4>
    </template>
    <template v-slot:footer>
      <b-card-footer>
        <pf-button-save v-if="isNew || isClone" :disabled="invalidForm" :isLoading="isLoading">
          <template v-if="isNew">{{ $t('Create') }}</template>
          <template v-else-if="isClone">{{ $t('Clone') }}</template>
        </pf-button-save>
        <b-button v-if="isNew || isClone" :disabled="isLoading" class="ml-1" variant="outline-secondary" @click="init()">{{ $t('Reset') }}</b-button>
        <b-button v-if="!isNew && !isClone" :disabled="isLoading" class="ml-1" variant="outline-primary" @click="clone()">{{ $t('Clone') }}</b-button>
      </b-card-footer>
    </template>
  </pf-config-view>
</template>

<script>
import pfButtonSave from '@/components/pfButtonSave'
import pfConfigView from '@/components/pfConfigView'
import {
  view,
  validators
} from '../_config/pki/profile'

export default {
  name: 'pki-profile-view',
  components: {
    pfButtonSave,
    pfConfigView
  },
  props: {
    formStoreName: { // from router
      type: String,
      default: null,
      required: true
    },
    isNew: { // from router
      type: Boolean,
      default: false
    },
    isClone: { // from router
      type: Boolean,
      default: false
    },
    id: { // from router
      type: String,
      default: null
    },
    ca_id: { // from router
      type: String,
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
      return view(this.form, this.meta) // ../_config/pki/profile
    },
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    isLoading () {
      return this.$store.getters['$_pkis/isLoading']
    },
    actionKey () {
      return this.$store.getters['events/actionKey']
    },
    escapeKey () {
      return this.$store.getters['events/escapeKey']
    },
    cas: { // mutating this property will re-evaluate view() and validators()
      get () {
        const { meta: { cas = [] } = {} } = this
        return cas
      },
      set (newValue) {
        this.$set(this.meta, 'cas', newValue)
      }
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_pkis/allCas').then(cas => {
        this.cas = cas
      })
      const { isNew, isClone, cas, ca_id } = this
      this.$store.dispatch(`${this.formStoreName}/setMeta`, { isNew, isClone, cas })
      this.$store.dispatch(`${this.formStoreName}/clearForm`)
      if (this.id) {
        // existing
        this.$store.dispatch('$_pkis/getProfile', this.id).then(form => {
          if (ca_id) {
            this.$store.dispatch(`${this.formStoreName}/setForm`, { ...form, ...{ ca_id } })
          } else {
            this.$store.dispatch(`${this.formStoreName}/setForm`, form)
          }
        })
      } else {
        this.$store.dispatch(`${this.formStoreName}/setForm`, { ca_id })
      }
      this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
    },
    close () {
      this.$router.push({ name: 'pkiProfiles' })
    },
    clone () {
      this.$router.push({ name: 'clonePkiProfile' })
    },
    create () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_pkis/createProfile', this.form).then(item => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        } else {
          const { ID: id } = item
          this.$router.push({ name: 'pkiProfile', params: { id } })
        }
      }).catch(e => {
        this.$store.dispatch('notification/danger', { message: this.$i18n.t('Could not create Profile.<br/>Reason: ') + e })
      })
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
    isClone: {
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
