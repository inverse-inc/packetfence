<template>
    <div class="card-body">
        <div class="textright" v-if="!advancedMode">
            <b-form v-if="quickWithoutFields" @submit.prevent="onSubmit">
              <div class="input-group">
                <div class="input-group-prepend">
                  <div class="input-group-text"><icon name="search"></icon></div>
                </div>
                <b-form-input v-model="quickValue" type="text" :placeholder="quickPlaceholder"></b-form-input>
                <b-button type="submit" variant="outline-primary">{{ $t('Search') }}</b-button>
              </div>
            </b-form>
            <b-form inline @submit.prevent="onSubmit" v-else>
              <pf-search-condition :model="condition" :fields="fields" :store="store" :isQuick="true"/>
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
    quickWithoutFields: {
      type: Boolean,
      default: false
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
      this.$emit('submit-search', this.condition)
    },
    onReset (event) {
      this.condition = { op: 'and', values: [{ field: this.fields[0].value, op: null, value: null }] }
    }
  }
}
</script>

