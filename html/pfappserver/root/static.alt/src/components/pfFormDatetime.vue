/**
 * Component to pick datetime.
 * 
 * Optional Properties:
 *    v-model: reactive property getter/setter
 *    value: default value
 *    label: form-group label
 *    placeholder: input placeholder
 *    prependText: input-group prepend slot
 *    config: extend/overload pc-bootstrap4-datetimepicker options
 *      See: http://eonasdan.github.io/bootstrap-datetimepicker/Options/
 *    disabled: boolean true/false to disable/enable input
 *    min: minimum datetime string, Date or moment
 *    max: maximum datetime String, Date or moment
 */
 <template>
  <b-form-group :label-cols="labelCols" :label="$t(label)" :state="isValid()" :invalid-feedback="$t(invalidFeedback)" horizontal>
    <b-input-group>
      <b-input-group-prepend v-if="prependText" is-text>
        {{ prependText }}
      </b-input-group-prepend>
      <date-picker ref="datetime" v-model="inputValue" :config="datetimeConfig" :placeholder="placeholder" @input.native="validate()"
        :state="isValid()"></date-picker>
      <b-input-group-append>
        <div class="input-group-text" @click.stop="toggle($event)"><icon name="calendar-alt" variant="secondary"></icon></div>
      </b-input-group-append>
    </b-input-group>
    <b-form-text v-if="text" v-t="text"></b-form-text>
  </b-form-group>
</template>

<script>
import {createDebouncer} from 'promised-debounce'
import datePicker from 'vue-bootstrap-datetimepicker'
import 'pc-bootstrap4-datetimepicker/build/css/bootstrap-datetimepicker.css'

