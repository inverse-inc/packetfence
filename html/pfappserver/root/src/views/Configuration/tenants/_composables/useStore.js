import { defineStore } from 'pinia'

export default defineStore({
  id: 'tenants',

  state() {
    return {
      cache: null,
      status: null,
      message: null
    }
  },

  getters: {

  },

  actions: {
    getCollection: () => {

    }
  }
})