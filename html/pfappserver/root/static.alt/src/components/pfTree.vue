<template>
  <b-table :items="items" :fields="fields" :class="'table-clickable table-rowindent-' + level"
    small fixed hover
    @row-clicked="onRowClick">
    <template slot="name" slot-scope="row">
      <div class="text-lowercase" variant="link"
        v-if="childrenIf(row.item)"
        :disabled="row.item[childrenKey].length === 0"
        n0click.stop="row.toggleDetails">
        <icon class="mr-1" name="regular/folder-open" v-if="row.detailsShowing"></icon>
        <icon class="mr-1" name="regular/folder" v-else></icon>  {{ row.item.name }}
      </div>
      <div class="text-lowercase" variant="link"
        v-else>
          <icon class="mr-1" name="regular/file"></icon> {{ row.item.name }}
      </div>
    </template>
    <template slot="row-details" slot-scope="row">
      <transition name="fade" mode="out-in">
      <pf-tree
        v-if="childrenIf(row.item)"
        class="table-headless bg-transparent mb-0"
        :items="row.item[childrenKey]"
        :fields="fields"
        :childrenKey="childrenKey"
        :childrenIf="childrenIf"
        :level="level + 1"></pf-tree>
      </transition>
    </template>
  </b-table>
</template>

<script>
export default {
  name: 'pf-tree',
  props: {
    items: {
      type: Array,
      default: () => []
    },
    fields: {
      type: Array,
      default: () => []
    },
    childrenKey: {
      type: String,
      default: 'entries'
    },
    childrenIf: {
      type: Function,
      default: (item) => this.childrenKey in item
    },
    level: {
      type: Number,
      default: 0
    }
  },
  methods: {
    onRowClick (item, index) {
      if (this.childrenIf(item)) {
        this.$set(item, '_showDetails', !item._showDetails)
      } else {
        // TODO: open file
      }
    }
  }
}
</script>

<style lang="scss">
@import "../../node_modules/bootstrap/scss/functions";
@import "../styles/variables";

.table-headless thead {
    display: none;
}

@for $i from 1 through 5 {
    .table-rowindent-#{$i} td:first-child {
        padding-left: $i * 2rem;
    }
}
</style>
