
<template>
  <b-form @submit.prevent="isNew? create() : save()">
    <b-card no-body>
      <b-card-header>
        <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
        <h4 class="mb-0">
          <span v-if="id">{{ $t('Role') }} <strong v-text="id"></strong></span>
          <span v-else>{{ $t('New Role') }}</span>
        </h4>
      </b-card-header>
      <div class="card-body">
        <pf-form-input v-if="isNew" v-model="role.id"
          :column-label="$t('Name')"
          :validation="$v.role.id"
        />
        <pf-form-input v-model="role.notes"
          :column-label="$t('Description')"
          :validation="$v.role.notes"
        />
        <pf-form-input v-model="role.max_nodes_per_pid"
          :column-label="$t('Max nodes per user')"
          :filter="globals.regExp.integerPositive"
          :validation="$v.role.max_nodes_per_pid"
          :text="$t('nodes')"
          type="number"
        />
      </div>
      <b-card-footer @mouseenter="$v.role.$touch()">
        <pf-button-save :disabled="invalidForm" :isLoading="isLoading">{{ isNew? $t('Create') : $t('Save') }}</pf-button-save>
        <pf-button-delete v-if="!isNew" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Role?')" @on-delete="deleteRole()"/>
      </b-card-footer>
    </b-card>
  </b-form>
</template>

<script>
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfFormInput from '@/components/pfFormInput'
import pfFormRow from '@/components/pfFormRow'
import MixinEscapeKey from './MixinEscapeKey'
import { pfRegExp as regExp } from '@/globals/pfRegExp'
const { validationMixin } = require('vuelidate')
const { required, alphaNum, integer } = require('vuelidate/lib/validators')

export default {
  name: 'BaseView',
  components: {
    pfButtonSave,
    pfButtonDelete,
    pfFormRow,
    pfFormInput
  },
  mixins: [
    validationMixin,
    MixinEscapeKey
  ],
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
      globals: {
        regExp: regExp
      },
      role: {} // will be overloaded with the data from the store
    }
  },
  validations () {
    return {
      role: {
        id: { required, alphaNum },
        max_nodes_per_pid: { required, integer }
      }
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
    deleteRole () {
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
