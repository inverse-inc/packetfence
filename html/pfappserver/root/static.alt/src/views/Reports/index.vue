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
  data () {
    return {
      standardReports: reportCategories.map(reportCategory => {
        return {
          name: reportCategory.name,
          items: reportCategory.reports.map(report => {
            return {
              name: report.name,
              path: `/reports/standard/chart/${report.tabs[0].path}`,
              icon: report.chart ? 'chart-pie' : null
            }
          })
        }
      }),
      otherReports: this.$store.dispatch('$_reports/all').then(reports => {
        this.otherReports = reports.sort((a, b) => {
          return a.description.localeCompare(b.description)
        }).filter(report => {
          return report.type === 'builtin'
        }).map(report => {
          return {
            name: report.description,
            path: `/reports/dynamic/chart/${report.id}`,
            saveSearchNamespace: `dymamicReports::${report.id}`
          }
        })
      }),
      dynamicReports: this.$store.dispatch('$_reports/all').then(reports => {
        this.dynamicReports = reports.sort((a, b) => {
          return a.description.localeCompare(b.description)
        }).filter(report => {
          return !report.type
        }).map(report => {
          return {
            name: report.description,
            path: `/reports/dynamic/chart/${report.id}`,
            saveSearchNamespace: `dymamicReports::${report.id}`
          }
        })
      })
    }
  },
  computed: {
    sections () {
      return [
        {
          name: this.$i18n.t('Standard Reports'),
          icon: 'chart-pie',
          collapsable: true,
          items: this.standardReports
        },
        {
          name: this.$i18n.t('Other Reports'),
          icon: 'chart-bar',
          collapsable: true,
          items: this.otherReports
        },
        {
          name: this.$i18n.t('Dynamic Reports'),
          icon: 'chart-bar',
          collapsable: true,
          items: this.dynamicReports
        }
      ]
    }
  }
}
</script>
