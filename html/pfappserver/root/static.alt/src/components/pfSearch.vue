<template>
  <div class="card-body">
    <div v-if="advancedMode || quickWithFields">
      <b-form inline @submit.prevent="onSubmit" @reset.prevent="onReset">
        <pf-search-boolean :model="condition" :fields="fields" :store="store" :advancedMode="advancedMode"/>
        <br/>
        <b-container fluid class="mt-3 px-0 text-right">
          <b-button type="reset" variant="outline-secondary">{{ $t('Reset') }}</b-button>
          <b-button type="submit" variant="outline-primary">{{ $t('Search') }}</b-button>
        </b-container>
      </b-form>
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
    }
  },
  data () {
    return {
      quickValue: '',
      condition: { op: 'and', values: [{ op: 'or', values: [{ field: this.fields[0].value, op: null, value: null }] }] }
    }
  },
  computed: {
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
      this.condition = { op: 'and', values: [{ op: 'or', values: [{ field: this.fields[0].value, op: null, value: null }] }] }
      this.$emit('reset-search')
    }
  },
  mounted () {
    if (!this.advancedMode && !this.quickWithFields) {
      this.quickValue = this.condition.values[0].value
    }
  }
}
</script>

