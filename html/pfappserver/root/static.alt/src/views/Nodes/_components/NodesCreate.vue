<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Create Node'"></h4>
    </b-card-header>
    <div class="card-body">
      <b-form @submit.prevent="create()">
        <b-form-row align-v="center">
          <b-col sm="12">
            <pf-form-input :column-label="$t('MAC')"
              v-model="single.mac"
              :vuelidate="$v.single.mac"
            />
            <pf-form-autocomplete :column-label="$t('Owner')"
              v-model="single.pid"
              :suggestions="matchingUsers"
              :vuelidate="$v.single.pid"
               placeholder="default"
              @search="searchUsers"
            />
            <pf-form-select :column-label="$t('Status')"
              v-model="single.status"
              :options="statuses"
              :vuelidate="$v.single.status"
            />
            <pf-form-select :column-label="$t('Role')"
             v-model="single.category"
             :options="roles"
              :vuelidate="$v.single.category"
            />
            <pf-form-datetime :column-label="$t('Unregistration')"
              v-model="single.unregdate"
              :moments="['1 hours', '1 days', '1 weeks', '1 months', '1 quarters', '1 years']"
              :vuelidate="$v.single.unregdate"
            />
            <pf-form-textarea :column-label="$t('Notes')"
              v-model="single.notes"
              :vuelidate="$v.single.notes"
              rows="3" max-rows="3"
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
import usersApi from '@/views/Users/_api'
import { pfRegExp as regExp } from '@/globals/pfRegExp'
import {
  pfSearchConditionType as conditionType,
  pfSearchConditionValues as conditionValues
} from '@/globals/pfSearch'
import {
  required
} from 'vuelidate/lib/validators'
import {
  isMacAddress,
  userExists,
  nodeExists
} from '@/globals/pfValidators'
import {
  pfDatabaseSchema as schema,
  buildValidationFromTableSchemas
} from '@/globals/pfDatabaseSchema'

const { validationMixin } = require('vuelidate')

export default {
  name: 'NodesCreate',
  components: {
    pfFormAutocomplete,
    pfFormDatetime,
    pfFormInput,
    pfFormSelect,
    pfFormTextarea
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
      single: {
        mac: '',
        status: 'reg'
      },
      matchingUsers: []
    }
  },
  validations () {
    return {
      single: buildValidationFromTableSchemas(
        schema.node, // use `node` table schema
        {
          // additional custom validations ...
          mac: {
            [this.$i18n.t('MAC address required.')]: required,
            [this.$i18n.t('Invalid MAC address.')]: isMacAddress,
            [this.$i18n.t('MAC address exists.')]: nodeExists
          },
          pid: {
            [this.$i18n.t('Owner does not exist.')]: userExists
          }
        }
      )
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
      return this.$v.single.$invalid || this.isLoading
    }
  },
  methods: {
    close () {
      this.$router.push({ name: 'nodes' })
    },
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
              { field: 'pid', op: 'contains', value: this.single.pid },
              { field: 'firstname', op: 'contains', value: this.single.pid },
              { field: 'lastname', op: 'contains', value: this.single.pid },
              { field: 'email', op: 'contains', value: this.single.pid }
            ]
          }]
        }
      }
      usersApi.search(body).then((data) => {
        _this.matchingUsers = data.items.map(item => item.pid)
      })
    },
    create () {
      this.$store.dispatch('$_nodes/createNode', this.single).then(() => this.close())
    }
  },
  created () {
    this.$store.dispatch('config/getRoles')
  }
}
</script>
