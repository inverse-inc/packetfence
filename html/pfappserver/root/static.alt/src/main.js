import Vue from 'vue'
import VueI18n from 'vue-i18n'
import BootstrapVue from 'bootstrap-vue'
import Icon from 'vue-awesome/components/Icon'
import 'vue-awesome/icons/arrow-circle-right'
import 'vue-awesome/icons/check'
import 'vue-awesome/icons/columns'
import 'vue-awesome/icons/minus-circle'
import 'vue-awesome/icons/plus-circle'
import 'vue-awesome/icons/search'
import 'vue-awesome/icons/times'
import 'vue-awesome/icons/wifi'
import 'vue-awesome/icons/cogs'
import 'vue-awesome/icons/thumbtack'
import 'vue-awesome/icons/ban'
import 'vue-awesome/icons/sync'
import 'vue-awesome/icons/retweet'
import 'vue-awesome/icons/user-plus'
import 'vue-awesome/icons/trash-alt'
import 'vue-awesome/icons/ellipsis-v'
import 'vue-awesome/icons/exclamation-triangle'

import store from './store'
import router from './router'
import filters from './utils/filters'
import App from './App'

import 'bootstrap-vue/dist/bootstrap-vue.css'

Vue.config.productionTip = process.env.NODE_ENV === 'production'

Vue.component('icon', Icon)

Vue.use(VueI18n)
Vue.use(BootstrapVue)

const i18n = new VueI18n({
  locale: 'en',
  messages: { en: {} }
})

// Register global filters
for (const filter of Object.keys(filters)) {
  Vue.filter(filter, filters[filter])
}

/* eslint-disable no-new */
new Vue({
  el: '#app',
  router,
  store,
  i18n,
  components: { App }
})
