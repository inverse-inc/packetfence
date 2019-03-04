<template>
  <div>
  <b-table :items="items" :fields="fields" :class="'mb-0 table-clickable table-rowindent-' + level" :sort-by="sortBy" :sort-desc="false"
    small fixed hover show-empty no-local-sorting
    @sort-changed="onSortingChanged" @row-clicked="onRowClick">
    <template slot="name" slot-scope="row">
      <div class="text-lowercase" variant="link"
        v-if="childrenIf(row.item)"
        :disabled="row.item[childrenKey].length === 0">
        <icon class="mr-1" name="regular/folder-open" v-if="row.detailsShowing"></icon>
        <icon class="mr-1" name="regular/folder" v-else></icon> {{ row.item.name }}
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
        :path="fullPath(row.item)"
        :items="row.item[childrenKey]"
        :fields="fields"
        :children-key="childrenKey"
        :children-if="childrenIf"
        :on-node-click="onNodeClick"
        :on-node-create="onNodeCreate"
        :level="level + 1"></pf-tree>
      </transition>
    </template>
    <template slot="empty">
      <b-container v-if="isLoading" class="my-5">
        <b-row class="justify-content-md-center">
          <b-col cols="12" md="auto">
            <icon name="circle-notch" scale="1.5" spin></icon>
          </b-col>
        </b-row>
      </b-container>
      <div v-else class="font-weight-light text-secondary">{{ $t('Directory is empty') }}</div>
    </template>
  </b-table>
    <div :class="'my-1 indent-' + level" v-if="onNodeCreate">
      <b-button size="sm" variant="outline-secondary" @click="onNodeCreate(path)">{{ $t('New') }}</b-button>
    </div>
  </div>
</template>

<script>
export default {
  name: 'pf-tree',
  props: {
    path: {
      type: String,
      default: ''
    },
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
    sortBy: {
      type: String,
      default: null
    },
    onSortingChanged: {
      type: Function,
      default: null
    },
    onNodeClick: {
      type: Function,
      default: null
    },
    onNodeCreate: {
      type: Function,
      default: null
    },
    level: {
      type: Number,
      default: 0
    },
    isLoadingStoreGetter: {
      type: String,
      default: null
    }
  },
  computed: {
    isLoading () {
      if (this.isLoadingStoreGetter) {
        return this.$store.getters[this.isLoadingStoreGetter]
      }
      return false
    }
  },
  methods: {
    onRowClick (item, index) {
      if (this.childrenIf(item)) {
        this.$set(item, '_showDetails', !item._showDetails)
      } else if (typeof this.onNodeClick === 'function') {
        return this.onNodeClick(item)
      }
    },
    fullPath (item) {
      return [item.path, item.name].filter(e => e).join('/')
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

.b-table-details:hover {
  background-color: transparent !important;
}

.b-table-details > td {
  padding: 0;
}

@for $i from 1 through 5 {
    .table-rowindent-#{$i} td:first-child,
    .indent-#{$i} {
        padding-left: $i * 2rem;
    }
}
</style>
