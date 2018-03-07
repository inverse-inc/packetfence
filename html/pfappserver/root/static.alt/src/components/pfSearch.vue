<template>
    <div class="card-body">
        <div v-if="!advancedMode">
            <b-form v-if="quickWithoutFields">
              <div class="input-group">
                <div class="input-group-prepend">
                  <div class="input-group-text"><icon name="search"></icon></div>
                </div>
                <b-form-input v-model="quickSearch" type="text" :placeholder="quickPlaceholder"></b-form-input>
              </div>
            </b-form>
            <b-form class="d-flex" inline v-else>
              <b-form-select v-model="values[0].field" :options="fields"></b-form-select>
              <b-form-select v-model="values[0].op" :options="operators(0)"></b-form-select>
              <b-form-input  v-model="values[0].value" type="text"></b-form-input>
              <!-- <b-button class="ml-auto" type="submit">Search</b-button> -->
            </b-form>
        </div>
        <div v-if="advancedMode">
          <b-form inline>
          </b-form>
        </div>
    </div>
</template>

<script>
import { pfConditionOperators as conditionOperators } from '@/globals/pfSearch'

export default {
  name: 'pf-search',
  components: {
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
    }
  },
  data () {
    return {
      quickSearch: '',
      values: [{ field: null, op: null, value: null }]
    }
  },
  computed: {
  },
  methods: {
    operators: function (i) {
      var value = this.values[i]
      var option = this.fields.filter(option => value.field === option.value)
      if (option.length) {
        return conditionOperators[option[0].type]
          .map(function (operator) {
            return { value: operator, text: operator + ' loc' }
          })
      }
    }
  }
}
</script>

