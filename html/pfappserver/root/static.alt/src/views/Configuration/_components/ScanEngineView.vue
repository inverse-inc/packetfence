<template>
  <pf-config-view
    :form-store-name="formStoreName"
    :is-loading="isLoading"
    :disabled="isLoading"
    :is-deletable="isDeletable"
    :is-new="isNew"
    :is-clone="isClone"
    :view="view"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template v-slot:header>
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="d-inline mb-0">
        <span v-if="!isNew && !isClone" v-html="$t('Scan Engine {id}', { id: $strong(id) })"></span>
        <span v-else-if="isClone" v-html="$t('Clone Scan Engine {id}', { id: $strong(id) })"></span>
        <span v-else>{{ $t('New Scan Engine') }}</span>
      </h4>
      <b-badge class="ml-2" variant="secondary" v-t="scanType"></b-badge>
    </template>
    <template v-slot:footer>
      <b-card-footer>
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">
          <template v-if="isNew">{{ $t('Create') }}</template>
          <template v-else-if="isClone">{{ $t('Clone') }}</template>
          <template v-else-if="actionKey">{{ $t('Save & Close') }}</template>
          <template v-else>{{ $t('Save') }}</template>
        </pf-button-save>
        <b-button :disabled="isLoading" class="ml-1" variant="outline-secondary" @click="init()">{{ $t('Reset') }}</b-button>
        <b-button v-if="!isNew && !isClone" :disabled="isLoading" class="ml-1" variant="outline-primary" @click="clone()">{{ $t('Clone') }}</b-button>
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Scan Engine?')" @on-delete="remove()"/>
      </b-card-footer>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import {
  defaultsFromMeta as defaults
} from '../_config/'
import {
  view,
  validators
} from '../_config/scanEngine'

export default {
  name: 'scan-engine-view',
  components: {
    pfConfigView,
    pfButtonSave,
    pfButtonDelete
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
    scanType: { // from router
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
      return view(this.meta) // ../_config/scanEngine
    },
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    isLoading () {
      return this.$store.getters['$_scans/isLoading']
    },
    isDeletable () {
      if (this.isNew || this.isClone || ('not_deletable' in this.form && this.form.not_deletable)) {
        return false
      }
      return true
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
      if (this.id) {
        // existing
        this.$store.dispatch('$_scans/optionsById', this.id).then(options => {
          const { meta = {} } = options
          this.$store.dispatch('$_scans/getScanEngine', this.id).then(form => {
            const scanType = form.type
            const { isNew, isClone, isDeletable } = this
            this.$store.dispatch(`${this.formStoreName}/setMeta`, { ...meta, ...{ scanType, isNew, isClone, isDeletable } })
            this.$store.dispatch(`${this.formStoreName}/setForm`, form)
            if (this.isClone) form.id = `${form.id}-${this.$i18n.t('copy')}`
          })
        })
      } else {
        // new
        const { isNew, isClone, isDeletable, scanType } = this
        this.$store.dispatch('$_scans/optionsByScanType', this.scanType).then(options => {
          const { meta = {} } = options
          this.$store.dispatch(`${this.formStoreName}/setMeta`, { ...meta, ...{ scanType, isNew, isClone, isDeletable } })
          this.$store.dispatch(`${this.formStoreName}/setForm`, { ...defaults(meta), type: scanType }) // set defaults
        })
      }
      this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
    },
    close () {
      this.$router.push({ name: 'scanEngines' })
    },
    clone () {
      this.$router.push({ name: 'cloneScanEngine' })
    },
    create () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_scans/createScanEngine', this.form).then(() => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'scanEngine', params: { id: this.form.id } })
        }
      })
    },
    save () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_scans/updateScanEngine', this.form).then(() => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        }
      })
    },
    remove () {
      this.$store.dispatch('$_scans/deleteScanEngine', this.id).then(() => {
        this.close()
      })
    }
  },
  created () {
    this.init()
  },
  watch: {
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
