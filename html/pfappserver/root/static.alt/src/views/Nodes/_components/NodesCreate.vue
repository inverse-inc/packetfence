<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Create Nodes'"></h4>
    </b-card-header>
    <div class="card-body">
      <b-form @submit.prevent="create()">
        <b-form-row align-v="center">
          <b-col sm="8">
            <pf-form-input v-model="single.mac" :label="$t('MAC')" 
              :filter="globals.regExp.stringMac"
              :validation="$v.single.mac" 
              :invalid-feedback="[
                { 'MAC address required': !$v.single.mac.required },
                { 'Enter a valid MAC address': !$v.single.mac.macAddress || !$v.single.mac.minLength || !$v.single.mac.maxLength },
                { 'MAC address already exists': !$v.single.mac.nodeExists }
              ]
            "/>
            <pf-form-autocomplete v-model="single.pid" :label="$t('Owner')" placeholder="default" @search="searchUsers" 
              :suggestions="matchingUsers"
              :validation="$v.single.pid"
              :invalid-feedback="[
                { 'Owner does not exist': !$v.single.pid.userExists }
              ]"
            />
            <pf-form-select v-model="single.status" :label="$t('Status')" :options="statuses"/>
            <pf-form-select v-model="single.category" :label="$t('Role')" :options="roles"/>
            <pf-form-datetime v-model="single.unregdate" :label="$t('Unregistration')" :moments="['1 hours', '1 days', '1 weeks', '1 months', '1 quarters', '1 years']"
              :validation="$v.single.unregdate"
              :invalid-feedback="[
                { 'Invalid date': !$v.single.unregdate.isDateFormat }
              ]"
            />
            <pf-form-textarea v-model="single.notes" :label="$t('Notes')" rows="8" max-rows="12"
              :validation="$v.single.notes"
              :invalid-feedback="[
                { [`Maximum ${globals.schema.person.notes.maxLength} characters`]: !$v.single.notes.maxLength }
              ]"
            />
          </b-col>
        </b-form-row>
      </b-form>
    </div>
    <b-card-footer @mouseenter="$v.$touch()">
      <b-button variant="primary" :disabled="invalidForm" @click="create()">
        <icon name="circle-notch" spin v-show="isLoading"></icon> {{ $t('Create') }}
      </b-button>
    </b-card-footer>

  </b-card>
</template>

<script>
import pfFormAutocomplete from '@/components/pfFormAutocomplete'
import pfFormDatetime from '@/components/pfFormDatetime'
import pfFormInput from '@/components/pfFormInput'
import pfFormSelect from '@/components/pfFormSelect'
import pfFormTextarea from '@/components/pfFormTextarea'
import draggable from 'vuedraggable'
import usersApi from '@/views/Users/_api'
import { pfRegExp as regExp } from '@/globals/pfRegExp'
import {
  pfSearchConditionType as conditionType,
  pfSearchConditionValues as conditionValues
} from '@/globals/pfSearch'
import {
  required,
  macAddress,
  minLength,
  maxLength
} from 'vuelidate/lib/validators'
import {
  isDateFormat,
  userExists,
  nodeExists
} from '@/globals/pfValidators'
import { pfDatabaseSchema as schema } from '@/globals/pfDatabaseSchema'

const { validationMixin } = require('vuelidate')

export default {
  name: 'NodesCreate',
  components: {
    draggable,
    'pf-form-autocomplete': pfFormAutocomplete,
    'pf-form-datetime': pfFormDatetime,
    'pf-form-input': pfFormInput,
    'pf-form-select': pfFormSelect,
    'pf-form-textarea': pfFormTextarea
  },
  mixins: [
    validationMixin
  ],
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    }
  },
  data () {
    return {
      globals: {
        regExp: regExp,
        schema: schema
      },
      modeIndex: 0,
      single: {
        mac: '',
        status: 'reg'
      },
      matchingUsers: []
    }
  },
  validations () {
    return {
      single: {
        mac: {
          required,
          macAddress,
          nodeExists,
          minLength: minLength(17),
          maxLength: maxLength(17)
        },
        pid: { userExists },
        unregdate: { isDateFormat: isDateFormat('YYYY-MM-DD HH:mm:ss') },
        notes: { maxLength: maxLength(schema.node.notes.maxLength) }
      }
    }
  },
  computed: {
    statuses () {
      return conditionValues[conditionType.NODE_STATUS]
    },
    roles () {
      return this.$store.getters['config/rolesList']
    },
    isLoading () {
      return this.$store.getters['$_nodes/isLoading']
    },
    invalidForm () {
      if (this.modeIndex === 0) {
        return this.$v.single.$invalid || this.isLoading
      } else {
        return false
      }
    }
  },
  methods: {
    searchUsers () {
      const _this = this
      let body = {
        limit: 10,
        fields: ['pid', 'firstname', 'lastname', 'email'],
        sort: ['pid'],
        query: {
          op: 'and',
          values: [{
            op: 'or',
            values: [
              {field: 'pid', op: 'contains', value: this.single.pid},
              {field: 'firstname', op: 'contains', value: this.single.pid},
              {field: 'lastname', op: 'contains', value: this.single.pid},
              {field: 'email', op: 'contains', value: this.single.pid}
            ]
          }]
        }
      }
      usersApi.search(body).then((data) => {
        _this.matchingUsers = data.items.map(item => item.pid)
      })
    },
    create () {
      if (this.modeIndex === 0) {
        this.$store.dispatch('$_nodes/createNode', this.single).then(response => {
          this.$store.dispatch('notification/info', {message: this.$i18n.t('Node') + ' ' + this.single.mac + ' ' + this.$i18n.t('created')})
          this.single = {
            mac: '',
            status: 'reg'
          }
        }).catch(err => {
          this.$store.dispatch('notification/danger', {message: this.$store.state[this.storeName].message})
          console.debug(err)
          console.debug(this.$store.state[this.storeName].message)
        })
      }
    }
  },
  created () {
    this.$store.dispatch('config/getRoles')
  }
}
</script>
