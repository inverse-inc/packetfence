<template>
    <div class="card-body">
        <div class="textright" v-if="!advancedMode">
            <b-form v-if="!quickWithFields" @submit.prevent="onSubmit" @reset.prevent="onReset">
              <div class="input-group">
                <div class="input-group-prepend">
                  <div class="input-group-text"><icon name="search"></icon></div>
                </div>
                <b-form-input v-model="quickValue" type="text" :placeholder="quickPlaceholder"></b-form-input>
                <b-button class="ml-1" type="submit" variant="outline-primary">{{ $t('Search') }}</b-button>
              </div>
            </b-form>
            <b-form inline @submit.prevent="onSubmit" @reset.prevent="onReset" v-else>
              <pf-search-condition :model="condition" :fields="fields" :store="store" :isQuick="true"/>
              <b-button type="reset" variant="outline-secondary">{{ $t('Reset') }}</b-button>
              <b-button type="submit" variant="outline-primary">{{ $t('Search') }}</b-button>
            </b-form>
        </div>
        <div v-if="advancedMode">
          <b-form inline @submit.prevent="onSubmit" @reset.prevent="onReset">
            <b-list-group>
              <pf-search-condition :model="condition" :fields="fields" :store="store" :isRoot="true"/>
            </b-list-group>
            <div>
              <b-button type="reset" variant="outline-secondary">{{ $t('Reset') }}</b-button>
              <b-button type="submit" variant="outline-primary">{{ $t('Search') }}</b-button>
            </div>
          </b-form>
        </div>
    </div>
</template>

<script>
import pfSearchCondition from './pfSearchCondition'

export default {
  name: 'pf-search',
  components: {
    'pf-search-condition': pfSearchCondition
  },
  props: {
    advancedMode: {
      type: Boolean
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
      condition: { op: 'and', values: [{ field: this.fields[0].value, op: null, value: null }] }
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
      this.condition = { op: 'and', values: [{ field: this.fields[0].value, op: null, value: null }] }
      this.$emit('reset-search')
    }
  }
}
</script>

