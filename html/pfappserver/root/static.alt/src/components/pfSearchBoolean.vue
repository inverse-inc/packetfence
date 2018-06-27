<template>
  <b-container fluid class="px-0" v-if="!advancedMode">
    <!-- BEGIN SIMPLE SEARCH -->
    <b-container fluid class="rc px-1 py-1 bg-light">
      <b-row class="mx-auto">
        <b-col cols="12" class="bg-white rc">
          <b-container fluid class="mx-0 px-0 py-1">
            <b-form-select v-model="model.values[0].values[0].field" :options="fields"></b-form-select>
            <b-form-select v-model="model.values[0].values[0].op" :options="operators(model.values[0].values[0])"></b-form-select>
            <b-form-input v-model="model.values[0].values[0].value" type="text" v-if="isFieldType(substringValueType, model.values[0].values[0])"></b-form-input>
            <b-form-select v-model.lazy="model.values[0].values[0].value" :options="values(model.values[0].values[0])" v-else-if="isFieldType(selectValueType, model.values[0].values[0])"></b-form-select>
          </b-container>
        </b-col>
      </b-row>
    </b-container>
    <!-- END SIMPLE SEARCH -->
  </b-container>
  <b-container fluid class="px-0" v-else>
    <!-- BEGIN ADVANCED SEARCH -->
    <b-container fluid class="px-0" v-for="(rule, outerindex) in model.values" :key="outerindex">
      <!-- BEGIN NAVBAR
      <nav class="navbar navbar-dark navbar-expand-md pb-0">
        <div class="navbar-collapse collapse">
          <ul class="navbar-nav ml-auto">
            <li class="nav-item bg-secondary rc-t">
              <a class="nav-link text-white" href="#">{{ $t('delete') }}</a>
            </li>
          </ul>
        </div>
      </nav>
      END NAVBAR -->
      <b-container fluid class="rc px-0 py-1 bg-secondary">
        <draggable v-model="model.values[outerindex].values" :options="{group: 'or', handle: '.draghandle', filter: '.nodrag', dragClass: 'sortable-drag'}" @start="onDragStart" @end="onDragEnd"> 
          <b-container fluid class="px-1" v-for="(rule, innerindex) in model.values[outerindex].values" :key="innerindex">
            <b-row class="mx-auto isdrag">
              <b-col cols="12" class="bg-white rc">
                <b-container fluid class="mx-0 px-0 py-1">
                  <span v-if="model.values.length > 1 || model.values[outerindex].values.length > 1" class="draghandle mr-2" v-b-tooltip.hover.right :title="$t('Click &amp; Drag statement to reorder')"><icon name="ellipsis-v"></icon></span>
                  <b-form-select v-model="rule.field" :options="fields"></b-form-select>
                  <b-form-select v-model="rule.op" :options="operators(rule)"></b-form-select>
                  <b-form-input v-model="rule.value" type="text" v-if="isFieldType(substringValueType, rule)"></b-form-input>
                  <b-form-select v-model.lazy="rule.value" :options="values(rule)" v-else-if="isFieldType(selectValueType, rule)"></b-form-select>
                  <b-button v-if="model.values.length > 1 || model.values[outerindex].values.length > 1 && drag === false" variant="link" class="nodrag float-right mt-1 mr-1" v-b-tooltip.hover.left :title="$t('Delete statement')" @click="removeStatement(outerindex, innerindex)"><icon name="trash-alt"></icon></b-button>
                </b-container>
              </b-col>
            </b-row>
            <b-row class="mx-auto isdrag">
              <b-col cols="1"></b-col>
              <b-col cols="1" class="py-0 bg-white" style="min-width:60px;">
                <div class="mx-auto text-center text-nowrap font-weight-bold">{{ $t('or') }}</div>
              </b-col>
            </b-row>
            <b-row class="mx-auto nodrag" v-if="innerindex === model.values[outerindex].values.length - 1 && drag === false">
              <b-col cols="12" class="bg-white rc">
                <b-container class="mx-0 px-1 py-1">
                  <a href="#" class="text-nowrap" @click="addInnerStatement(outerindex)">{{ $t('Add "or" statement') }}</a>
                </b-container>  
              </b-col>
            </b-row>
          </b-container>
        </draggable>
      </b-container>
      <b-row class="mx-auto">
        <b-col cols="1"></b-col>
        <b-col cols="1" class="py-0 bg-secondary" style="min-width:60px;">
          <div class="mx-auto text-center text-nowrap text-white font-weight-bold">{{ $t('and') }}</div>
        </b-col>
      </b-row>
    </b-container>
    <b-row class="mx-auto">
      <b-col cols="12" class="bg-secondary rc">
        <b-container class="mx-0 px-1 py-1">
          <a href="#" class="text-nowrap text-white" @click="addOuterStatement()">{{ $t('Add "and" statement') }}</a>
        </b-container>  
      </b-col>
    </b-row>
    <!-- END ADVANCED SEARCH -->
  </b-container>
</template>

<script>
import Vue from 'vue'
import draggable from 'vuedraggable'
import {
  pfSearchOperatorsForTypes as operatorsForTypes,
  pfSearchValuesForOperator as valuesForOperator,
  pfConditionOperators as conditionOperators,
  pfSearchConditionValue as conditionValue
} from '@/globals/pfSearch'

export default {
  name: 'pf-search-boolean',
  components: {
    draggable
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
    advancedMode: {
      type: Boolean,
      default: false
    },
    drag: {
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
  watch: {
    advancedMode (a, b) {
      if (a === false) {
        // truncate model to singular
        this.model.values.length = 1
        this.model.values[0].values.length = 1
      }
    }
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
    addOuterStatement () {
      this.model.values.push({ op: 'or', values: [{ field: this.fields[0].value, op: null, value: null }] })
    },
    addInnerStatement (outerindex) {
      this.model.values[outerindex].values.push({ field: this.fields[0].value, op: null, value: null })
    },
    removeStatement (outerindex, innerindex) {
      if (this.model.values[outerindex].values.length === 1) {
        if (this.model.values.length > 1) {
          this.model.values.splice(outerindex, 1)
        }
      } else {
        this.model.values[outerindex].values.splice(innerindex, 1)
      }
    },
    onDragStart (event) {
      this.drag = true
    },
    onDragEnd (event) {
      this.drag = false
      for (var i = this.model.values.length - 1; i >= 0; i--) {
        if (this.model.values[i].values.length === 0) {
          this.model.values.splice(i, 1)
        }
      }
    }
  }
}
</script>

<style lang="scss" scoped>
.rc,
.rc-t,
.rc-l,
.rc-tl {
  border-top-left-radius: 0.5em;
}
.rc,
.rc-t,
.rc-r,
.rc-tr {
  border-top-right-radius: 0.5em;
}
.rc,
.rc-b,
.rc-r,
.rc-br {
  border-bottom-right-radius: 0.5em;
}
.rc,
.rc-b
.rc-l,
.rc-bl {
  border-bottom-left-radius: 0.5em;
}
.sortable-drag .nodrag {
  display: none;
}
</style>
