<template>
  <b-card class="mt-3" header-tag="header" no-body>
    <div slot="header">
      <h4>Create Nodes</h4>
    </div>
    <div slot="actions">
    </div>
    <b-tabs card>
      <b-tab title="Single">
        <b-form :validated="validForm">
          <b-form-group horizontal label-cols="3" label="MAC">
            <b-form-input v-model.trim="mac" @blur="macVisited = true" :state="macState" :formatter="macFormat" required></b-form-input>
            <b-form-feedback>Enter a valid MAC address</b-form-feedback>
          </b-form-group>
          <b-form-group horizontal label-cols="3" class="mt-3">
            <b-button variant="outline-primary" :disabled="!validForm">Create Node</b-button>
          </b-form-group>
        </b-form>
      </b-tab>
      <b-tab title="Multiple">
        <b-form>
          <b-form-group horizontal label-cols="3" label="CSV File">
            <b-form-file v-model="file" accept="text/*" choose-label="Choose a file" required></b-form-file>
          </b-form-group>
          <b-form-group horizontal label-cols="3" label="Column Delimiter">
            <b-form-select v-model="delimiter" :options="delimiters"></b-form-select>
          </b-form-group>
          <b-form-group horizontal label-cols="3" label="Default Voice Over IP">
            <b-form-checkbox v-model="voip" value="yes"></b-form-checkbox>
          </b-form-group>
          <b-row>
            <b-col sm="3">Columns Order</b-col>
            <b-col>
              <draggable v-model="columns" :options="{ handle: '.draggable-handle' }">
                <div class="draggable-item" v-for="(column, index) in columns">
                  <span class="draggable-handle">{{ index }}</span>
                  <b-form-checkbox v-model="column.value" value="1">{{column.text}}</b-form-checkbox>
                </div>
              </draggable>
            </b-col>
          </b-row>
          <b-form-group horizontal label-cols="3" class="mt-3">
            <b-button variant="outline-primary">Create Nodes</b-button>
          </b-form-group>
        </b-form>
      </b-tab>
    </b-tabs>
  </b-card>
</template>

<script>
import draggable from 'vuedraggable'

export default {
  name: 'NodesCreate',
  components: {
    draggable
  },
  data () {
    return {
      mac: '',
      macVisited: false,
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
  },
  computed: {
    macState () {
      var macRE = /^([A-Fa-f0-9]{2}[:]){5}[A-Fa-f0-9]{2}$/
      return macRE.test(this.mac) ? true : (this.macVisited ? false : null)
    },
    validForm () {
      return this.macState === true
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

