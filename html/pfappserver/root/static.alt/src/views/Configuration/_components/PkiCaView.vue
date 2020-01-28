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
        <span v-if="!isNew && !isClone" v-html="$t('Certificate Authority')"></span>
        <span v-else-if="isClone" v-html="$t('Clone Certificate Authority')"></span>
        <span v-else>{{ $t('New Certificate Authority') }}</span>
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
  validators,
  decomposeCa,
  recomposeCa
} from '../_config/pki/ca'

export default {
  name: 'pki-ca-view',
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
      return view(this.form, this.meta) // ../_config/pki/ca
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
    }
  },
  methods: {
    init () {
      const { isNew, isClone } = this
      this.$store.dispatch(`${this.formStoreName}/setMeta`, { isNew, isClone })
      if (this.id) {
        // existing
        this.$store.dispatch('$_pkis/getCa', this.id).then(form => {
          this.$store.dispatch(`${this.formStoreName}/setForm`, decomposeCa(form))
        })
      } else {
        this.$store.dispatch(`${this.formStoreName}/clearForm`)
      }
      this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
    },
    close () {
      this.$router.push({ name: 'pkiCas' })
    },
    clone () {
      this.$router.push({ name: 'clonePkiCa' })
    },
    create () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_pkis/createCa', recomposeCa(this.form)).then(response => {
        const { result: { 0: { Entries: { 0: { ID: id } = {} } = {} } = {} } = {} } = response
        if (actionKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'pkiCa', params: { id } })
        }
      }).catch(e => {
        this.$store.dispatch('notification/danger', { message: this.$i18n.t('Could not create Certificate Authority: ') + e })
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
