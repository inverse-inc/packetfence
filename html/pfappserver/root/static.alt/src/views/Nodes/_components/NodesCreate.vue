<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Create Nodes'"></h4>
    </b-card-header>
    <b-tabs v-model="modeIndex" card>

      <b-tab :title="$t('Single')">
        <b-form>
          <pf-form-input v-model="single.mac" label="MAC"
            :validation="$v.single.mac" invalid-feedback="Enter a valid MAC address"/>
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

    <b-card-footer align="right">
      <b-button variant="outline-primary" :disabled="invalidForm" v-t="'Create'"></b-button>
    </b-card-footer>

  </b-card>
</template>

<script>
import pfFormInput from '@/components/pfFormInput'
import draggable from 'vuedraggable'
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
        mac: ''
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
    invalidForm () {
      if (this.modeIndex === 0) {
        return this.$v.single.$invalid
      } else {
        return false
      }
    }
  },
  methods: {
    macFormat (value, event) {
      var re = /[a-fA-F0-9]{2}/g
      var validMac = []
      var match
      while ((match = re.exec(value))) {
        validMac.push(match[0].toUpperCase())
      }
      match = /^(?:[a-fA-F0-9]{2}:?)*([a-fA-F0-9])$/g.exec(value)
      if (match) {
        validMac.push(match[1].toUpperCase())
      }
      // this.$nextTick(function () {
      //   this.mac = validMac.slice(0, 6).join(':')
      // })
      return validMac.slice(0, 6).join(':')
    }
  }
}
</script>

