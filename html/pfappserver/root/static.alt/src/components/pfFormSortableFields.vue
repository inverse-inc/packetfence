<template>
  <b-form-group horizontal :label-cols="(columnLabel) ? labelCols : 0" :label="$t(columnLabel)"
    :state="isValid()" :invalid-feedback="getInvalidFeedback()" :class="[{ 'is-focus': drag }, { 'mb-0': !columnLabel }]">
    <b-input-group class="input-group-sortablefields">
      <b-container fluid class="px-0"
        @mouseleave="onMouseLeave()"
      >
        <draggable
          v-model="inputValue"
          :options="{handle: '.draghandle', dragClass: 'sortable-drag'}"
          @start="onDragStart"
          @end="onDragEnd"
        >
          <b-form-row
            v-for="(value, index) in inputValue"
            class="text-secondary align-items-center"
            align-v="center"
            :key="index"
            @mouseenter="onMouseEnter(index)"
            @mousemove="onMouseEnter(index)"
            no-gutter
          >
            <b-col col v-if="hover === index && inputValue.length > 1" class="draghandle text-center"><icon name="th"></icon></b-col>
            <b-col col v-else class="dragindex text-center"><b-badge variant="light">{{ index + 1 }}</b-badge></b-col>
            <b-col cols="4" class="text-left py-1">

              <pf-form-chosen
                :value="inputValue[index].type"
                :id="'chosen-' + index"
                label="text"
                track-by="value"
                :options="fields"
                @input="setType(index, $event)"
              ></pf-form-chosen>

            </b-col>
            <b-col cols="6" class="text-left py-1">

              <!-- BEGIN ADMINROLE -->
              <pf-form-chosen
                v-if="isFieldType(adminroleValueType, inputValue[index])"
                :value="inputValue[index].value"
                label="name"
                track-by="value"
                :options="values(inputValue[index])"
                @input="setValue(index, $event)"
              ></pf-form-chosen>

              <!-- BEGIN ROLE -->
              <pf-form-chosen
                v-if="isFieldType(roleValueType, inputValue[index])"
                :value="inputValue[index].value"
                label="name"
                track-by="value"
                :options="values(inputValue[index])"
                @input="setValue(index, $event)"
              ></pf-form-chosen>

              <!-- BEGIN TENANT -->
              <pf-form-chosen
                v-if="isFieldType(tenantValueType, inputValue[index])"
                :value="inputValue[index].value"
                label="name"
                track-by="value"
                :options="values(inputValue[index])"
                @input="setValue(index, $event)"
              ></pf-form-chosen>

              <!-- BEGIN DATETIME -->
              <pf-form-datetime
                v-if="isFieldType(datetimeValueType, inputValue[index])"
                v-model="inputValue[index].value"
                :config="{useCurrent: true}"
              ></pf-form-datetime>

              <!-- BEGIN DURATION -->
              <pf-form-chosen
                v-if="isFieldType(durationValueType, inputValue[index])"
                :value="inputValue[index].value"
                label="name"
                track-by="value"
                :options="values(inputValue[index])"
                @input="setValue(index, $event)"
              ></pf-form-chosen>

              <!-- BEGIN PREFIXMULTIPLER -->
              <pf-form-prefix-multiplier
                v-if="isFieldType(prefixmultiplerValueType, inputValue[index])"
                v-model="inputValue[index].value"
              ></pf-form-prefix-multiplier>

            </b-col>
            <b-col col class="text-center text-nowrap">
              <icon name="plus-circle" class="text-pointer mx-1" @click.native="rowAdd(index)"></icon>
              <icon name="minus-circle" v-if="inputValue.length > 1" class="text-pointer mx-1" @click.native="rowDel(index)"></icon>
            </b-col>
          </b-form-row>
        </draggable>

        <pre>{{ JSON.stringify(inputValue, null, 2) }}</pre>

      </b-container>
    </b-input-group>
    <b-form-text v-if="text" v-t="text"></b-form-text>
  </b-form-group>
</template>

<script>
/* eslint key-spacing: ["error", { "mode": "minimum" }] */
import draggable from 'vuedraggable'
import pfMixinValidation from '@/components/pfMixinValidation'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormDatetime from '@/components/pfFormDatetime'
import pfFormPrefixMultiplier from '@/components/pfFormPrefixMultiplier'
import {
  pfFieldType as fieldType,
  pfFieldTypeValues as fieldTypeValues
} from '@/globals/pfField'

