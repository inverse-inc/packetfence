<template>
  <div class="card-body">
    <div v-if="advancedMode || quickWithFields">
      <b-form inline @submit.prevent="onSubmit" @reset.prevent="onReset">
        <pf-search-boolean :model="condition" :fields="fields" :store="store" :advancedMode="advancedMode"/>
        <br/>
        <b-container fluid class="mt-3 px-0 text-right">
          <b-button type="reset" variant="outline-secondary">{{ $t('Reset') }}</b-button>
          <b-button-group>
            <b-button type="submit" variant="outline-primary">{{ $t('Search') }}</b-button>
            <b-dropdown variant="outline-primary" right>
              <b-dropdown-item @click="showExportJsonModal=true">{{ $t('Export to JSON') }}</b-dropdown-item>
              <b-dropdown-item @click="showImportJsonModal=true">{{ $t('Import from JSON') }}</b-dropdown-item>
              <b-dropdown-divider></b-dropdown-divider>
              <b-dropdown-item>...</b-dropdown-item>
            </b-dropdown>
          </b-button-group>
        </b-container>
      </b-form>
      <b-modal v-model="showExportJsonModal" size="lg" id="nodeExportJsonModal" :title="$t('Export to JSON')">
        <b-form-textarea ref="nodeExportJsonTextarea" v-model="JSON.stringify(condition)" :rows="3" :max-rows="3" readonly></b-form-textarea>
        <div slot="modal-footer">
          <b-button-group class="float-right">
            <b-button variant="outline-secondary" @click="showExportJsonModal=false">{{ $t('Cancel') }}</b-button>
            <b-button variant="primary" @click="copyNodeExportJsonTextarea">{{ $t('Copy to Clipboard') }}</b-button>
          </b-button-group>
        </div>
      </b-modal>
      <b-modal v-model="showImportJsonModal" size="lg" id="nodeImportJsonModal" :title="$t('Import from JSON')">
        <b-form-textarea ref="nodeImportJsonTextarea" v-model="json" :rows="3" :max-rows="3" :placeholder="$t('Enter JSON')"></b-form-textarea>
        <div slot="modal-footer">
          <b-button-group class="float-right">
            <b-button variant="outline-secondary" @click="showImportJsonModal=false">{{ $t('Cancel') }}</b-button>
            <b-button variant="primary" @click="importNodeImportJsonTextarea">{{ $t('Import JSON') }}</b-button>
          </b-button-group>
        </div>
      </b-modal>
    </div>
    <b-form @submit.prevent="onSubmit" @reset.prevent="onReset" v-else>
      <div class="input-group">
        <div class="input-group-prepend">
          <div class="input-group-text"><icon name="search"></icon></div>
        </div>
        <b-form-input v-model="quickValue" type="text" :placeholder="quickPlaceholder"></b-form-input>
        <b-button class="ml-1" type="submit" variant="outline-primary">{{ $t('Search') }}</b-button>
      </div>
    </b-form>
  </div>
</template>

<script>
import pfSearchBoolean from './pfSearchBoolean'

export default {
  name: 'pf-search',
  components: {
    'pf-search-boolean': pfSearchBoolean
  },
  props: {
    condition: {
      type: Object
    },
    advancedMode: {
      type: Boolean,
      default: false
    },
    fields: {
      type: Array
    },
    quickWithFields: {
      type: Boolean,
      default: true
    },
    quickPlaceholder: {
      type: String,
      default: 'Search'
    },
    store: {
      type: Object
    },
    showExportJsonModal: {
      type: Boolean,
      default: false
    },
    showImportJsonModal: {
      type: Boolean,
      default: false
    },
    json: {
      type: String
    }
  },
  data () {
    return {
      quickValue: '',
      condition: this.defaultCondition()
    }
  },
  computed: {
  },
  methods: {
    defaultCondition () {
      return { op: 'and', values: [{ op: 'or', values: [{ field: this.fields[0].value, op: null, value: null }] }] }
    },
    onSubmit (event) {
      let query = this.condition
      if (!this.advancedMode) {
        if (this.quickWithFields) {
          query.values.splice(1)
        } else {
          query = this.quickValue
        }
      }
      this.$emit('submit-search', query)
    },
    onReset (event) {
      this.condition = this.defaultCondition()
      this.$emit('reset-search')
    },
    copyNodeExportJsonTextarea () {
      this.$refs.nodeExportJsonTextarea.$el.select()
      document.execCommand('copy')
      this.showExportJsonModal = false
    },
    importNodeImportJsonTextarea () {
      try {
        const json = JSON.parse(this.json)
        this.$emit('import-search', json)
        this.json = ''
        this.showImportJsonModal = false
      } catch (e) {
        // noop
      }
    }
  },
  mounted () {
    if (!this.advancedMode && !this.quickWithFields) {
      this.quickValue = this.condition.values[0].value
    }
  }
}
</script>

