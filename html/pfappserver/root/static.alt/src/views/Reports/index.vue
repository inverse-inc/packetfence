<template>
        <b-row>
            <b-col cols="12" md="3" xl="2" class="bd-sidebar">
                <div class="bd-search d-flex align-items-center">
                    <b-form-input type="text" :placeholder="$t('Filter')"></b-form-input>
                    <b-btn class="bd-search-docs-toggle d-md-none p-0 ml-3" aria-controls="bd-docs-nav">=</b-btn>
                </div>
                <b-collapse is-nav class="bd-links" id="bd-docs-nav">
                    <div class="bd-toc-item active">
                        <b-nav vertical class="bd-sidenav" v-for="(reportCategory, reportCategoryIndex) in reportCategories" :key="reportCategory.name">
                            <hr v-if="reportCategoryIndex >= 1" />
                            <div class="bd-toc-link" v-t="reportCategory.name"></div>
                            <b-nav-item v-for="report in reportCategory.reports" :key="report.name" :to="'/reports/table/'+report.path" replace>
                              {{ $t(report.name) }}
                              <icon v-if="report.chart" class="float-right mt-1" name="chart-pie"></icon>
                            </b-nav-item>
                        </b-nav>
                    </div>
                </b-collapse>
            </b-col>
            <b-col cols="12" md="9" xl="10" class="mt-3 mb-3">
                <transition name="slide-bottom">
                    <router-view></router-view>
                </transition>
            </b-col>
        </b-row>
</template>

<script>
import { pfReportCategories as reportCategories } from '@/globals/pfReports'

export default {
  name: 'Reports',
  computed: {
    reportCategories () {
      return reportCategories
    }
  }
}
</script>
