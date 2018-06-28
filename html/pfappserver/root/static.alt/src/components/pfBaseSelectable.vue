<!--
<template>
<div>
  <template slot="HEAD_actions" slot-scope="head">
    <input type="checkbox" id="checkallnone" v-model="selectAll" @change="onSelectAllChange" @click.stop>
    <b-tooltip target="checkallnone" placement="right" v-if="selectValues.length === tableValues.length">{{$t('Select None [ALT+N]')}}</b-tooltip>
    <b-tooltip target="checkallnone" placement="right" v-else>{{$t('Select All [ALT+A]')}}</b-tooltip>
  </template>
  <template slot="actions" slot-scope="data">
    <input type="checkbox" :id="data.value" :value="data.item" v-model="selectValues" @click.stop="onToggleSelected($event, data.index)">
    <icon name="exclamation-triangle" class="ml-1" v-if="tableValues[data.index]._message" v-b-tooltip.hover.right :title="tableValues[data.index]._message"></icon>
  </template>
</div>
</template>
-->

<script>
export default {
  name: 'pfBaseSelectable',
  props: {
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
    }
  },
  methods: {
    onSelectAllChange (item) {
      this.selectValues = this.selectAll ? this.tableValues : []
    },
    clearSelected () {
      this.selectValues = []
      this.selectAll = false
      this.lastIndex = null
      const _this = this
      this.selectValues.forEach(function (item, index, items) {
        _this.$store.commit(`${_this._storeName}/ROW_VARIANT`, {mac: item.mac, variant: ''})
        _this.$store.commit(`${_this._storeName}/ROW_MESSAGE`, {mac: item.mac, message: ''})
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
    onKeydown (event) {
      switch (true) {
        case (event.altKey && event.keyCode === 65): // ALT+A
          event.preventDefault()
          this.selectValues = this.tableValues
          break
        case (event.altKey && event.keyCode === 78): // ALT+N
          event.preventDefault()
          this.selectValues = []
          break
      }
    }
  },
  watch: {
    selectValues (a, b) {
      this.selectAll = (this.tableValues.length === a.length && a.length > 0)
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
    }
  },
  created () {
    // Called before the component's created function.
    if (!this.$options.props.tableValues) {
      throw new Error(`Missing 'props.tableValues' in properties of component ${this.$options.name}`)
    }
    if (this.columns.filter(column => column.key === 'actions').length === 0) {
      throw new Error(`Missing column 'actions' in properties of component ${this.$options.name}`)
    }
  },
  mounted () {
    document.addEventListener('keydown', this.onKeydown)
  },
  beforeDestroy () {
    document.removeEventListener('keydown', this.onKeydown)
  }
}
</script>
