<template>
  <div>
    <b-card no-body>
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
          sort-icon-left
          striped
        >
          <template v-slot:empty>
            <base-table-empty :is-loading="isLoading" text="">{{ $t('No stats found') }}</base-table-empty>
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
          sort-icon-left
          striped
        >
          <template v-slot:empty>
            <base-table-empty :is-loading="isLoading" text="">{{ $t('No stats found') }}</base-table-empty>
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
          sort-icon-left
          striped
        >
          <template v-slot:empty>
            <base-table-empty :is-loading="isLoading" text="">{{ $t('No stats found') }}</base-table-empty>
          </template>
        </b-table>
      </div>
    </b-card>
  </div>
</template>

<script>
import {
  BaseTableEmpty
} from '@/components/new/'

const components = {
  BaseTableEmpty
}

import { computed, onBeforeUnmount, onMounted, ref } from '@vue/composition-api'
import i18n from '@/utils/locale'

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const fieldsBasic = computed(() => ([
    {
      key: 'queue',
      label: i18n.t('Queue'),
      sortable: true,
      visible: true
    },
    {
      key: 'count',
      label: i18n.t('Count'),
      sortable: true,
      visible: true
    }
  ]))
  const fieldsExtended = computed(() => ([
    {
      key: 'queue',
      label: i18n.t('Queue'),
      sortable: true,
      visible: true
    },
    {
      key: 'name',
      label: i18n.t('Task type'),
      sortable: true,
      visible: true
    },
    {
      key: 'count',
      label: i18n.t('Count'),
      sortable: true,
      visible: true
    }
  ]))

  const isLoading = computed(() => $store.getters[`pfqueue/isLoading`])

  const queueCounts = computed(() => {
    let counts = []
    $store.getters['pfqueue/stats'].forEach(stat => {
      counts.push({ queue: stat.queue, count: stat.stats.count })
    })
    return counts
  })

  const queueCountsExpired = computed(() => {
    return $store.getters['pfqueue/stats'].reduce((stats, stat) => {
      const { stats: { expired = null } = {} } = stat
      if (expired) {
        expired.forEach(expired => {
          stats.push({ queue: stat.queue, name: expired.name, count: expired.count })
        })
      }
      return stats
    }, [])
  })

  const queueCountsOutstanding = computed(() => {
    return $store.getters['pfqueue/stats'].reduce((stats, stat) => {
      const { stats: { outstanding = null } = {} } = stat
      if (outstanding) {
        outstanding.forEach(outstanding => {
          stats.push({ queue: stat.queue, name: outstanding.name, count: outstanding.count })
        })
      }
      return stats
    }, [])
  })

  const sortBy = ref('queue')
  const sortDesc = ref(false)

  let statsInterval = false
  const statsIntervalTimeout = (15 * 1E3) // 15s

  onMounted(() => {
    $store.dispatch(`pfqueue/getStats`)
    statsInterval = setInterval(() => {
      $store.dispatch(`pfqueue/getStats`)
    }, statsIntervalTimeout)
  })

  onBeforeUnmount(() => {
    if (statsInterval)
      clearInterval(statsInterval)
  })

  return {
    fieldsBasic,
    fieldsExtended,
    isLoading,
    queueCounts,
    queueCountsExpired,
    queueCountsOutstanding,
    sortBy,
    sortDesc
  }
}

// @vue/component
export default {
  name: 'the-view',
  components,
  setup
}
</script>
