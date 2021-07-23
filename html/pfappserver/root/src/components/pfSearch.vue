<template>
  <div class="card-body">
    <!-- Advanced Search Mode -->
    <transition name="fade" mode="out-in">
    <div v-if="advancedMode">
      <b-form inline @submit.prevent="onSubmit" @reset.prevent="onReset">
        <pf-search-boolean :model="condition" :fields="fields" :advancedMode="advancedMode"/>
        <b-container fluid class="text-right mt-3 px-0">
          <b-button class="mr-1" type="reset" variant="secondary">{{ $t('Clear') }}</b-button>
          <b-button-group>
            <b-button type="submit" variant="primary">{{ $t('Search') }}</b-button>
          </b-button-group>
        </b-container>
      </b-form>
    </div>
    <!-- Simple Search Mode with Search Fields -->
    <b-form inline @submit.prevent="onSubmit" @reset.prevent="onReset" v-else-if="quickWithFields">
      <b-container class="px-0" fluid>
        <b-row class="align-items-center px-0" no-gutters>
          <b-col cols="auto" class="mr-auto">
            <pf-search-boolean :model="condition" :fields="fields" :store="store" :advancedMode="false"/>
          </b-col>
          <b-col cols="auto" align="right" class="flex-grow-0">
            <b-button type="reset" variant="secondary" class="mr-1">{{ $t('Clear') }}</b-button>
            <b-button type="submit" variant="primary">{{ $t('Search') }}</b-button>
          </b-col>
        </b-row>
      </b-container>
    </b-form>
    <!-- Quick Search Mode -->
    <b-form @submit.prevent="onSubmit" @reset.prevent="onReset" v-else>
      <div class="input-group">
        <div class="input-group-prepend">
          <div class="input-group-text"><icon name="search"></icon></div>
        </div>
        <b-form-input v-model="quickValue" type="text" :placeholder="quickPlaceholder"></b-form-input>
        <b-button class="ml-1" type="reset" variant="secondary">{{ $t('Clear') }}</b-button>
        <b-button class="ml-1" type="submit" variant="primary">{{ $t('Search') }}</b-button>
      </div>
    </b-form>
    </transition>
  </div>
</template>

<script>
import pfSearchBoolean from './pfSearchBoolean'

export default {
  name: 'pf-search',
  components: {
    pfSearchBoolean
  },
  props: {
    storeName: { // from router
      type: String,
      default: null
    },
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
    showExportJsonModal: {
      type: Boolean,
      default: false
    },
    showImportJsonModal: {
      type: Boolean,
      default: false
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
    },
    saveSearchNamespace: {
      type: String
    }
  },
  data () {
    return {
      quickValue: '',
      localShowExportJsonModal: this.showExportJsonModal,
      localShowImportJsonModal: this.showImportJsonModal,
      localShowSaveSearchModal: this.showSaveSearchModal,
      localSaveSearchString: this.saveSearchString,
      localImportJsonString: this.importJsonString,
      importJsonError: null
    }
  },
  computed: {
    jsonCondition () {
      return JSON.stringify(this.condition)
    },
    canSaveSearch () {
      return (this.saveSearchNamespace)
    }
  },
  methods: {
    onSubmit () {
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
    onReset () {
      this.quickValue = ''
      this.$emit('reset-search')
    }
  },
  mounted () {
    const { condition = null, advancedMode = false, quickWithFields = false } = this
    if (condition && !advancedMode && !quickWithFields) {
      this.quickValue = this.condition.values[0].value
    }
  },
  watch: {
    showExportJsonModal: {
      handler (a) {
        this.localShowExportJsonModal = a
      },
      immediate: true
    },
    showImportJsonModal: {
      handler (a) {
        this.localShowImportJsonModal = a
      },
      immediate: true
    },
    showSaveSearchModal: {
      handler (a) {
        this.localShowSaveSearchModal = a
      },
      immediate: true
    },
    saveSearchString: {
      handler (a) {
        this.localSaveSearchString = a
      },
      immediate: true

    }
  }
}
</script>
