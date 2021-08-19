<template>
  <b-row>
    <section-sidebar v-model="sections" />
    <b-col cols="12" md="9" xl="10" class="mt-3 mb-3">
      <transition name="slide-bottom">
        <router-view />
      </transition>
    </b-col>
  </b-row>
</template>

<script>
import SectionSidebar from '@/components/SectionSidebar'
const components = {
  SectionSidebar
}

import { computed, onMounted, ref } from '@vue/composition-api'
import { pfReportCategories as reportCategories } from '@/globals/pfReports'
import i18n from '@/utils/locale'
const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const standardReports = computed(() => reportCategories().map(reportCategory => {
    return {
      name: i18n.t(reportCategory.name),
      items: reportCategory.reports.map(report => {
        return {
          name: i18n.t(report.name),
          path: `/reports/standard/chart/${report.tabs[0].path}`,
          icon: report.chart ? 'chart-pie' : null
        }
      })
    }
  }))

  const otherReports = ref([])
  const dynamicReports = ref([])
  onMounted(() => {
    $store.dispatch('$_reports/all').then(reports => {
      const sorted = [...(new Set(reports))] // dereferenced (prevents `sort` mutation)
        .sort((a, b) => i18n.t(a.description).localeCompare(i18n.t(b.description)))

      otherReports.value = sorted.filter(report => { return report.type === 'builtin' })
        .map(report => {
          return {
            name: i18n.t(report.description),
            path: `/reports/dynamic/chart/${report.id}`,
            saveSearchNamespace: `dymamicReports::${report.id}`
          }
        })

      dynamicReports.value = sorted.filter(report => { return !report.type || report.type !== 'builtin' })
        .map(report => {
          return {
            name: i18n.t(report.description),
            path: `/reports/dynamic/chart/${report.id}`,
            saveSearchNamespace: `dymamicReports::${report.id}`
          }
        })
      })
  })

  const sections = computed(() => ([
    {
      name: i18n.t('Standard Reports'),
      icon: 'chart-pie',
      collapsable: true,
      items: standardReports.value
    },
    {
      name: i18n.t('Other Reports'),
      icon: 'chart-bar',
      collapsable: true,
      items: otherReports.value
    },
    {
      name: i18n.t('Dynamic Reports'),
      icon: 'chart-bar',
      collapsable: true,
      items: dynamicReports.value
    }
  ]))

  return {
    sections
  }
}

// @vue/component
export default {
  name: 'Reports',
  components,
  setup
}
</script>
