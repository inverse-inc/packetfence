<template>
  <div class="card-body">
    <!-- Advanced Search Mode -->
    <div v-if="advancedMode">
      <b-form inline @submit.prevent="onSubmit" @reset.prevent="onReset">
        <pf-search-boolean :model="condition" :fields="fields" :store="store" :advancedMode="advancedMode" :defaultSearch="defaultSearch"/>
        <br/>
        <b-container fluid class="mt-3 px-0">
          <b-button-group>
            <b-button type="submit" variant="primary">{{ $t('Search') }}</b-button>
            <b-dropdown variant="primary" right>
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
          <b-button type="reset" variant="secondary">{{ $t('Clear') }}</b-button>
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
    <!-- Simple Search Mode with Search Fields -->
    <b-form inline @submit.prevent="onSubmit" @reset.prevent="onReset" v-else-if="quickWithFields">
      <b-form-row class="align-items-center">
        <b-col cols="auto" class="px-0 mr-auto">
          <pf-search-boolean :model="condition" :fields="fields" :store="store" :advancedMode="false"/>
        </b-col>
        <b-col cols="auto" align="right" class="flex-grow-0">
          <b-button type="submit" variant="primary">{{ $t('Search') }}</b-button>
          <b-button type="reset" variant="secondary">{{ $t('Clear') }}</b-button>
        </b-col>
      </b-form-row>
    </b-form>
    <!-- Quick Search Mode -->
    <b-form @submit.prevent="onSubmit" @reset.prevent="onReset" v-else>
      <div class="input-group">
        <div class="input-group-prepend">
          <div class="input-group-text"><icon name="search"></icon></div>
        </div>
        <b-form-input v-model="quickValue" type="text" :placeholder="quickPlaceholder"></b-form-input>
        <b-button class="ml-1" type="submit" variant="primary">{{ $t('Search') }}</b-button>
        <b-button class="ml-1" type="reset" variant="secondary">{{ $t('Clear') }}</b-button>
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
    defaultSearch: {
      type: Object
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
      console.log('pfSearch onSubmit ' + JSON.stringify(this.condition))
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
      this.quickValue = ''
      this.$emit('reset-search')
    },
    copyJsonTextarea () {
      if (document.queryCommandSupported('copy')) {
        this.$refs.exportJsonTextarea.$el.select()
        document.execCommand('copy')
        this.showExportJsonModal = false
        this.$store.dispatch('notification/info', {message: this.$i18n.t('Search copied to clipboard')})
      }
    },
    importJsonTextarea () {
      this.importJsonError = ''
      try {
        const json = JSON.parse(this.importJsonString)
        this.$emit('import-search', json)
        this.importJsonString = ''
        this.showImportJsonModal = false
        this.$store.dispatch('notification/info', {message: this.$i18n.t('Search imported')})
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
        _this.$store.dispatch('notification/info', {message: _this.$i18n.t('Search saved as ') + '\'' + _this.saveSearchString + '\''})
        _this.saveSearchString = ''
        _this.showSaveSearchModal = false
      })
    }
  },
  created () {
    console.log('2. pfSearch created')
  },
  mounted () {
    if (!this.advancedMode && !this.quickWithFields) {
      this.quickValue = this.condition.values[0].value
    }
    console.log('5. pfSearch mounted')
  }
}
</script>

