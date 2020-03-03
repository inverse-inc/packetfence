<template>
  <div>
    <b-card no-body>
      <b-card-header>
        <h4 class="d-inline mb-0" v-t="'Filter Engines'"></h4>
      </b-card-header>
      <b-card class="m-3" v-for="(collection, index) in collections" :key="index">
        <h4 class="mb-3">{{ collection.name }}</h4>
        <b-button class="mb-3" variant="outline-primary" :to="{ name: 'newFilterEngine', params: collection }">{{ $t('New Filter') }}</b-button>
        <pf-table-sortable
          :items="collection.items"
          :fields="columns"
          @row-clicked="view(collection, $event)"
          hover
          striped
          @end="sort(collection, $event)"
        >
          <template v-slot:empty>
            <pf-empty-table :isLoading="isLoading" :text="$t('Click the button to define a new filter.')">{{ $t('No filters defined') }}</pf-empty-table>
          </template>
          <template v-slot:cell(buttons)="item">
            <span class="float-right text-nowrap">
              <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Filter?')" @on-delete="remove(item)" reverse/>
              <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(collection, item)">{{ $t('Clone') }}</b-button>
            </span>
          </template>
        </pf-table-sortable>
      </b-card>
    </b-card>
  </div>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfTableSortable from '@/components/pfTableSortable'
import { columns } from '../_config/filterEngine'

export default {
  name: 'filter-engines-list',
  components: {
    pfButtonDelete,
    pfEmptyTable,
    pfTableSortable
  },
  data () {
    return {
      columns, // ../_config/filterEngines
      collections: []
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_filter_engines/isLoading']
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_filter_engines/getCollections').then(collections => {
        for (let i = 0; i < collections.length; i++) {
          this.$store.dispatch('$_filter_engines/getCollection', collections[i].collection).then(collection => {
            this.$set(this.collections, i, collection)
          })
        }
      })
    },
    sort (filterEngine, event) {
/*
      const { oldIndex, newIndex } = event // shifted, not swapped
      const tmp = items[oldIndex]
      if (oldIndex > newIndex) {
        // shift down (not swapped)
        for (let i = oldIndex; i > newIndex; i--) {
          items[i] = items[i - 1]
        }
      } else {
        // shift up (not swapped)
        for (let i = oldIndex; i < newIndex; i++) {
          items[i] = items[i + 1]
        }
      }
      items[newIndex] = tmp
      this.sources = [ // rebuild sources
        ...this.sources.filter(_item => !items.map(item => item.id).includes(_item.id)), // all but sorted items
        ...items // sorted items
      ]
      this.$store.dispatch('$_sources/sortAuthenticationSources', items.map(item => item.id)).then(() => {
        this.$store.dispatch('notification/info', { message: this.$i18n.t('Authentication sources resorted.') })
      })
*/
    },
    remove () {

    },
    clone (_collection, item) {
      const { collection } = _collection
      const { id } = item
      this.$router.push({ name: 'cloneFilterEngine', params: { collection, id } })
    },
    view (_collection, item) {
console.log('view', { _collection, item })
      const { collection } = _collection
      const { id } = item
      this.$router.push({ name: 'filter_engine', params: { collection, id } })
    }
  },
  created () {
    this.init()
  }
}
</script>