export default {
  name: 'pf-form-sortable-fields',
  mixins: [
    pfMixinValidation
  ],
  components: {
    draggable,
    'pf-form-chosen': pfFormChosen,
    'pf-form-datetime': pfFormDatetime,
    'pf-form-prefix-multiplier': pfFormPrefixMultiplier
  },
  props: {
    value: {
      type: Array
    },
    columnLabel: {
      type: String
    },
    labelCols: {
      type: Number,
      default: 3
    },
    text: {
      type: String,
      default: null
    },
    fields: {
      type: Array,
      default: null
    }
  },
  data () {
    return {
      valuePlaceholder:         { type: null, value: null },
      hover:                    null,
      drag:                     false,
      /* Generic field types */
      noValueType:              fieldType.NONE,
      integerValueType:         fieldType.INTEGER,
      substringValueType:       fieldType.SUBSTRING,
      /* Custom element field types */
      datetimeValueType:        fieldType.DATETIME,
      prefixmultiplerValueType: fieldType.PREFIXMULTIPLIER,
      durationValueType:        fieldType.DURATION,
      /* Promise based field types */
      adminroleValueType:       fieldType.ADMINROLE,
      roleValueType:            fieldType.ROLE,
      tenantValueType:          fieldType.TENANT
    }
  },
  computed: {
    inputValue: {
      get () {
        const value = (this.value) ? this.value : [this.valuePlaceholder]
        const compressedValue = value.map(row => {
          return {
            type: (row.type && typeof row.type !== 'object')
              ? this.fields.find(field => field.value === row.type)
              : row.type,
            value: (row.value && typeof row.value !== 'object')
              ? this.values({ type: this.fields.find(field => field.value === row.type) }).find(value => value.value === row.value)
              : row.value
          }
        })
        return compressedValue
      },
      set (newValue) {
        const uncompressedValue = newValue.map(row => {
          return {
            type: ((row.type && row.type.value) ? this.fields.find(field => field.value === row.type.value).value : row.type),
            value: ((row.value && row.value.value) ? row.value.value : row.value)
          }
        })
        this.$emit('input', uncompressedValue)
      }
    }
    /*
    newValue [
      {
        "type": {
          "value": "set_access_duration",
          "text": "Access duration",
          "types": [
            "duration"
          ],
          "validations": {}
        },
        "value": null
      }
    ]
    */
  },
  methods: {
    setType (index, type) {
      let inputValue = JSON.parse(JSON.stringify(this.inputValue))
      inputValue[index].type = type
      inputValue[index].value = null
      this.inputValue = inputValue
    },
    setValue (index, value) {
      let inputValue = JSON.parse(JSON.stringify(this.inputValue))
      inputValue[index].value = value
      this.inputValue = inputValue
    },
    rowAdd (index) {
      let inputValue = JSON.parse(JSON.stringify(this.inputValue))
      // push placeholder into middle of array
      this.inputValue = [...inputValue.slice(0, index + 1), this.valuePlaceholder, ...inputValue.slice(index + 1)]
    },
    rowDel (index) {
      this.inputValue.splice(index, 1)
      if (this.inputValue.length === 0) {
        this.rowAdd(0)
      }
    },
    onDragStart (event) {
      this.drag = true
      this.hover = null
    },
    onDragEnd (event) {
      this.drag = false
    },
    onMouseEnter (index) {
      if (this.drag) return
      this.hover = index
    },
    onMouseLeave () {
      this.hover = null
    },
    values (inputValue) {
      if (!inputValue || !inputValue.type) return []
      let index = this.fields.findIndex(field => inputValue.type.value === field.value)
      let values = []
      if (index >= 0) {
        let field = this.fields[index]
        for (const type of field.types) {
          if (fieldTypeValues[type]) {
            values.push(...fieldTypeValues[type](this.$store))
          }
        }
      }
      return values
    },
    isFieldType (type, inputValue) {
      if (!inputValue.type) return false
      let index = this.fields.findIndex(field => inputValue.type.value === field.value)
      if (index >= 0) {
        let field = this.fields[index]
        if (field.types.includes(type)) {
          return true
        }
      }
      return false
    }
  }
}
</script>

<style lang="scss">
@import "../../node_modules/bootstrap/scss/functions";
@import "../../node_modules/bootstrap/scss/mixins/border-radius";
@import "../../node_modules/bootstrap/scss/mixins/transition";
@import "../styles/variables";

.form-group {
  .input-group-sortablefields {
    border: 1px solid $input-focus-bg;
    @include border-radius($border-radius);
    @include transition($custom-forms-transition);
    outline: 0;
  }
  &.is-focus {
    .input-group-sortablefields {
      border-color: $input-focus-border-color;
      box-shadow: 0 0 0 $input-focus-width rgba($input-focus-border-color, .25);
    }
  }
  &.is-invalid {
    .input-group-sortablefields {
      border-color: $form-feedback-invalid-color;
      box-shadow: 0 0 0 $input-focus-width rgba($form-feedback-invalid-color, .25);
    }
  }
  .form-row {
    &:not(:last-child) {
      border-bottom: 1px solid $input-focus-bg;
    }
  }
}
.draghandle {
  cursor: grab;
}
.dragindex {
  font-size: 80%
}
.text-pointer {
  cursor: pointer;
}
</style>
