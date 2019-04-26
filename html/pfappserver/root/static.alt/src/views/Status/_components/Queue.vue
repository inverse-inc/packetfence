<template>
  <div>
    <b-card no-body class="mt-3">
      <b-card-header>
        <h4 class="d-inline" v-t="'Queue'"></h4>
      </b-card-header>
      <div class="card-body">
        <b-table
          :fields="fieldsBasic"
          :items="queueCounts"
          :sort-by="sortBy"
          :sort-desc="sortDesc"
          :hover="queueCounts.length > 0"
          show-empty
          responsive
          fixed
          striped
        >
          <template slot="empty">
            <pf-empty-table :isLoading="isLoading">{{ $t('No stats found') }}</pf-empty-table>
          </template>
        </b-table>
      </div>
    </b-card>

    <b-card no-body class="mt-3">
      <b-card-header>
        <h4 class="d-inline" v-t="'Outstanding Task Counters'"></h4>
      </b-card-header>
      <div class="card-body">
        <b-table
          :fields="fieldsExtended"
          :items="queueCountsOutstanding"
          :sort-by="sortBy"
          :sort-desc="sortDesc"
          :hover="queueCountsOutstanding.length > 0"
          show-empty
          responsive
          fixed
          striped
        >
          <template slot="empty">
            <pf-empty-table :isLoading="isLoading">{{ $t('No stats found') }}</pf-empty-table>
          </template>
        </b-table>
      </div>
    </b-card>

    <b-card no-body class="mt-3">
      <b-card-header>
        <h4 class="d-inline" v-t="'Expired Task Counters'"></h4>
      </b-card-header>
      <div class="card-body">
        <b-table
          :fields="fieldsExtended"
          :items="queueCountsExpired"
          :sort-by="sortBy"
          :sort-desc="sortDesc"
          :hover="queueCountsExpired.length > 0"
          show-empty
          responsive
          fixed
          striped
        >
          <template slot="empty">
            <pf-empty-table :isLoading="isLoading">{{ $t('No stats found') }}</pf-empty-table>
          </template>
        </b-table>
      </div>
    </b-card>
  </div>
</template>

<script>
import pfEmptyTable from '@/components/pfEmptyTable'

export default {
  name: 'Queue',
  components: {
    pfEmptyTable
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    }
  },
  computed: {
    queueCounts () {
      let counts = []
      this.$store.getters[`${this.storeName}/stats`].forEach(stat => {
        counts.push({ queue: stat.queue, count: stat.stats.count })
      })
      return counts
    },
    queueCountsOutstanding () {
      return this.$store.getters[`${this.storeName}/stats`].reduce((stats, stat) => {
        const { stats: { outstanding = null } = {} } = stat
        if (outstanding) {
          outstanding.forEach(outstanding => {
            stats.push({ queue: stat.queue, name: outstanding.name, count: outstanding.count })
          })
        }
        return stats
      }, [])
    },
    queueCountsExpired () {
      return this.$store.getters[`${this.storeName}/stats`].reduce((stats, stat) => {
        const { stats: { expired = null } = {} } = stat
        if (expired) {
          expired.forEach(expired => {
            stats.push({ queue: stat.queue, name: expired.name, count: expired.count })
          })
        }
        return stats
      }, [])
    },
    stats () {
      return this.$store.getters[`${this.storeName}/stats`] || []
    },
    isLoading () {
      return this.$store.getters[`${this.storeName}/isLoading`]
    }
  },
  data () {
    return {
      sortBy: 'queue',
      sortDesc: false,
      fieldsBasic: [
        {
          key: 'queue',
          label: this.$i18n.t('Queue'),
          sortable: true,
          visible: true
        },
        {
          key: 'count',
          label: this.$i18n.t('Count'),
          sortable: true,
          visible: true
        }
      ],
      fieldsExtended: [
        {
          key: 'queue',
          label: this.$i18n.t('Queue'),
          sortable: true,
          visible: true
        },
        {
          key: 'name',
          label: this.$i18n.t('Task type'),
          sortable: true,
          visible: true
        },
        {
          key: 'count',
          label: this.$i18n.t('Count'),
          sortable: true,
          visible: true
        }
      ],
      statsInterval: false,
      statsIntervalTimeout: 15000
    }
  },
  created () {
    this.$store.dispatch(`${this.storeName}/getStats`)
    this.statsInterval = setInterval(() => {
      this.$store.dispatch(`${this.storeName}/getStats`)
    }, this.statsIntervalTimeout)
  },
  beforeDestroy () {
    if (this.statsInterval) clearInterval(this.statsInterval)
  }
}
</script>
