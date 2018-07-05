<template>
  <div class="card-body">
    <div v-if="advancedMode || quickWithFields">
      <b-form inline @submit.prevent="onSubmit" @reset.prevent="onReset">
        <pf-search-boolean :model="condition" :fields="fields" :store="store" :advancedMode="advancedMode"/>
        <br/>
        <b-container fluid class="mt-3 px-0 text-right">
          <b-button type="reset" variant="outline-secondary">{{ $t('Clear') }}</b-button>
          <b-button-group>
            <b-button type="submit" variant="outline-primary">{{ $t('Search') }}</b-button>
            <b-dropdown variant="outline-primary" right>
              <b-dropdown-item @click="showSaveSearchModal=true">
                <icon class="position-absolute mt-1" name="save"></icon>
                <span class="ml-4">{{ $t('Save Search') }}</span>
              </b-dropdown-item>
              <b-dropdown-divider></b-dropdown-divider>
              <b-dropdown-item @click="showExportJsonModal=true">
                <icon class="position-absolute mt-1" name="sign-out-alt"></icon>
                <span class="ml-4">{{ $t('Export to JSON') }}</span>
              </b-dropdown-item>
              <b-dropdown-item @click="showImportJsonModal=true">
                <icon class="position-absolute mt-1" name="sign-in-alt"></icon>
                <span class="ml-4">{{ $t('Import from JSON') }}</span>
              </b-dropdown-item>
            </b-dropdown>
          </b-button-group>
        </b-container>
      </b-form>
      <b-modal v-model="showExportJsonModal" size="lg" centered id="exportJsonModal" :title="$t('Export to JSON')">
        <b-form-textarea ref="exportJsonTextarea" v-model="jsonCondition" :rows="3" :max-rows="3" readonly></b-form-textarea>
        <div slot="modal-footer">
          <b-button-group class="float-right">
            <b-button variant="outline-secondary" @click="showExportJsonModal=false">{{ $t('Cancel') }}</b-button>
            <b-button variant="primary" @click="copyJsonTextarea">{{ $t('Copy to Clipboard') }}</b-button>
          </b-button-group>
        </div>
      </b-modal>
      <b-modal v-model="showImportJsonModal" size="lg" centered id="importJsonModal" :title="$t('Import from JSON')" @shown="focusImportJsonTextarea">
        <b-card v-if="importJsonError" class="mb-3" bg-variant="danger" text-variant="white"><icon name="exclamation-triangle" class="mr-1"></icon>{{ importJsonError }}</b-card>
        <b-form-textarea ref="importJsonTextarea" v-model="importJsonString" :rows="3" :max-rows="3" :placeholder="$t('Enter JSON')"></b-form-textarea>
        <div slot="modal-footer">
          <b-button-group class="float-right">
            <b-button variant="outline-secondary" @click="showImportJsonModal=false">{{ $t('Cancel') }}</b-button>
            <b-button variant="primary" @click="importJsonTextarea">{{ $t('Import JSON') }}</b-button>
          </b-button-group>
        </div>
      </b-modal>
      <b-modal v-model="showSaveSearchModal" size="lg" centered id="saveSearchModal" :title="$t('Save Search')" @shown="focusSaveSearchInput">
        <label for="saveSearchInput">{{ $t('Search Name') }}:</label>
        <b-form-input id="saveSearchInput" ref="saveSearchInput" v-model="saveSearchString" type="text" :placeholder="$t('Enter a unique name')"></b-form-input>
        <div slot="modal-footer">
          <b-button-group class="float-right">
            <b-button variant="outline-secondary" @click="showSaveSearchModal=false">{{ $t('Cancel') }}</b-button>
            <b-button variant="primary" @click="saveSearch">{{ $t('Save') }}</b-button>
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
    storeName: {
      type: String,
      default: null,
      required: true
    },
    showExportJsonModal: {
      type: Boolean,
      default: false
    },
    showImportJsonModal: {
      type: Boolean,
      default: false
    },
    importJsonError: {
      type: String
    },
    importJsonString: {
      type: String
    },
    showSaveSearchModal: {
      type: Boolean,
      default: false
    },
    saveSearchString: {
      type: String
    }
  },
  data () {
    return {
      quickValue: '',
      condition: null
    }
  },
  computed: {
    jsonCondition () {
      return JSON.stringify(this.condition)
    }
  },
  methods: {
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
      this.$emit('reset-search')
    },
    copyJsonTextarea () {
      if (document.queryCommandSupported('copy')) {
        this.$refs.exportJsonTextarea.$el.select()
        document.execCommand('copy')
        this.showExportJsonModal = false
      }
    },
    importJsonTextarea () {
      this.importJsonError = ''
      try {
        const json = JSON.parse(this.importJsonString)
        this.$emit('import-search', json)
        this.importJsonString = ''
        this.showImportJsonModal = false
      } catch (e) {
        if (e instanceof SyntaxError) {
          this.importJsonError = this.$i18n.t('Invalid JSON') + ': ' + e.message
        } else {
          this.importJsonError = this.$i18n.t('Unhandled error') + ': ' + e.message
        }
      }
    },
    focusImportJsonTextarea () {
      this.$refs.importJsonTextarea.focus()
    },
    focusSaveSearchInput () {
      this.$refs.saveSearchInput.focus()
    },
    saveSearch () {
      const _this = this
      this.$store.dispatch(`${this.storeName}/addSavedSearch`, {name: this.saveSearchString, query: this.condition}).then(response => {
        _this.saveSearchString = ''
        _this.showSaveSearchModal = false
      })
    }
  },
  mounted () {
    if (!this.advancedMode && !this.quickWithFields) {
      this.quickValue = this.condition.values[0].value
    }
  }
}
</script>

