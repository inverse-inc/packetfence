import Vue from 'vue'
import VueI18n from 'vue-i18n'
import BootstrapVue from 'bootstrap-vue'
import Icon from 'vue-awesome/components/Icon'

import store from './store'
import App from './App'
import router from './router'

import 'bootstrap-vue/dist/bootstrap-vue.css'
import 'vue-awesome/icons/search'

Vue.config.productionTip = process.env.NODE_ENV === 'production'

Vue.component('icon', Icon)

Vue.use(VueI18n)
Vue.use(BootstrapVue)

const i18n = new VueI18n({
  locale: 'en',
  messages: { en: {} }
})

/* eslint-disable no-new */
new Vue({
  el: '#app',
  router,
  store,
  i18n,
  components: { App }
})
