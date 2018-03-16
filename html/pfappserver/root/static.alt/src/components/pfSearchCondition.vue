<template>
  <b-list-group-item>
    <b-form-row align-v="center" align-h="between" class="align-self-center justify-content-between" v-if="!isQuick">
      <b-form-radio-group v-model="model.op">
        <b-form-radio value="any">{{ $t('any') }}</b-form-radio>
        <b-form-radio value="and">{{ $t('and') }}</b-form-radio>
      </b-form-radio-group>
      <b-button variant="link-secondary" v-if="!isRoot" @click="removeCondition()"><icon name="minus-circle"></icon></b-button>
    </b-form-row>
    <div v-for="(rule, index) in model.values" :key="index">
      <div v-if="rule.field">
        <!-- A single condition -->
        <b-form-row align-v="center">
          <b-form-select v-model="rule.field" :options="fields"></b-form-select>
          <b-form-select v-model="rule.op" :options="operators(rule)"></b-form-select>
          <b-form-input v-model="rule.value" type="text" v-if="isFieldType(substringValueType, rule)"></b-form-input>
          <b-form-select v-model.lazy="rule.value" :options="values(rule)" v-else-if="isFieldType(selectValueType, rule)"></b-form-select>
          <b-button variant="link-secondary" v-if="index > 0" @click="removeRule(index)"><icon name="minus-circle"></icon></b-button>
        </b-form-row>
      </div>
      <b-list-group v-else>
        <!-- A set of conditions -->
        <pf-search-condition :model="rule" :fields="fields" @delete-search-condition="onRemoveCondition(rule)" :isQuick="isQuick"/>
      </b-list-group>
    </div>
    <b-form-row align-v="center" align-h="end" class="align-self-center justify-content-end" v-if="!isQuick">
      <b-button variant="link-secondary" @click="addRule()"><icon name="plus-circle"></icon></b-button>
      <b-button variant="link-secondary" @click="addOp()"><icon name="arrow-circle-right"></icon></b-button>
    </b-form-row>
  </b-list-group-item>
</template>

<script>
import Vue from 'vue'
import {
  pfSearchOperatorsForTypes as operatorsForTypes,
  pfSearchValuesForOperator as valuesForOperator,
  pfConditionOperators as conditionOperators,
  pfSearchConditionValue as conditionValue
} from '@/globals/pfSearch'

export default {
  name: 'pf-search-condition',
  components: {
  },
  props: {
    model: {
      type: Object
    },
    fields: {
      type: Array
    },
    store: {
      type: Object
    },
    isQuick: {
      type: Boolean,
      default: false
    },
    isRoot: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      substringValueType: conditionValue.TEXT,
      selectValueType: conditionValue.SELECT
    }
  },
  computed: {
  },
  methods: {
    operators (rule) {
      let _this = this
      let index = this.fields.findIndex(field => rule.field === field.value)
      if (index >= 0) {
        let field = this.fields[index]
        return operatorsForTypes(field.types).map(function (operator, index, operators) {
          if (index === 0 && !operators.includes(rule.op)) {
            // Preselect the first valid operator
            rule.op = operator
          }
          return { value: operator, text: _this.$i18n.t(operator) }
        })
      }
    },
    values (rule) {
      let index = this.fields.findIndex(field => rule.field === field.value)
      let values = []
      if (index >= 0) {
        let field = this.fields[index]
        values = valuesForOperator(field.types, rule.op, this.$store)
        if (values.length && values.findIndex(v => v.value === rule.value) < 0) {
          // Preselect the first valid value
          Vue.set(rule, 'value', values[0].value)
        }
      }
      return values
    },
    isFieldType (type, rule) {
      let isType = false
      let index = this.fields.findIndex(field => rule.field === field.value)
      if (index >= 0) {
        let field = this.fields[index]
        let found = false
        for (const t of field.types) {
          let operators = conditionOperators[t]
          for (const op of Object.keys(operators)) {
            if (op === rule.op) {
              isType = (operators[op] === type)
              found = true
              break
            }
          }
          if (found) {
            break
          }
        }
      }
      return isType
    },
    removeCondition () {
      this.$emit('delete-search-condition', this.model)
    },
    addRule () {
      this.model.values.push({ field: this.fields[0].value, op: null, value: null })
    },
    addOp () {
      this.model.values.push({ op: 'and', values: [{ field: this.fields[0].value, op: null, value: null }] })
    },
    removeRule (index) {
      this.model.values.splice(index, 1)
    },
    onRemoveCondition (rule) {
      let index = this.model.values.indexOf(rule)
      if (index >= 0) {
        this.model.values.splice(index, 1)
      }
    }
  },
  mounted () {
  }
}
</script>

