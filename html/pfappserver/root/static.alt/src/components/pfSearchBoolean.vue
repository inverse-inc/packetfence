<template>
  <b-container fluid class="px-0" v-if="!advancedMode">
    <!-- BEGIN SIMPLE SEARCH -->
    <b-row class="mx-auto">
      <b-input-group class="mr-1">
        <b-input-group-prepend is-text v-if="icon(model.values[0].values[0])">
          <icon :name="icon(model.values[0].values[0])"></icon>
        </b-input-group-prepend>
        <b-form-select v-model="model.values[0].values[0].field" :options="fields"></b-form-select>
      </b-input-group>
      <b-form-select class="mr-1" v-model="model.values[0].values[0].op" :options="operators(model.values[0].values[0])"></b-form-select>
      <b-form-input class="mr-1" type="text" v-model="model.values[0].values[0].value" v-if="isFieldType(substringValueType, model.values[0].values[0])"></b-form-input>
      <pf-form-datetime class="mr-1" v-model="model.values[0].values[0].value" v-else-if="isFieldType(datetimeValueType, model.values[0].values[0])" :config="{useCurrent: true}"></pf-form-datetime>
      <pf-form-prefix-multiplier class="mr-1" v-model="model.values[0].values[0].value" v-else-if="isFieldType(prefixmultipleValueType, model.values[0].values[0])"></pf-form-prefix-multiplier>
      <b-form-select class="mr-1" v-model.lazy="model.values[0].values[0].value" :options="values(model.values[0].values[0])" v-else-if="isFieldType(selectValueType, model.values[0].values[0])"></b-form-select>
    </b-row>
    <!-- END SIMPLE SEARCH -->
  </b-container>
  <b-container fluid class="px-0" v-else>
    <!-- BEGIN ADVANCED SEARCH -->
    <b-container fluid class="px-0" v-for="(rule, outerindex) in model.values" :key="outerindex">
      <b-container fluid class="rc px-0 py-1 bg-secondary">
        <draggable v-model="model.values[outerindex].values" :options="{group: 'or', handle: '.draghandle', filter: '.nodrag', dragClass: 'sortable-drag'}" @start="onDragStart" @end="onDragEnd">
          <b-container fluid class="px-1" v-for="(rule, innerindex) in model.values[outerindex].values" :key="innerindex">
            <b-row class="bg-white rc align-items-center m-0 p-1 isdrag">
              <span v-if="model.values.length > 1 || model.values[outerindex].values.length > 1" class="draghandle mx-2" v-b-tooltip.hover.right.d1000 :title="$t('Click & drag statement to reorder')">
                <icon name="grip-vertical"></icon>
              </span>
              <b-input-group class="mr-1">
                <b-input-group-prepend is-text v-if="icon(rule)">
                  <icon :name="icon(rule)"></icon>
                </b-input-group-prepend>
                <b-form-select v-model="rule.field" :options="fields"></b-form-select>
              </b-input-group>
              <b-form-select class="mr-1" v-model="rule.op" :options="operators(rule)"></b-form-select>
              <b-form-input type="text" class="mr-1" v-model="rule.value" v-if="isFieldType(substringValueType, rule)"></b-form-input>
              <pf-form-datetime class="mr-1" v-model="rule.value" v-else-if="isFieldType(datetimeValueType, rule)" :config="{useCurrent: true}" :moments="['-1 hours', '-1 days', '-1 weeks', '-1 months', '-1 quarters', '-1 years']"></pf-form-datetime>
              <pf-form-prefix-multiplier class="mr-1" v-model="rule.value" v-else-if="isFieldType(prefixmultipleValueType, rule)"></pf-form-prefix-multiplier>
              <b-form-select class="mr-1" v-model.lazy="rule.value" :options="values(rule)" v-else-if="isFieldType(selectValueType, rule)"></b-form-select>
              <b-button class="ml-auto mr-1 nodrag" v-if="model.values.length > 1 || model.values[outerindex].values.length > 1 && drag === false" variant="link" v-b-tooltip.hover.left.d1000 :title="$t('Delete statement')" @click="removeStatement(outerindex, innerindex)"><icon name="trash-alt"></icon></b-button>
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
                  <a href="javascript:void(0)" class="text-nowrap" @click="addInnerStatement(outerindex)">{{ $t('Add "or" statement') }}</a>
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
          <a href="javascript:void(0)" class="text-nowrap text-white" @click="addOuterStatement()">{{ $t('Add "and" statement') }}</a>
        </b-container>
      </b-col>
    </b-row>
    <!-- END ADVANCED SEARCH -->
  </b-container>
</template>

<script>
import draggable from 'vuedraggable'
import {
  pfSearchOperatorsForTypes as operatorsForTypes,
  pfSearchValuesForOperator as valuesForOperator,
  pfConditionOperators as conditionOperators,
  pfSearchConditionValue as conditionValue
} from '@/globals/pfSearch'
import pfFormDatetime from '@/components/pfFormDatetime'
import pfFormPrefixMultiplier from '@/components/pfFormPrefixMultiplier'

export default {
  name: 'pf-search-boolean',
  components: {
    draggable,
    pfFormDatetime,
    pfFormPrefixMultiplier
  },
  props: {
    model: {
      type: Object
    },
    fields: {
      type: Array
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
      selectValueType: conditionValue.SELECT,
      datetimeValueType: conditionValue.DATETIME,
      prefixmultipleValueType: conditionValue.PREFIXMULTIPLE
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
          return { value: operator, text: _this.$i18n.t(operator.replace(/_/g, ' ')) }
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
          this.$set(rule, 'value', values[0].value)
        }
      }
      return values
    },
    icon (rule) {
      let index = this.fields.findIndex(field => rule.field === field.value)
      if (index >= 0) {
        let field = this.fields[index]
        return field.icon || undefined
      }
      return undefined
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
      let field = this.fields[0].value
      let op = null
      // repeat last `field` and `op` - if exists
      if (this.model.values[outerindex].values.length > 0) {
        let lastindex = this.model.values[outerindex].values.length - 1
        field = this.model.values[outerindex].values[lastindex].field
        op = this.model.values[outerindex].values[lastindex].op
      }
      this.model.values[outerindex].values.push({ field: field, op: op, value: null })
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
@import "../../node_modules/bootstrap/scss/functions";
@import "../styles/variables";

.draghandle {
  line-height: 1em;
}

.rc,
.rc-t,
.rc-l,
.rc-tl {
  border-top-left-radius: $input-border-radius;
}
.rc,
.rc-t,
.rc-r,
.rc-tr {
  border-top-right-radius: $input-border-radius;
}
.rc,
.rc-b,
.rc-r,
.rc-br {
  border-bottom-right-radius: $input-border-radius;
}
.rc,
.rc-b
.rc-l,
.rc-bl {
  border-bottom-left-radius: $input-border-radius;
}
.sortable-drag .nodrag {
  display: none;
}
/**
 * The element pfFormDatetime uses a form-group block
 * that causes a line-break.
 */
.form-inline .form-control {
  width:auto;
}
.form-inline .form-group {
  display: inline-block;
  vertical-align: middle;
}
</style>
