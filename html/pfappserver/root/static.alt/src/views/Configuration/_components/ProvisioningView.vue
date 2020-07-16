<template>
  <pf-config-view
    :form-store-name="formStoreName"
    :isLoading="isLoading"
    :disabled="isLoading"
    :isDeletable="isDeletable"
    :isNew="isNew"
    :isClone="isClone"
    :view="view"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template v-slot:header>
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="d-inline mb-0">
        <span v-if="!isNew && !isClone" v-html="$t('Provisioner {id}', { id: $strong(id) })"></span>
        <span v-else-if="isClone" v-html="$t('Clone Provisioner {id}', { id: $strong(id) })"></span>
        <span v-else>{{ $t('New Provisioner') }}</span>
      </h4>
      <b-badge class="ml-2" variant="secondary" v-t="provisioningType"></b-badge>
    </template>
    <template v-slot:footer>
      <b-card-footer>
        <pf-button-save :disabled="isDisabled" :isLoading="isLoading">
          <template v-if="isNew">{{ $t('Create') }}</template>
          <template v-else-if="isClone">{{ $t('Clone') }}</template>
          <template v-else-if="actionKey">{{ $t('Save & Close') }}</template>
          <template v-else>{{ $t('Save') }}</template>
        </pf-button-save>
        <b-button :disabled="isLoading" class="ml-1" variant="outline-secondary" @click="init()">{{ $t('Reset') }}</b-button>
        <b-button v-if="!isNew && !isClone" :disabled="isLoading" class="ml-1" variant="outline-primary" @click="clone()">{{ $t('Clone') }}</b-button>
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Provisioner?')" @on-delete="remove()"/>
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
} from '../_config/provisioning'

export default {
  name: 'provisioning-view',
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
    provisioningType: { // from router (or source)
      type: String,
      default: null
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
      return view(this.form, this.meta) // ../_config/provisioning
    },
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    isLoading () {
      return this.$store.getters['$_provisionings/isLoading']
    },
    isDisabled () {
      return this.invalidForm || this.isLoading
    },
    isDeletable () {
      const { isNew, isClone, form: { not_deletable: notDeletable = false } = {} } = this
      if (isNew || isClone || notDeletable) {
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
      if (this.id) { // existing
        this.$store.dispatch('$_provisionings/optionsById', this.id).then(options => {
          this.$store.dispatch('$_provisionings/getProvisioning', this.id).then(form => {
            if (this.isClone) form.id = `${form.id}-${this.$i18n.t('copy')}`
            const provisioningType = form.type
            const { meta = {} } = options
            const { isNew, isClone } = this
            this.$store.dispatch(`${this.formStoreName}/setMeta`, { ...meta, ...{ isNew, isClone, provisioningType } })
            this.$store.dispatch(`${this.formStoreName}/setForm`, form)
          })
        })
      } else { // new
        this.$store.dispatch('$_provisionings/optionsByProvisioningType', this.provisioningType).then(options => {
          const { meta = {} } = options
          const { isNew, isClone, provisioningType } = this
          this.$store.dispatch(`${this.formStoreName}/setMeta`, { ...meta, ...{ isNew, isClone, provisioningType } })
          this.$store.dispatch(`${this.formStoreName}/setForm`, { ...defaults(meta), ...{ type: this.provisioningType } }) // set defaults
        })
      }
      this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
    },
    close () {
      this.$router.push({ name: 'provisionings' })
    },
    clone () {
      this.$router.push({ name: 'cloneProvisioning' })
    },
    create () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_provisionings/createProvisioning', this.form).then(() => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'provisioning', params: { id: this.form.id } })
        }
      })
    },
    save () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_provisionings/updateProvisioning', this.form).then(() => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        }
      })
    },
    remove () {
      this.$store.dispatch('$_provisionings/deleteProvisioning', this.id).then(() => {
        this.close()
      })
    },
    setValidations (validations) {
      this.$set(this, 'formValidations', validations)
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
