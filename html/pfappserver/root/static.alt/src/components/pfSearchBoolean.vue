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
            <date-picker v-model="model.values[0].values[0].value" v-else-if="isFieldType(datetimeValueType, model.values[0].values[0])" :config="datetimeConfig"></date-picker>
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
                  <date-picker v-model="rule.value" v-else-if="isFieldType(datetimeValueType, rule)" :config="datetimeConfig"></date-picker>
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
import datePicker from 'vue-bootstrap-datetimepicker'
import 'pc-bootstrap4-datetimepicker/build/css/bootstrap-datetimepicker.css'
import {
  pfSearchOperatorsForTypes as operatorsForTypes,
  pfSearchValuesForOperator as valuesForOperator,
  pfConditionOperators as conditionOperators,
  pfSearchConditionValue as conditionValue
} from '@/globals/pfSearch'

export default {
  name: 'pf-search-boolean',
  components: {
    draggable,
    datePicker
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
      selectValueType: conditionValue.SELECT,
      datetimeValueType: conditionValue.DATETIME,
      datetimeConfig: {
        debug: false,
        format: 'YYYY-MM-DD HH:mm:ss',
        stepping: 5,
        collapse: true,
        icons: {
          time: 'icon-datetime icon-datetime-time',
          date: 'icon-datetime icon-datetime-date',
          up: 'icon-datetime icon-datetime-up',
          down: 'icon-datetime icon-datetime-down',
          previous: 'icon-datetime icon-datetime-previous',
          next: 'icon-datetime icon-datetime-next',
          today: 'icon-datetime icon-datetime-today',
          clear: 'icon-datetime icon-datetime-clear',
          close: 'icon-datetime icon-datetime-close'
        },
        sideBySide: true,
        showTodayButton: true,
        showClear: true,
        showClose: true,
        tooltips: {
          today: this.$i18n.t('Go to today'),
          clear: this.$i18n.t('Clear selection'),
          close: this.$i18n.t('Close the picker'),
          selectMonth: this.$i18n.t('Select Month'),
          prevMonth: this.$i18n.t('Previous Month'),
          nextMonth: this.$i18n.t('Next Month'),
          selectYear: this.$i18n.t('Select Year'),
          prevYear: this.$i18n.t('Previous Year'),
          nextYear: this.$i18n.t('Next Year'),
          selectDecade: this.$i18n.t('Select Decade'),
          prevDecade: this.$i18n.t('Previous Decade'),
          nextDecade: this.$i18n.t('Next Decade'),
          prevCentury: this.$i18n.t('Previous Century'),
          nextCentury: this.$i18n.t('Next Century'),
          incrementHour: this.$i18n.t('Increment Hour'),
          pickHour: this.$i18n.t('Pick Hour'),
          decrementHour: this.$i18n.t('Decrement Hour'),
          incrementMinute: this.$i18n.t('Increment Minute'),
          pickMinute: this.$i18n.t('Pick Minute'),
          decrementMinute: this.$i18n.t('Decrement Minute'),
          incrementSecond: this.$i18n.t('Increment Second'),
          pickSecond: this.$i18n.t('Pick Second'),
          decrementSecond: this.$i18n.t('Decrement Second')
        }
      }
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

<style lang="scss">
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

.icon-datetime {
  opacity:0.25;
  transition: all 300ms ease;
}
.icon-datetime:hover {
  opacity:1;
}
.icon-datetime-time {
  content:url(data:image/png;base64,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);
}
.icon-datetime-date {
  content:url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADgAAABACAYAAABP97SyAAACcElEQVRoQ+1bTUsbURS9Z7SNgpXuCi67En+BIkigiJmNk40Zl7b2F7gTNy4kS39Babc1K9PNFKQQBBH/gLjqstCdX6BRO1em1SAy5s28N+Fd05ftvHPuOfck772ZeQHl/MwF4YYHWkuFMdejZiP9WsY6RfMjY93OsEoQXgA09ITBdtRspF/LWKho/twG/WrI3bRG21u5OR/yFc2fW0zRAh43q2h+Z7DXHe41v0uw1x3uNX8nQd/3S/HLVx89YIWI3mac1aUN+xkzb3pXZ5+iKGon4v4anJ1fHBtEvEPAhDTFWnqYD2/Ym9359vUXiNY9PzjcJWBai0wqiHkvak7MYC4I33ugz1J1GumKeRl+UNsnYNKISCqY6QB+EJ4QaFSqRiNdTKdQbY2MCggAO4MCQjCS8B8kGNQuCSgZtUkqmLmdrINPP4KQKjyrLuZ67ruJrNxSxjmDUpLQ1dH/Cfb9JNP1OaTu90IKLlkm3F5UShqaOlyCmo0TA3MJiolCU4g6Qea1qNmop/FXqrVVEFKvdcZbxisNXhz/ftFqtW7SDJbL5cHh12+uuzXXNl5pUPW+T7WO2sY7g7YTMK3vEqT26dD9m5rHk0nyRopKo5ddZ3DLeGWCZHmaN62vNqi5wEqBOYNSktDV4RLU7ZwUnEtQShK6OlyCpgutbbwyQdv3c6b1lQZNd/O28c6g7QRM67sE3f3gc39sqLuDkIJT/galCNXVgUq1dgbCiC6BZBwTn/f/ccpKdWEJ5H2RnISutpjpQ3LKIvma7oEwpUskEcfE+9+3G9OdQ+kD4B8AjUsUm1cTMx39Yby7O5T+D96vfyu4BZoBCfz7ZVeYAAAAAElFTkSuQmCC);
}
.icon-datetime-up {
  padding: 15px;
  content:url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACgAAABACAYAAABoWTVaAAABp0lEQVRoQ+2VPU+EQBCGZ+7PCRUUHnRXqZU2fhQm2piYmPjRqIVaqCWcxW0F99/MjQl6SC4cDDvsccVQz7v77LMvWYQt/3DL+UABpTekBtWg1IA0rx1Ug1ID0rx2UA1KDUjz2kE1KDUgzWsH1SDXwE4Q740QzgHge0FwMzfJOzfbNNdLB70gukXE0+pGRHSXm/RMCikGrINbQvUBKQJsgusL0hrQD+NHADjkXKHEpBVgF7jKAZ6yWXLEOVB1pjOgJdxyz86QnQCFcFaQbMCe4DpDsgD9IHoFxP2u/WmZZ113K6AjOLbJRkDHcCzItYAbgvuFJHrLTHpQV4lawI3C/T85tZCrgOgH0YuDH4L3f9WYrAKiH8QfgDDhreZoagWyBBzkWteckYiec5MW73wB6AfxBBA+HTmxWpaIvNyk8wLQC+N7BDi2WslRiAAe8lly8mdwvAs4mjray25ZWowzM/0qO+iF0QUQXCFi6+tityMvRUSEgJeZSa7LDvKiw0wNaotzZAXkWGqaUYNqUGpAmtcOqkGpAWleO6gGpQakee2gGpQakOZ/AP2VjkEhvS7OAAAAAElFTkSuQmCC);
}
.icon-datetime-down {
  padding: 15px;
  content:url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACgAAABACAYAAABoWTVaAAABqUlEQVRoQ+2VTUvDQBRF39P/JgSEqGjiqjuLoK5EBV26kdqdovixEFw1XZjgIumPM09MbJDSNJm5k9rFyzr3zZkzdxKmFX94xflIAdETUoNqEDWA5rWDahA1gOa1g2oQNYDmtYNqEDWA5rWDahA1gOarDnp+eCUk18z8r70UESHiyywZ3fxsroDx/L1d4rUxuluXeZF8J0vGHyXgVjAk4lOXC+CzZJDG0UUBuLEdbq4LfeJD3U3IKe9N4vH7nw4Gj8R86G4J+0ki8pAl0VHVwd9R7PnhGzH17Ec7SIq8pEnUn06avbHs+cETMR84WMp8xAzcrMFqoOcHz0uHnANXC1h+epYIWQO3EHCJkPdpPDqp60PjX6NjkwvhGg1Od9URZCNca8AOjrsVnBGgQ8jWcMaA5X87vCOiY/OPXJEwgrMCtIUUkWGWRGemG2u8xXUDTUzawlkbrG53i+NG4GDApuNG4ZwA1kG6gHMGWELu94nknIi+cqHbSTJ6Nb0Q8963viQuFm8zQwHbWFr0jhpUg6gBNK8dVIOoATSvHVSDqAE0rx1Ug6gBNP8NaNGUQSZDEsYAAAAASUVORK5CYII=);
}
.icon-datetime-previous {
  height: 24px;
  width: 15px;
  content:url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACgAAABACAYAAABoWTVaAAAB+0lEQVRoQ+3aPVICMRQH8H90nMFKjsAN9AjQYZdGhhJOIp4ESsUmVm6JJxBvgDew46MgzorrB2x2N9m8lxRsx2zY+e1LspOXF4HILxG5D0dg3R4KEsG2lM1zcXap9el7ou4XRS/BDryWPQlgDIjmDqbVEpvhTKmPPCgrsCtvBgIn40OIni+x6eQh2YBmXMbNR7IAy3HfnQ3MEvXQ+RthcmBV3E8csR0m6nGS/SYF2uK+pgz0XaKmI3KgC24HZIigKw7QL89q2iYdg644DbytsG7vf2q8jkHfuDSS3oAUOG9AKpwXICWuNpAaVwvIgXMGcuGcgJw4ayA3zgoYAlcZGApXCRgSVwoMjSsExoAzAmPB5QJjwh0Au7LfEti+/ibV1TYuTIvNav8ubvVvPdiVvZGAuLV5MCUuJ4L2QMC8K2Dzoqa2exHst4DtXEBc2D2cDnmw5HedJFSRzM1JYkIak6ZYkIVZXQzI0rQzNLIUmM7mkMhKwJDIysBQSCtgCKQ1kBvpBOREOgO5kLWAHMjaQGqkFyAl0huQCukVSIH0DqyD1JylMNcFBkshJ8tnXJBspTBXJGsE7ZEMpTBTulrW3SylsLJc2oQs2p0g+cwUQdNDFRqYZJsDGnhaYT2I4lBFBk+PpTTQuAKwiO5YStkw2L/P3sVHoG0E6rb/BLNd3VBReri0AAAAAElFTkSuQmCC);
}
.icon-datetime-next {
  height: 24px;
  width: 15px;
  content:url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACgAAABACAYAAABoWTVaAAAB+klEQVRoQ+3aPVICMRQH8H8o+Oi8gdxAPIGWa2Ua0RJOIp4ESgabdG7H3kC9gUeAysLROCsyo5BsNpvkJTrQ7ib58fbla7MMif9Y4j4cgK5PyBjBjN/0GXs/fpVvz4UQK9cGbctrgeecH/XQngKMbyqVJW78IBbCthGX+5XAb9wSYIPdyiU+xrm4n7k0alN2D1iF21ZMidwDZvx6yYBz07+kQv4CZvxqxNCamnCUkdwBDicM7LYu8KvrBM5JpwhSRFKVg08MOLGJYshIKntxF50iFaR2HEwFWTmTpICsnIvLQTs20rhYiI00AsseGhNZCxgTWRsYC2kFjIG0BlIjGwEpkY2BVEgnIAXSGRga6QUYEukNGArpFRgC6R3ohpQridZpLuYv2xV9EKALUkLe5WIxIQH20Fa+naja75AA67ydUCEl5BpoDYI+4qY43c7Qaw76xpVob8AQOG/AUDgvwJA4Z2BonBOQAtcYSIVrBKTEWQOpcVbAGLjawFi4WsCYOCMwNq4SmAJOC0wFpwSmhFMCL/jwUXWIWLVM1y02TWXqXP9bBzkZ/2dHYaHP6XQ5WADszJQfFDhtLzadjVDhKsdBHZISZ5xJuujMGHC5GUbkmgGjJD6q+Jl/5WcpAPq5mBemvAxx3du+OATOuJoJ1ahNvYcI2kRLde8ndpiKUBUBQ7cAAAAASUVORK5CYII=);
}
.icon-datetime-today {
  content:url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADgAAABACAYAAABP97SyAAADyElEQVRoQ+2bT2gUVxzHv79JYnqovRQ8SHPxVOxRClaxim3IziWzHtwNIpL696IgoiB4sJQ2iIqCrYdWMUWoZDcHM7HhrYYWEaxIL0Jp8ORRvalRiKvJfMsk3RCXTfbtezPJI+5e3+/3e9/P7/vem9nZWUGDn64g/70nOFEzjexTYbH2mOY8SdcXzXlnwzJBfkIEH8wDWFZhsfaY5kRJ128Y0M/muZBWNVRouObceknXb1hM0gKqm5V0/SZg2h1Ou37TwbQ7nHb9WQd932+PVqzc64kcAbBG81R3LexRRJ7z3ry8rJQqx+KmATu7e1a3SjQKkbWuKTbSQ45N0uscHR54LMC3nh+M3YHIRqNiriaRd1W49kvpCvLfeIIrruq00hVxj/hB7h5E1lsVcjWZuC9+kH8BwUeuarTSRYxLvVsjqwkcSG4COmCClYT3wMEg9xoi7VZtcjWZLMfXwfkfQbgqXFcX2dfwtwnd2q7ENQFdccJUx/J3cNkfMgs+hzRdF67kxZeJ5r2oK24Y6mg6aNg4Z9KaDjpjhaEQJx0keVFaJk9hqrWHwGkRMb4hcQ+Q+E6FhZMVwzLd+R4Ir5lCugVIHlNh8Wz1arSBdAdwHjhbJ10BPKSGCj/VO0f8bO48IIfrxc0dX3rAiPvVcPGSjuhMkLsgIod0YisxSwZIkkIc0IYzPGwSAOQogX5QDopgg053p+EgvSosXNWJX7JDhsRAKSzsAMB16/a3rep4PgJI50KiYzhQdpSGCwNpw8X1zR0krqqw0BvDVYTWh+QUI9mpC+cH+V0EfzW9BpoDkpdUWDwwF64eJMlJgLlSOHhdx7kk4MwAyRsqLHYvJLLayRiOZPbm8ODIYsIZAZI8UgqL5+sJrUASsoVRtG0p4IwAQf4zsYIbbg8OvtKB/PiT8c9vhQN/1YuNx/3u3D4KfrbZc9XzGB0yBP+WctvXSv02riNcJyaGgye/6MQ2EmMEODMBH6DctjkJyLTgzJboO+2zh0wTLgFAOyfThksI0AzSz+YPAvixkf1kEmuxB6un01+uiwWXoIMVWD7w3rZuHRm59my+bi8mXAqAAIl/WyZbNtWCXGy4VACnd2QNSD/IHYXIGZN9ZJOT4B58V0YM+WYq6vrz98+e+MHYcYj8YCPUNDc1wGkngbcgnoqgw1SgbV6qgLbiksiXTDb3UiAfJlHMtRoEXy3/1ykz2e29Aq/fte4noScidsc/asTL9K5AvkiiqCs1CN4rDRU3zr6U3iL8QwSfuiLQRgeJh1OUr/5/KX2m1HL9W8F/9+EQ/EgYD4gAAAAASUVORK5CYII=);
}
.icon-datetime-clear {
  content:url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADgAAABACAYAAABP97SyAAACL0lEQVRoQ+1bvVnDMBB9R8FPFzYIE8AGmM7p1BCnDBMAEwATJExAShIadbiL2QAmIBtAB2kiPhP8EUKQbXxKbDi3Pp/u3Xt30ifJBKbHU6q2iY0OAe0iLg3Qe8X4NNL6uYif5FvicBL78FUwJMDj8GeAKNT9Aw5fLAB91fIIZsgRUOLDgA5CfR0V9ckEkI+9T4A8LFJcO1tYPzMgRUC9aMbK8L0BRgSjb/XglBoq6AI4LkNgDmK4pIZqPgFUc+B85S7fmWyowKw8EocBCECHyV2K67/PoK+a5wQ6W0o6lzyIgblgmeiXHHeu4QRgrnSV0Pj/MVjlphM3lVAPzmeF9I3Bqq9sbnX/CyYBWMK+YQ1JGJQaLLlmRaLZJWruDNbe90AJkx5A+3ZyXdtPR2dj0IB2Qn09mu6JtuoE82gD6No+GZsN4LyjNOZd2wvAJANpTPyUqbTvhMG5As6bEJGoSLSghPJKLq+9SFQkKhK1H+Lkram89lKDUoNSg1KDX7YouRfn0mSkyUiTkSYjTWa2CmSp9sMepWwbpk3AsquWUTppiZQazJjIXx9h582wa3v2tegLxtvJzfgshy+u7dkBxjfjATqaOjZXaTfuXduzA7Qdla3yHds8uEoQtrEFoK+CewJ2y8qQLS4DPIS6vzdrs2iaOAHQqSbAyVGob3pWgPHLKrK4iL0Yy8LrlB9/kkVVkWoM7hVjb9Efa9b7or46bANrJ2UFGgMDJt15Wc5K9A1WoKLXW46cgwAAAABJRU5ErkJggg==);
}
.icon-datetime-close {
  content:url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACwAAABACAYAAABhspUgAAACnklEQVRoQ+3ZQXLTMBQG4P91QWHHDeAGLScg2Tk7bUi6LCdJchJYQtl4R3ZNTkB6AsoN2BVYVIzsOHXs2HqSnuLpjLLJTEa2v3l+kfT0CM/sQ8/MiwSO/cZShFOEGxFIKZFSwpYSmboaAXpOgPneaiBf5TfL2JEz98/UdA7QNQFvNbAGaLnKv6zrzz7I4Ux9uCacfWrj9PYB/8brPP8dAz5S6vUrvLgF6LJ5f43Hj6v82+fq9z24G1sNjYPuw+6fXEMXYDs2DpqDbaLJ5CxB3/JftUykXbBPaBrTRE1Ncr/ng83IMLQPtvTpDU3UTLthw9LDH1s+14DvAbw5BToUC+AXZWq6INDcD8xPDwEsNPRyN0vMtgRcxELLYHG3yr9eFmBzw5c4X8dAS2H/4O/ILFz7hSMGWhpb/OnqaSCJNvftWm65qaeBuyqyraW5+kEKvZuEWnuDEGwrwrJoLq097lhkOyM8NLoP2xnhodA2rBUsN+XZ04ODZYFPgeZi2eCYaBesEzgG2hXrDJZE+2C9waErWPkX9CsCnE5+JPYGh/OFO5oNlsdWdDc0CxwP6462guNj3dC94NNh+ehO8OmxPPRR8HBYO7oFlsCaRWE3yYsXtq0SKXRRqFYwA45R2B4UoVLY6lhWqtyqH/Xuy3xprGwR8LS4FOCJmv44dphs33bvdgVHqtv6tVKR/p7fvAs+quLuuiTQxVFVpmY/TU+BG836OC5WKj00cO993OqKlUJ7HWj7YsPReuPcMgjFhqA1aOzUlJHC+qCr9he77SWNdUHXe3WsxmIsLAfd2VisLi7bYI8L01kqNzHatG4XPtOe6zWmfQGQKg/W9UbjbNHbunV9wBDjrSXSEKi+ZyZw7DeSIpwi3IhASomUEo0I/AcW6SZ18P2yqQAAAABJRU5ErkJggg==);
}
</style>