export default {
  name: 'pf-form-input',
  components: {
    'date-picker': datePicker
  },
  props: {
    value: {
      default: null
    },
    label: {
      type: String
    },
    placeholder: { // Warning: This prop is not automatically translated.
      type: String,
      default: null
    },
    validation: {
      type: Object,
      default: null
    },
    text: {
      type: String,
      default: null
    },
    invalidFeedback: {
      type: String,
      default: null
    },
    highlightValid: {
      type: Boolean,
      default: false
    },
    debounce: {
      type: Number,
      default: 300
    },
    prependText: {
      type: String
    },
    config: {
      type: Object
    },
    disabled: {
      type: Boolean,
      default: false
    },
    min: {
      type: String
    },
    max: {
      type: String
    }
  },
  data () {
    return {
      defaultConfig: {
        debug: false,
        format: 'YYYY-MM-DD HH:mm:ss',
        stepping: 1,
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
        sideBySide: false,
        showTodayButton: true,
        showClear: true,
        showClose: true,
        toolbarPlacement: 'top',
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
  computed: {
    inputValue: {
      get () {
        return this.value
      },
      set (newValue) {
        this.$emit('input', newValue)
      }
    },
    labelCols () {
      // do not reserve label column if no label
      return (this.label) ? 3 : 0
    },
    datetimeConfig () {
      return Object.assign(this.defaultConfig, this.config)
    }
  },
  methods: {
    isValid () {
      if (this.validation && this.validation.$dirty) {
        if (this.validation.$invalid) {
          return false
        } else if (this.highlightValid) {
          return true
        }
      }
      return null
    },
    validate () {
      const _this = this
      if (this.validation) {
        this.$debouncer({
          handler: () => {
            _this.validation.$touch()
          },
          time: this.debounce
        })
      }
    },
    toggle (event) {
      event.preventDefault()
      event.stopPropagation()
      let picker = this.$refs.datetime.dp
      picker.toggle()
    }
  },
  watch: {
    min (a, b) {
      if (a !== b) {
        let picker = this.$refs.datetime.dp
        picker.minDate(a)
      }
    },
    max (a, b) {
      if (a !== b) {
        let picker = this.$refs.datetime.dp
        picker.maxDate(a)
      }
    }
  },
  created () {
    this.$debouncer = createDebouncer()
  }
}
</script>

<style lang="scss">
/**
 * vue-bootstrap-datetimepicker only supports fontawesome icons,
 * define base64 encoded icon content and style dirrectly.
 */
.icon-datetime {
  opacity: 0.25;
  transition: all 300ms ease;
}
.icon-datetime:hover {
  opacity: 1;
}
.icon-datetime-time {
  height: 24px !important;
  width: 24px !important;
  content: url(data:image/svg+xml;base64,PHN2ZyByb2xlPSJpbWciIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgdmlld0JveD0iMCAwIDUxMiA1MTIiPjxwYXRoIGQ9Ik0yNTYgOEMxMTkgOCA4IDExOSA4IDI1NnMxMTEgMjQ4IDI0OCAyNDggMjQ4LTExMSAyNDgtMjQ4UzM5MyA4IDI1NiA4em0wIDQ0OGMtMTEwLjUgMC0yMDAtODkuNS0yMDAtMjAwUzE0NS41IDU2IDI1NiA1NnMyMDAgODkuNSAyMDAgMjAwLTg5LjUgMjAwLTIwMCAyMDB6bTYxLjgtMTA0LjRsLTg0LjktNjEuN2MtMy4xLTIuMy00LjktNS45LTQuOS05LjdWMTE2YzAtNi42IDUuNC0xMiAxMi0xMmgzMmM2LjYgMCAxMiA1LjQgMTIgMTJ2MTQxLjdsNjYuOCA0OC42YzUuNCAzLjkgNi41IDExLjQgMi42IDE2LjhMMzM0LjYgMzQ5Yy0zLjkgNS4zLTExLjQgNi41LTE2LjggMi42eiIgY2xhc3M9IiI+PC9wYXRoPjwvc3ZnPg==);
}
.icon-datetime-date {
  height: 24px !important;
  width: 24px !important;
  content: url(data:image/svg+xml;base64,PHN2ZyByb2xlPSJpbWciIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgdmlld0JveD0iMCAwIDQ0OCA1MTIiPjxwYXRoIGZpbGw9ImN1cnJlbnRDb2xvciIgZD0iTTE0OCAyODhoLTQwYy02LjYgMC0xMi01LjQtMTItMTJ2LTQwYzAtNi42IDUuNC0xMiAxMi0xMmg0MGM2LjYgMCAxMiA1LjQgMTIgMTJ2NDBjMCA2LjYtNS40IDEyLTEyIDEyem0xMDgtMTJ2LTQwYzAtNi42LTUuNC0xMi0xMi0xMmgtNDBjLTYuNiAwLTEyIDUuNC0xMiAxMnY0MGMwIDYuNiA1LjQgMTIgMTIgMTJoNDBjNi42IDAgMTItNS40IDEyLTEyem05NiAwdi00MGMwLTYuNi01LjQtMTItMTItMTJoLTQwYy02LjYgMC0xMiA1LjQtMTIgMTJ2NDBjMCA2LjYgNS40IDEyIDEyIDEyaDQwYzYuNiAwIDEyLTUuNCAxMi0xMnptLTk2IDk2di00MGMwLTYuNi01LjQtMTItMTItMTJoLTQwYy02LjYgMC0xMiA1LjQtMTIgMTJ2NDBjMCA2LjYgNS40IDEyIDEyIDEyaDQwYzYuNiAwIDEyLTUuNCAxMi0xMnptLTk2IDB2LTQwYzAtNi42LTUuNC0xMi0xMi0xMmgtNDBjLTYuNiAwLTEyIDUuNC0xMiAxMnY0MGMwIDYuNiA1LjQgMTIgMTIgMTJoNDBjNi42IDAgMTItNS40IDEyLTEyem0xOTIgMHYtNDBjMC02LjYtNS40LTEyLTEyLTEyaC00MGMtNi42IDAtMTIgNS40LTEyIDEydjQwYzAgNi42IDUuNCAxMiAxMiAxMmg0MGM2LjYgMCAxMi01LjQgMTItMTJ6bTk2LTI2MHYzNTJjMCAyNi41LTIxLjUgNDgtNDggNDhINDhjLTI2LjUgMC00OC0yMS41LTQ4LTQ4VjExMmMwLTI2LjUgMjEuNS00OCA0OC00OGg0OFYxMmMwLTYuNiA1LjQtMTIgMTItMTJoNDBjNi42IDAgMTIgNS40IDEyIDEydjUyaDEyOFYxMmMwLTYuNiA1LjQtMTIgMTItMTJoNDBjNi42IDAgMTIgNS40IDEyIDEydjUyaDQ4YzI2LjUgMCA0OCAyMS41IDQ4IDQ4em0tNDggMzQ2VjE2MEg0OHYyOThjMCAzLjMgMi43IDYgNiA2aDM0MGMzLjMgMCA2LTIuNyA2LTZ6Ij48L3BhdGg+PC9zdmc+);
}
.icon-datetime-up {
  padding: 15px;
  content:url(data:image/svg+xml;base64,PHN2ZyByb2xlPSJpbWciIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgdmlld0JveD0iMCAwIDQ0OCA1MTIiPjxwYXRoIGZpbGw9ImN1cnJlbnRDb2xvciIgZD0iTTI0MC45NzEgMTMwLjUyNGwxOTQuMzQzIDE5NC4zNDNjOS4zNzMgOS4zNzMgOS4zNzMgMjQuNTY5IDAgMzMuOTQxbC0yMi42NjcgMjIuNjY3Yy05LjM1NyA5LjM1Ny0yNC41MjIgOS4zNzUtMzMuOTAxLjA0TDIyNCAyMjcuNDk1IDY5LjI1NSAzODEuNTE2Yy05LjM3OSA5LjMzNS0yNC41NDQgOS4zMTctMzMuOTAxLS4wNGwtMjIuNjY3LTIyLjY2N2MtOS4zNzMtOS4zNzMtOS4zNzMtMjQuNTY5IDAtMzMuOTQxTDIwNy4wMyAxMzAuNTI1YzkuMzcyLTkuMzczIDI0LjU2OC05LjM3MyAzMy45NDEtLjAwMXoiPjwvcGF0aD48L3N2Zz4=);
}
.icon-datetime-down {
  padding: 15px;
  content:url(data:image/svg+xml;base64,PHN2ZyByb2xlPSJpbWciIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgdmlld0JveD0iMCAwIDQ0OCA1MTIiPjxwYXRoIGZpbGw9ImN1cnJlbnRDb2xvciIgZD0iTTIwNy4wMjkgMzgxLjQ3NkwxMi42ODYgMTg3LjEzMmMtOS4zNzMtOS4zNzMtOS4zNzMtMjQuNTY5IDAtMzMuOTQxbDIyLjY2Ny0yMi42NjdjOS4zNTctOS4zNTcgMjQuNTIyLTkuMzc1IDMzLjkwMS0uMDRMMjI0IDI4NC41MDVsMTU0Ljc0NS0xNTQuMDIxYzkuMzc5LTkuMzM1IDI0LjU0NC05LjMxNyAzMy45MDEuMDRsMjIuNjY3IDIyLjY2N2M5LjM3MyA5LjM3MyA5LjM3MyAyNC41NjkgMCAzMy45NDFMMjQwLjk3MSAzODEuNDc2Yy05LjM3MyA5LjM3Mi0yNC41NjkgOS4zNzItMzMuOTQyIDB6Ij48L3BhdGg+PC9zdmc+);
}
.icon-datetime-previous {
  height: 24px;
  width: 15px;
  content: url(data:image/svg+xml;base64,PHN2ZyByb2xlPSJpbWciIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgdmlld0JveD0iMCAwIDMyMCA1MTIiPjxwYXRoIGZpbGw9ImN1cnJlbnRDb2xvciIgZD0iTTM0LjUyIDIzOS4wM0wyMjguODcgNDQuNjljOS4zNy05LjM3IDI0LjU3LTkuMzcgMzMuOTQgMGwyMi42NyAyMi42N2M5LjM2IDkuMzYgOS4zNyAyNC41Mi4wNCAzMy45TDEzMS40OSAyNTZsMTU0LjAyIDE1NC43NWM5LjM0IDkuMzggOS4zMiAyNC41NC0uMDQgMzMuOWwtMjIuNjcgMjIuNjdjLTkuMzcgOS4zNy0yNC41NyA5LjM3LTMzLjk0IDBMMzQuNTIgMjcyLjk3Yy05LjM3LTkuMzctOS4zNy0yNC41NyAwLTMzLjk0eiI+PC9wYXRoPjwvc3ZnPg==);
}
.icon-datetime-next {
  height: 24px;
  width: 15px;
  content: url(data:image/svg+xml;base64,PHN2ZyByb2xlPSJpbWciIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgdmlld0JveD0iMCAwIDMyMCA1MTIiPjxwYXRoIGQ9Ik0yODUuNDc2IDI3Mi45NzFMOTEuMTMyIDQ2Ny4zMTRjLTkuMzczIDkuMzczLTI0LjU2OSA5LjM3My0zMy45NDEgMGwtMjIuNjY3LTIyLjY2N2MtOS4zNTctOS4zNTctOS4zNzUtMjQuNTIyLS4wNC0zMy45MDFMMTg4LjUwNSAyNTYgMzQuNDg0IDEwMS4yNTVjLTkuMzM1LTkuMzc5LTkuMzE3LTI0LjU0NC4wNC0zMy45MDFsMjIuNjY3LTIyLjY2N2M5LjM3My05LjM3MyAyNC41NjktOS4zNzMgMzMuOTQxIDBMMjg1LjQ3NSAyMzkuMDNjOS4zNzMgOS4zNzIgOS4zNzMgMjQuNTY4LjAwMSAzMy45NDF6Ij48L3BhdGg+PC9zdmc+);
}
.icon-datetime-today {
  height: 24px !important;
  width: 24px !important;
  content: url(data:image/svg+xml;base64,PHN2ZyByb2xlPSJpbWciIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgdmlld0JveD0iMCAwIDQ0OCA1MTIiPjxwYXRoIGQ9Ik00MDAgNjRoLTQ4VjEyYzAtNi42MjctNS4zNzMtMTItMTItMTJoLTQwYy02LjYyNyAwLTEyIDUuMzczLTEyIDEydjUySDE2MFYxMmMwLTYuNjI3LTUuMzczLTEyLTEyLTEyaC00MGMtNi42MjcgMC0xMiA1LjM3My0xMiAxMnY1Mkg0OEMyMS40OSA2NCAwIDg1LjQ5IDAgMTEydjM1MmMwIDI2LjUxIDIxLjQ5IDQ4IDQ4IDQ4aDM1MmMyNi41MSAwIDQ4LTIxLjQ5IDQ4LTQ4VjExMmMwLTI2LjUxLTIxLjQ5LTQ4LTQ4LTQ4em0tNiA0MDBINTRhNiA2IDAgMCAxLTYtNlYxNjBoMzUydjI5OGE2IDYgMCAwIDEtNiA2em0tNTIuODQ5LTIwMC42NUwxOTguODQyIDQwNC41MTljLTQuNzA1IDQuNjY3LTEyLjMwMyA0LjYzNy0xNi45NzEtLjA2OGwtNzUuMDkxLTc1LjY5OWMtNC42NjctNC43MDUtNC42MzctMTIuMzAzLjA2OC0xNi45NzFsMjIuNzE5LTIyLjUzNmM0LjcwNS00LjY2NyAxMi4zMDMtNC42MzcgMTYuOTcuMDY5bDQ0LjEwNCA0NC40NjEgMTExLjA3Mi0xMTAuMTgxYzQuNzA1LTQuNjY3IDEyLjMwMy00LjYzNyAxNi45NzEuMDY4bDIyLjUzNiAyMi43MThjNC42NjcgNC43MDUgNC42MzYgMTIuMzAzLS4wNjkgMTYuOTd6Ij48L3BhdGg+PC9zdmc+);
}
.icon-datetime-clear {
  height: 24px !important;
  width: 24px !important;
  content: url(data:image/svg+xml;base64,PHN2ZyByb2xlPSJpbWciIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgdmlld0JveD0iMCAwIDY0MCA1MTIiPjxwYXRoIGZpbGw9ImN1cnJlbnRDb2xvciIgZD0iTTU3NiA2NEgyMDUuMjZBNjMuOTcgNjMuOTcgMCAwIDAgMTYwIDgyLjc1TDkuMzcgMjMzLjM3Yy0xMi41IDEyLjUtMTIuNSAzMi43NiAwIDQ1LjI1TDE2MCA0MjkuMjVjMTIgMTIgMjguMjggMTguNzUgNDUuMjUgMTguNzVINTc2YzM1LjM1IDAgNjQtMjguNjUgNjQtNjRWMTI4YzAtMzUuMzUtMjguNjUtNjQtNjQtNjR6bS04NC42OSAyNTQuMDZjNi4yNSA2LjI1IDYuMjUgMTYuMzggMCAyMi42M2wtMjIuNjIgMjIuNjJjLTYuMjUgNi4yNS0xNi4zOCA2LjI1LTIyLjYzIDBMMzg0IDMwMS4yNWwtNjIuMDYgNjIuMDZjLTYuMjUgNi4yNS0xNi4zOCA2LjI1LTIyLjYzIDBsLTIyLjYyLTIyLjYyYy02LjI1LTYuMjUtNi4yNS0xNi4zOCAwLTIyLjYzTDMzOC43NSAyNTZsLTYyLjA2LTYyLjA2Yy02LjI1LTYuMjUtNi4yNS0xNi4zOCAwLTIyLjYzbDIyLjYyLTIyLjYyYzYuMjUtNi4yNSAxNi4zOC02LjI1IDIyLjYzIDBMMzg0IDIxMC43NWw2Mi4wNi02Mi4wNmM2LjI1LTYuMjUgMTYuMzgtNi4yNSAyMi42MyAwbDIyLjYyIDIyLjYyYzYuMjUgNi4yNSA2LjI1IDE2LjM4IDAgMjIuNjNMNDI5LjI1IDI1Nmw2Mi4wNiA2Mi4wNnoiPjwvcGF0aD48L3N2Zz4=);
}
.icon-datetime-close {
  height: 24px !important;
  width: 24px !important;
  content: url(data:image/svg+xml;base64,PHN2ZyByb2xlPSJpbWciIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgdmlld0JveD0iMCAwIDM1MiA1MTIiPjxwYXRoIGQ9Ik0yNDIuNzIgMjU2bDEwMC4wNy0xMDAuMDdjMTIuMjgtMTIuMjggMTIuMjgtMzIuMTkgMC00NC40OGwtMjIuMjQtMjIuMjRjLTEyLjI4LTEyLjI4LTMyLjE5LTEyLjI4LTQ0LjQ4IDBMMTc2IDE4OS4yOCA3NS45MyA4OS4yMWMtMTIuMjgtMTIuMjgtMzIuMTktMTIuMjgtNDQuNDggMEw5LjIxIDExMS40NWMtMTIuMjggMTIuMjgtMTIuMjggMzIuMTkgMCA0NC40OEwxMDkuMjggMjU2IDkuMjEgMzU2LjA3Yy0xMi4yOCAxMi4yOC0xMi4yOCAzMi4xOSAwIDQ0LjQ4bDIyLjI0IDIyLjI0YzEyLjI4IDEyLjI4IDMyLjIgMTIuMjggNDQuNDggMEwxNzYgMzIyLjcybDEwMC4wNyAxMDAuMDdjMTIuMjggMTIuMjggMzIuMiAxMi4yOCA0NC40OCAwbDIyLjI0LTIyLjI0YzEyLjI4LTEyLjI4IDEyLjI4LTMyLjE5IDAtNDQuNDhMMjQyLjcyIDI1NnoiIGNsYXNzPSIiPjwvcGF0aD48L3N2Zz4=);
}
</style>
