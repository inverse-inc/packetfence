<template>
  <b-row>
    <pf-sidebar v-model="sections"></pf-sidebar>
    <b-col cols="12" md="9" xl="10" class="mt-3 mb-3">
      <router-view></router-view>
    </b-col>
  </b-row>
</template>

<script>
import pfSidebar from '@/components/pfSidebar'
import { pfReportCategories as reportCategories } from '@/globals/pfReports'

export default {
  name: 'Reports',
  components: {
    pfSidebar
  },
  computed: {
    sections () {
      return reportCategories.map(reportCategory => {
        return {
          name: reportCategory.name,
          items: reportCategory.reports.map(report => {
            return {
              name: report.name,
              path: `/reports/table/${report.tabs[0].path}`,
              icon: report.chart ? 'chart-pie' : null
            }
          })
        }
      })
    }
  }
}
</script>
