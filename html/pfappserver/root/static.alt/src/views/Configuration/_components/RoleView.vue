
<template>
  <b-form @submit.prevent="save()">
    <b-card no-body>
      <b-card-header>
        <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
        <h4 class="mb-0">{{ $t('Role') }} <strong v-text="id"></strong></h4>
      </b-card-header>
      <div class="card-body">
        <pf-form-input v-model="roleContent.notes"
          :column-label="$t('Description')"
          :validation="$v.roleContent.notes"/>
        <pf-form-input v-model="roleContent.max_nodes_per_pid" type="number"
          :filter="globals.regExp.integerPositive"
          :validation="$v.roleContent.max_nodes_per_pid"
          :column-label="$t('Max nodes per user')"
          :text="$t('nodes')"/>
      </div>
      <b-card-footer @mouseenter="$v.roleContent.$touch()">
        <b-button variant="primary" type="submit" :disabled="invalidForm"><icon name="circle-notch" spin v-show="isLoading"></icon> {{ $t('Save') }}</b-button>
        <delete-button variant="danger" class="mr-3" :disabled="isLoading" :confirm="$t('Delete Role?')" @on-delete="deleteRole()">{{ $t('Delete') }}</delete-button>
      </b-card-footer>
    </b-card>
  </b-form>
</template>

<script>
import DeleteButton from '@/components/DeleteButton'
import pfFormInput from '@/components/pfFormInput'
import pfFormRow from '@/components/pfFormRow'
import { pfRegExp as regExp } from '@/globals/pfRegExp'
const { validationMixin } = require('vuelidate')
const { required, integer } = require('vuelidate/lib/validators')

export default {
  name: 'RoleView',
  components: {
    'delete-button': DeleteButton,
    'pf-form-row': pfFormRow,
    'pf-form-input': pfFormInput
  },
  mixins: [
    validationMixin
  ],
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    },
    id: String
  },
  data () {
    return {
      globals: {
        regExp: regExp
      },
      roleContent: { // will be overloaded with the data from the store
        pid: ''
      }
    }
  },
  validations: {
    roleContent: {
      max_nodes_per_pid: { required, integer }
    }
  },
  computed: {
    // role () {
    //   return this.$store.state.$_roles.roles[this.id]
    // },
    isLoading () {
      return this.$store.getters['$_roles/isLoading']
    },
    invalidForm () {
      return this.$v.roleContent.$invalid || this.$store.getters['$_roles/isLoading']
    }
  },
  methods: {
    close () {
      this.$router.push({ name: 'roles' })
    },
    save () {
      this.$store.dispatch('$_roles/updateRole', this.roleContent).then(response => {
        this.close()
      })
    },
    deleteRole () {
      this.$store.dispatch('$_roles/deleteRole', this.id).then(response => {
        this.close()
      })
    },
    onKeyup (event) {
      switch (event.keyCode) {
        case 27: // escape
          this.close()
      }
    }
  },
  created () {
    this.$store.dispatch('$_roles/getRole', this.id).then(data => {
      this.roleContent = Object.assign({}, data)
    })
  },
  mounted () {
    document.addEventListener('keyup', this.onKeyup)
  },
  beforeDestroy () {
    document.removeEventListener('keyup', this.onKeyup)
  }
}
</script>

<style>
</style>
