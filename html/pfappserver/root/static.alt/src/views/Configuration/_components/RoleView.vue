<template>
  <pf-config-view
    :isLoading="isLoading"
    :form="getForm"
    :model="role"
    :validation="$v.role"
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
import pfFormInput from '@/components/pfFormInput'
import pfMixinEscapeKey from '@/components/pfMixinEscapeKey'
const { validationMixin } = require('vuelidate')
const { required, alphaNum, integer } = require('vuelidate/lib/validators')

export default {
  name: 'RoleView',
  mixins: [
    validationMixin,
    pfMixinEscapeKey
  ],
  components: {
    pfConfigView,
    pfButtonSave,
    pfButtonDelete,
    pfFormInput
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    },
    id: { // from router
      type: String,
      default: null
    }
  },
  data () {
    return {
      role: {}, // will be overloaded with the data from the store
      roleValidations: {} // will be overloaded with data from the pfConfigView
    }
  },
  validations () {
    return {
      role: this.roleValidations
    }
  },
  computed: {
    isNew () {
      return this.id === null
    },
    isLoading () {
      return this.$store.getters['$_roles/isLoading']
    },
    invalidForm () {
      return this.$v.role.$invalid || this.$store.getters['$_roles/isWaiting']
    },
    getForm () {
      return {
        labelCols: 3,
        fields: [
          {
            if: this.isNew, // new roles only
            key: 'id',
            component: pfFormInput,
            label: this.$i18n.t('Name'),
            validators: {
              [this.$i18n.t('Name is required.')]: required,
              [this.$i18n.t('Alphanumeric value required.')]: alphaNum
            }
          },
          {
            key: 'notes',
            component: pfFormInput,
            label: this.$i18n.t('Description'),
            validators: {}
          },
          {
            key: 'max_nodes_per_pid',
            component: pfFormInput,
            label: this.$i18n.t('Max nodes per user'),
            attrs: {
              type: 'number'
            },
            validators: {
              [this.$i18n.t('Max nodes per user required.')]: required,
              [this.$i18n.t('Integer value required.')]: integer
            }
          }
        ]
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
