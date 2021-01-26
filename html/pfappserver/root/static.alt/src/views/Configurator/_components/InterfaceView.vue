<template>
  <pf-config-view
    :form-store-name="formStoreName"
    :isLoading="isLoading"
    :isClonable="isClonable"
    :isDeletable="isDeletable"
    :disabled="isLoading"
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
      <template>
        <h4 class="d-inline mb-0">
          <span v-if="!isNew && !isClone">{{ $t('Interface {id}', { id: (isVlan) ? form.master : id }) }}</span>
          <span v-else-if="isClone">{{ $t('Clone Interface {id}', { id: (isVlan) ? form.master : id }) }}</span>
          <span v-else>{{ $t('New VLAN for Interface {id}', { id: (isVlan) ? form.master : id }) }}</span>
        </h4>
        <b-badge v-if="isVlan" class="ml-2" variant="secondary">VLAN {{ vlanFromId }}</b-badge>
      </template>
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
        <b-button v-if="isClonable" :disabled="isLoading" class="ml-1" variant="outline-primary" @click="clone()">{{ $t('Clone') }}</b-button>
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Interface?')" @on-delete="remove()"/>
      </b-card-footer>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfButtonSave from '@/components/pfButtonSave'
import {
  view,
  validators
} from '@/views/Configuration/_config/interface'

export default {
  name: 'interface-view',
  components: {
    pfButtonDelete,
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
      return view(this.form, this.meta) // ../_config/interface
    },
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    isLoading () {
      return this.$store.getters['$_interfaces/isLoading']
    },
    isDisabled () {
      return this.invalidForm || this.isLoading
    },
    isClonable () {
      const { isNew, isClone, isVlan } = this
      return !isNew && !isClone && isVlan
    },
    isDeletable () {
      const { isNew, isClone, isVlan } = this
      return !isNew && !isClone && isVlan
    },
    isVlan () {
      const { form: { master = false } = {} } = this
      return master
    },
    actionKey () {
      return this.$store.getters['events/actionKey']
    },
    escapeKey () {
      return this.$store.getters['events/escapeKey']
    },
    vlanFromId () {
      const { 1: vlan = null } = this.id.split('.')
      return vlan
    }
  },
  methods: {
    init () {
      let promise
      this.$store.dispatch('$_interfaces/getInterface', this.id).then(form => {
        if (this.isNew) {
          promise = this.$store.dispatch(`${this.formStoreName}/setForm`, { id: form.id, type: 'none' })
        } else if (this.isClone) {
          promise = this.$store.dispatch(`${this.formStoreName}/setForm`, { ...form, id: form.master })
        } else {
          promise = this.$store.dispatch(`${this.formStoreName}/setForm`, form)
        }
        promise.then(() => { // wait for `form` before consuming `isVlan`
          const { id, isNew, isClone, isVlan } = this
          this.$store.dispatch(`${this.formStoreName}/setMeta`, { id, isNew, isClone, isVlan })
        })
      })
      this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
    },
    close () {
      this.$router.push({ name: 'configurator-interfaces' })
    },
    clone () {
      this.$router.push({ name: 'configurator-cloneInterface' })
    },
    create () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_interfaces/createInterface', this.form).then(() => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'configurator-interface', params: { id: `${this.form.id}.${this.form.vlan}` } })
        }
      })
    },
    save () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_interfaces/updateInterface', this.form).then(() => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        }
      })
    },
    remove () {
      this.$store.dispatch('$_interfaces/deleteInterface', this.id).then(() => {
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
    },
    'form.type' (a, b) {
      if (this.isNew && (a === 'inlinel2' && b !== 'inlinel2')) {
        this.$set(this.form, 'nat_enabled', 'enabled') // enable NAT by default w/ Inline L2
      }
    }
  }
}
</script>
