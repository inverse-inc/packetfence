<template>
  <pf-config-view
    :isLoading="isLoading"
    :form="getForm"
    :model="role"
    :vuelidate="$v.role"
    @validations="roleValidations = $event"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template slot="header" is="b-card-header">
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="mb-0">
        <span v-if="id">{{ $t('Role') }} <strong v-text="id"></strong></span>
        <span v-else>{{ $t('New Role') }}</span>
      </h4>
    </template>
    <template slot="footer" is="b-card-footer" @mouseenter="$v.role.$touch()">
      <pf-button-save :disabled="invalidForm" :isLoading="isLoading">{{ isNew? $t('Create') : $t('Save') }}</pf-button-save>
      <pf-button-delete v-if="!isNew" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Role?')" @on-delete="remove()"/>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfMixinEscapeKey from '@/components/pfMixinEscapeKey'
import {
  pfConfigurationRoleViewFields as fields,
  pfConfigurationRoleViewDefaults as defaults
} from '@/globals/pfConfigurationRoles'
const { validationMixin } = require('vuelidate')

export default {
  name: 'RoleView',
  mixins: [
    validationMixin,
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
      role: defaults(this), // will be overloaded with the data from the store
      roleValidations: {} // will be overloaded with data from the pfConfigView
    }
  },
  validations () {
    return {
      role: this.roleValidations
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_roles/isLoading']
    },
    invalidForm () {
      return this.$v.role.$invalid || this.$store.getters['$_roles/isWaiting']
    },
    getForm () {
      return {
        labelCols: 3,
        fields: fields(this)
      }
    }
  },
  methods: {
    close () {
      this.$router.push({ name: 'roles' })
    },
    create () {
      this.$store.dispatch('$_roles/createRole', this.role).then(response => {
        this.close()
      })
    },
    save () {
      this.$store.dispatch('$_roles/updateRole', this.role).then(response => {
        this.close()
      })
    },
    remove () {
      this.$store.dispatch('$_roles/deleteRole', this.id).then(response => {
        this.close()
      })
    }
  },
  created () {
    if (this.id) {
      this.$store.dispatch('$_roles/getRole', this.id).then(data => {
        this.role = Object.assign({}, data)
      })
    }
  }
}
</script>
