import Vue from 'vue'
import BootstrapVue from 'bootstrap-vue'
import i18n from '@/utils/locale'
import VueTimeago from 'vue-timeago'
import Icon from 'vue-awesome/components/Icon'
import 'vue-awesome/icons/arrow-circle-right'
import 'vue-awesome/icons/balance-scale'
import 'vue-awesome/icons/ban'
import 'vue-awesome/icons/barcode'
import 'vue-awesome/icons/bars'
import 'vue-awesome/icons/bell'
import 'vue-awesome/icons/calendar-alt'
import 'vue-awesome/icons/calendar-check'
import 'vue-awesome/icons/caret-up'
import 'vue-awesome/icons/caret-down'
import 'vue-awesome/icons/caret-right'
import 'vue-awesome/icons/chart-pie'
import 'vue-awesome/icons/check'
import 'vue-awesome/icons/check-square'
import 'vue-awesome/icons/chevron-circle-right'
import 'vue-awesome/icons/chevron-circle-down'
import 'vue-awesome/icons/chevron-left'
import 'vue-awesome/icons/chevron-right'
import 'vue-awesome/icons/chevron-down'
import 'vue-awesome/icons/circle'
import 'vue-awesome/icons/circle-notch'
import 'vue-awesome/icons/clipboard-list'
import 'vue-awesome/icons/clock'
import 'vue-awesome/icons/code'
import 'vue-awesome/icons/cogs'
import 'vue-awesome/icons/columns'
import 'vue-awesome/icons/compress'
import 'vue-awesome/icons/ellipsis-v'
import 'vue-awesome/icons/exchange-alt'
import 'vue-awesome/icons/exclamation-circle'
import 'vue-awesome/icons/exclamation-triangle'
import 'vue-awesome/icons/desktop'
import 'vue-awesome/icons/download'
import 'vue-awesome/icons/edit'
import 'vue-awesome/icons/expand'
import 'vue-awesome/icons/eye'
import 'vue-awesome/icons/fast-backward'
import 'vue-awesome/icons/file'
import 'vue-awesome/icons/regular/file'
import 'vue-awesome/icons/regular/folder'
import 'vue-awesome/icons/regular/folder-open'
import 'vue-awesome/icons/grip-vertical'
import 'vue-awesome/icons/id-card'
import 'vue-awesome/icons/info-circle'
import 'vue-awesome/icons/lock'
import 'vue-awesome/icons/long-arrow-alt-right'
import 'vue-awesome/icons/magic'
import 'vue-awesome/icons/minus-circle'
import 'vue-awesome/icons/notes-medical'
import 'vue-awesome/icons/phone'
import 'vue-awesome/icons/play'
import 'vue-awesome/icons/plug'
import 'vue-awesome/icons/plus-circle'
import 'vue-awesome/icons/power-off'
import 'vue-awesome/icons/project-diagram'
import 'vue-awesome/icons/puzzle-piece'
import 'vue-awesome/icons/regular/square'
import 'vue-awesome/icons/retweet'
import 'vue-awesome/icons/ruler-combined'
import 'vue-awesome/icons/save'
import 'vue-awesome/icons/search'
import 'vue-awesome/icons/server'
import 'vue-awesome/icons/shield-alt'
import 'vue-awesome/icons/sign-in-alt'
import 'vue-awesome/icons/sign-out-alt'
import 'vue-awesome/icons/sitemap'
import 'vue-awesome/icons/spinner'
import 'vue-awesome/icons/step-backward'
import 'vue-awesome/icons/stop'
import 'vue-awesome/icons/stopwatch'
import 'vue-awesome/icons/sync'
import 'vue-awesome/icons/th'
import 'vue-awesome/icons/thumbtack'
import 'vue-awesome/icons/times'
import 'vue-awesome/icons/times-circle'
import 'vue-awesome/icons/toggle-on'
import 'vue-awesome/icons/toggle-off'
import 'vue-awesome/icons/trash-alt'
import 'vue-awesome/icons/undo-alt'
import 'vue-awesome/icons/unlink'
import 'vue-awesome/icons/user'
import 'vue-awesome/icons/user-plus'
import 'vue-awesome/icons/user-secret'
import 'vue-awesome/icons/wifi'

import store from './store'
import router from './router'
import filters from './utils/filters'
import App from './App'

import 'bootstrap-vue/dist/bootstrap-vue.css'
import 'vue2vis/dist/vue2vis.css'

Vue.config.productionTip = process.env.NODE_ENV === 'production'
Vue.config.devtools = process.env.VUE_APP_DEBUG

Vue.use(VueTimeago, {
  name: 'Timeago',
  locale: undefined,
  locales: {
    'fr': require('date-fns/locale/fr')
  }
})
Vue.component('icon', Icon)
Vue.use(BootstrapVue)

// Register global filters
for (const filter of Object.keys(filters)) {
  Vue.filter(filter, filters[filter])
}

/* eslint-disable no-new */
new Vue({
  render: h => h(App),
  router,
  store,
  i18n
}).$mount('#app')
