<template>
  <pf-config-view
    :form-store-name="formStoreName"
    :isLoading="isLoading"
    :disabled="isLoading"
    :view="view"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template v-slot:header>
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="mb-0">
        <span v-html="$t('Layer2 Network {id}', { id: $strong(id) })"></span>
      </h4>
    </template>
    <template v-slot:footer>
      <b-card-footer>
        <pf-button-save :disabled="isDisabled" :isLoading="isLoading" class="mr-1">
          <template v-if="actionKey">{{ $t('Save & Close') }}</template>
          <template v-else>{{ $t('Save') }}</template>
        </pf-button-save>
        <b-button :disabled="isLoading" class="mr-1" variant="outline-secondary" @click="init()">{{ $t('Reset') }}</b-button>
        <pf-button-service service="pfdhcp" class="mr-1" restart start stop></pf-button-service>
        <pf-button-service service="pfdns" class="mr-1" restart start stop></pf-button-service>
      </b-card-footer>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonService from '@/components/pfButtonService'
import {
  defaultsFromMeta as defaults
} from '../_config/'
import {
  view,
  validators
} from '../_config/layer2Network'

export default {
  name: 'layer2-network-view',
  components: {
    pfConfigView,
    pfButtonSave,
    pfButtonService
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
      return view(this.form, this.meta) // ../_config/layer2Network
    },
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    isLoading () {
      return this.$store.getters['$_layer2_networks/isLoading']
    },
    isDisabled () {
      return this.invalidForm || this.isLoading
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
      this.$store.dispatch('$_layer2_networks/options', this.id).then(options => {
        const { meta = {} } = options
        const { isNew } = this
        this.$store.dispatch(`${this.formStoreName}/setMeta`, { ...meta, ...{ isNew } })
        if (this.id) { // existing
          this.$store.dispatch('$_layer2_networks/getLayer2Network', this.id).then(form => {
            this.$store.dispatch(`${this.formStoreName}/setForm`, form)
          })
        } else { // new
          this.$store.dispatch(`${this.formStoreName}/setForm`, defaults(meta)) // set defaults
        }
      })
      this.$store.dispatch(`${this.formStoreName}/setFormValidations`, validators)
    },
    close () {
      this.$router.push({ name: 'interfaces' })
    },
    save () {
      const actionKey = this.actionKey
      this.$store.dispatch('$_layer2_networks/updateLayer2Network', this.form).then(() => {
        if (actionKey) { // [CTRL] key pressed
          this.close()
        }
      })
    }
  },
  created () {
    this.init()
  },
  watch: {
    escapeKey (pressed) {
      if (pressed) this.close()
    }
  }
}
</script>
