<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Create Nodes'"></h4>
    </b-card-header>
    <b-tabs v-model="modeIndex" card>

      <b-tab :title="$t('Single')">
        <b-form @submit.prevent="create()">
          <b-form-row align-v="center">
            <b-col sm="8">
              <pf-form-input v-model="single.mac" label="MAC"
                :validation="$v.single.mac" invalid-feedback="Enter a valid MAC address"/>
              <pf-form-input v-model="single.pid" label="Owner" placeholder="default" validation="$v.single.pid"/>
              <b-form-group horizontal label-cols="3" :label="$t('Status')">
                <b-form-select v-model="single.status" :options="statuses"></b-form-select>
              </b-form-group>
              <b-form-group horizontal label-cols="3" :label="$t('Role')">
                <b-form-select v-model="single.category" :options="roles"></b-form-select>
              </b-form-group>
              <b-form-group horizontal label-cols="3" :label="$t('Unregistration')">
                <b-form-row>
                  <b-col>
                    <b-form-input type="date" v-model="single.unreg_date"/>
                  </b-col>
                  <b-col>
                    <b-form-input type="time" v-model="single.unreg_time"/>
                  </b-col>
                </b-form-row>
              </b-form-group>
            </b-col>
            <b-col sm="4">
              <b-form-textarea :placeholder="$t('Notes')" v-model="single.notes" rows="8" max-rows="12"></b-form-textarea>
            </b-col>
          </b-form-row>
        </b-form>
      </b-tab>

      <b-tab :title="$t('Import')">
        <b-form>
          <b-form-group horizontal label-cols="3" label="CSV File">
            <b-form-file v-model="csv.file" accept="text/*" choose-label="Choose a file"></b-form-file>
          </b-form-group>
          <b-form-group horizontal label-cols="3" label="Column Delimiter">
            <b-form-select v-model="csv.delimiter" :options="csv.delimiters"></b-form-select>
          </b-form-group>
          <b-form-group horizontal label-cols="3" label="Default Voice Over IP">
            <b-form-checkbox v-model="csv.voip" value="yes"></b-form-checkbox>
          </b-form-group>
          <b-row>
            <b-col sm="3">{{ $t('Columns Order') }}</b-col>
            <b-col>
              <draggable v-model="csv.olumns" :options="{ handle: '.draggable-handle' }">
                <div class="draggable-item" v-for="(column, index) in csv.columns" :key="column.name">
                  <span class="draggable-handle">{{ index }}</span>
                  <b-form-checkbox v-model="column.value" value="1">{{column.text}}</b-form-checkbox>
                </div>
              </draggable>
            </b-col>
          </b-row>
        </b-form>
      </b-tab>
    </b-tabs>

    <b-card-footer align="right" @mouseenter="$v.$touch()">
      <b-button variant="outline-primary" :disabled="invalidForm" @click="create()">
        <icon name="circle-notch" spin v-show="isLoading"></icon> {{ $t('Create') }}
      </b-button>
    </b-card-footer>

  </b-card>
</template>

<script>
import pfFormInput from '@/components/pfFormInput'
import draggable from 'vuedraggable'
import {
  pfSearchConditionType as conditionType,
  pfSearchConditionValues as conditionValues
} from '@/globals/pfSearch'
const { validationMixin } = require('vuelidate')
const { macAddress, required } = require('vuelidate/lib/validators')

export default {
  name: 'NodesCreate',
  components: {
    draggable,
    'pf-form-input': pfFormInput
  },
  mixins: [
    validationMixin
  ],
  data () {
    return {
      modeIndex: 0,
      single: {
        mac: '',
        status: 'reg',
        unreg_time: '00:00:00'
      },
      csv: {
        file: null,
        delimiter: 'comma',
        delimiters: [
          { value: 'comma', text: 'Comma' },
          { value: 'semicolon', text: 'Semicolon' },
          { value: 'tab', text: 'Tab' }
        ],
        voip: null,
        columns: [
          { value: '1', name: 'mac', text: 'MAC Address' },
          { value: '0', name: 'owner', text: 'Owner' },
          { value: '0', name: 'role', text: 'Role' },
          { value: '0', name: 'unregdate', text: 'Unregistration Date' }
        ]
      }
    }
  },
  validations: {
    single: {
      mac: { macAddress: macAddress(), required }
    },
    csv: {
      file: { required }
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
    create () {
      if (this.modeIndex === 0) {
        this.$store.dispatch('$_nodes/createNode', this.single).then(response => {
          console.debug('node created')
        }).catch(err => {
          console.debug(err)
          console.debug(this.$store.state.$_nodes.message)
        })
      }
    }
  },
  created () {
    this.$store.dispatch('config/getRoles')
  }
}
</script>

