/**
 * Pinia store, the id is prefixed with the extension id
 */
import { defineStore } from 'pinia'

export const useCounter = defineStore({
  id: '$_hello_world_counter',
  state: () => ({
    count: 0
  }),
  actions: {
    increment () {
      this.count++
    }
  }
})
