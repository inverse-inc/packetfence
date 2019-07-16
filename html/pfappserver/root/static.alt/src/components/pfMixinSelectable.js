/**
 * Mixin for select components.
 *
 * A component using the pfMixinSelectable mixin component is required to:
 *
 *   1. Declare an option 'storeName':
 *
 *   export default {
 *    storeName: '$_nodes'
 *    // ...
 *   }
 *
 *   2. Declare a property 'tableValues':
 *
 *     props: {
 *       tableValues: {
 *         type: Array,
 *         default: []
 *       }
 *     }
 *
 *   3. declare an attribute 'v-model' in <b-table/>:
 *
 *      <b-table ... v-model="tableValues" ... />
 *
 *   4. declare a property 'actions' in the columns data attribute:
 *
 *     columns: [
 *       {
 *         key: 'actions',
 *         label: this.$i18n.t('Actions'),
 *         sortable: false,
 *         visible: true,
 *         locked: true,
 *         formatter: (value, key, item) => {
 *           return item.mac
 *         }
 *       },
 *       // ...
 *    ]
 *
 *   5. declare an attribute 'head-clicked' in <b-table/>:
 *
 *     <b-table ... @head-clicked="clearSelected" ... />
 *
 *   6. declare a 'HEAD_actions' slot in <b-table/>:
 *
 *     <b-table ... >
 *       <template slot="HEAD_actions" slot-scope="head">
 *         <input type="checkbox" id="checkallnone" v-model="selectAll" @change="onSelectAllChange" @click.stop>
 *         <b-tooltip target="checkallnone" placement="right" v-if="selectValues.length === tableValues.length">{{$t('Select None [Alt + N]')}}</b-tooltip>
 *         <b-tooltip target="checkallnone" placement="right" v-else>{{$t('Select All [Alt + A]')}}</b-tooltip>
 *       </template>
 *     </b-table>
 *
 *   7. declare a 'actions' slot in <b-table/>:
 *
 *     <b-table ... >
 *       <template slot="actions" slot-scope="data">
 *         <input type="checkbox" :id="data.value" :value="data.item" v-model="selectValues" @click.stop="onToggleSelected($event, data.index)">
 *         <icon name="exclamation-triangle" class="ml-1" v-if="tableValues[data.index]._rowMessage" v-b-tooltip.hover.right :title="tableValues[data.index]._rowMessage"></icon>
 *       </template>
 *     </b-table>
 *
 *
 * Optionally, the following can also be used:
 *
 *   1. Clear all the selected values with the following method:
 *
 *     clearSelected()
 *
 *   2. Access the selected values with the following data attribute:
 *
 *     (array) selectValues
 *
**/
export default {
  name: 'pf-mixin-selectable',
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    },
    selectValues: {
      type: Array,
      default: []
    },
    selectAll: {
      type: Boolean,
      default: false
    },
    lastIndex: {
      type: Number,
      default: null
    },
    eventsListen: {
      type: Boolean,
      default: true
    }
  },
  computed: {
    altAKey () {
      return this.$store.getters['events/altAKey']
    },
    altNKey () {
      return this.$store.getters['events/altNKey']
    }
  },
  methods: {
    forceUpdate () {
      if (this.forceUpdateTimeout) clearTimeout(this.forceUpdateTimeout)
      this.forceUpdateTimeout = setTimeout(() => {
        this.$forceUpdate()
      }, 100)
    },
    setRowVariant (index, variant) {
      this.$set(this.tableValues[index], '_rowVariant', variant)
      this.forceUpdate()
    },
    setRowMessage (index, message) {
      this.$set(this.tableValues[index], '_rowMessage', message)
      this.forceUpdate()
    },
    onSelectAllChange (checked) {
      this.selectValues = checked ? this.tableValues : []
    },
    clearSelected () {
      this.selectValues = []
      this.selectAll = false
      this.lastIndex = null
      this.selectValues.forEach((item, index, items) => {
        this.setRowVariant(index, '')
        this.setRowMessage(index, '')
      })
    },
    onToggleSelected (event, index) {
      // support SHIFT+CLICK
      const lastIndex = this.lastIndex
      this.lastIndex = index
      if (lastIndex === null || index === lastIndex || !event.shiftKey) return
      const subset = this.tableValues.slice(
        Math.min(index, lastIndex),
        Math.max(index, lastIndex) + 1
      )
      if (event.currentTarget.checked) {
        this.selectValues.push(...subset)
        // remove duplicates
        this.selectValues = this.selectValues.reduce((x, y) => x.includes(y) ? x : [...x, y], [])
      } else {
        this.selectValues = this.selectValues.reduce((x, y) => subset.includes(y) ? x : [...x, y], [])
      }
    },
    searchableStoreName () {
      if (this.storeName) {
        return this.storeName + '_searchable'
      } else {
        return undefined
      }
    }
  },
  watch: {
    selectValues (a, b) {
      this.selectAll = (this.tableValues.length === a.length && a.length > 0)
      if (JSON.stringify(a) !== JSON.stringify(b)) {
        const selectValues = this.selectValues
        this.tableValues.forEach((item, index, items) => {
          this.setRowMessage(index, '')
          if (selectValues.includes(item)) {
            this.setRowVariant(index, 'info')
          } else {
            this.setRowVariant(index, '')
          }
        })
      }
    },
    requestPage (a, b) {
      if (a !== b) this.clearSelected()
    },
    currentPage (a, b) {
      if (a !== b) this.clearSelected()
    },
    pageSizeLimit (a, b) {
      if (a !== b) this.clearSelected()
    },
    visibleColumns (a, b) {
      if (a !== b) this.clearSelected()
    },
    condition: {
      handler: function (a, b) {
        if (a !== b) this.clearSelected()
      },
      immediate: true,
      deep: true
    },
    altAKey (pressed) {
      if (pressed && this.eventsListen) {
        if (!('isLoading' in this) || !this.isLoading) {
          this.selectValues = this.tableValues
        }
      }
    },
    altNKey (pressed) {
      if (pressed && this.eventsListen) {
        if (!('isLoading' in this) || !this.isLoading) {
          this.selectValues = []
        }
      }
    }
  },
  created () {
    // Called before the component's created function.
    if (!this.storeName) {
      throw new Error(`Missing 'storeName' in options of component ${this.$options.name}`)
    }
    if (!this.tableValues) {
      throw new Error(`Missing 'tableValues' in properties of component ${this.$options.name}`)
    }
    if (this.columns.filter(column => column.key === 'actions').length === 0) {
      throw new Error(`Missing column 'actions' in properties of component ${this.$options.name}`)
    }
  },
  beforeDestroy () {
    if (this.forceUpdateTimeout) {
      clearTimeout(this.forceUpdateTimeout)
    }
  }
}
