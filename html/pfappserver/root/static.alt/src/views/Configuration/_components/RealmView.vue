<template>
  <pf-config-view
    :isLoading="isLoading"
    :form="getForm"
    :model="realm"
    :vuelidate="$v.realm"
    @validations="realmValidations = $event"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template slot="header" is="b-card-header">
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="mb-0">
        <span v-if="id">{{ $t('Realm') }} <strong v-text="id"></strong></span>
        <span v-else>{{ $t('New Realm') }}</span>
      </h4>
    </template>
    <template slot="footer"
      scope="{isDeletable}"
    >
      <b-card-footer @mouseenter="$v.realm.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">
          <template v-if="isNew">{{ $t('Create') }}</template>
          <template v-else-if="isClone">{{ $t('Clone') }}</template>
          <template v-else-if="ctrlKey">{{ $t('Save &amp; Close') }}</template>
          <template v-else>{{ $t('Save') }}</template>
        </pf-button-save>
        <pf-button-delete v-if="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Realm?')" @on-delete="remove()"/>
      </b-card-footer>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfMixinCtrlKey from '@/components/pfMixinCtrlKey'
import pfMixinEscapeKey from '@/components/pfMixinEscapeKey'
import {
  pfConfigurationRealmViewFields as fields,
  pfConfigurationRealmViewDefaults as defaults
} from '@/globals/pfConfigurationRealms'
const { validationMixin } = require('vuelidate')

export default {
  name: 'RealmView',
  mixins: [
    validationMixin,
    pfMixinCtrlKey,
    pfMixinEscapeKey
  ],
  components: {
    pfConfigView,
    pfButtonSave,
    pfButtonDelete
  },
  props: {
    storeName: { // from router
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
  data () {
    return {
      domains: [],
      realm: defaults(this), // will be overloaded with the data from the store
      realmValidations: {} // will be overloaded with data from the pfConfigView
    }
  },
  validations () {
    return {
      realm: this.realmValidations
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_realms/isLoading']
    },
    invalidForm () {
      return this.$v.realm.$invalid || this.$store.getters['$_realms/isWaiting']
    },
    getForm () {
      return {
        labelCols: 3,
        fields: fields(this)
      }
    },
    isDeletable () {
      if (this.isNew || this.isClone || ('not_deletable' in this.realm && this.realm.not_deletable)) {
        return false
      }
      return true
    }
  },
  methods: {
    close () {
      this.$router.push({ name: 'realms' })
    },
    create () {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch('$_realms/createRealm', this.realm).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
          this.close()
        } else {
          this.$router.push({ name: 'realm', params: { id: this.realm.id } })
        }
      })
    },
    save () {
      const ctrlKey = this.ctrlKey
      this.$store.dispatch('$_realms/updateRealm', this.realm).then(response => {
        if (ctrlKey) { // [CTRL] key pressed
          this.close()
        }
      })
    },
    remove () {
      this.$store.dispatch('$_realms/deleteRealm', this.id).then(response => {
        this.close()
      })
    }
  },
  mounted () {
    this.$store.dispatch('$_domains/all').then(items => {
      this.domains = items.map(domain => domain.id)
      if (this.isNew && this.domains.length > 0) {
        this.realm.domain = this.domains[0]
      }
    })
  },
  created () {
    if (this.id) {
      this.$store.dispatch('$_realms/getRealm', this.id).then(data => {
        this.realm = Object.assign({}, data)
      })
    }
  }
}
</script>
