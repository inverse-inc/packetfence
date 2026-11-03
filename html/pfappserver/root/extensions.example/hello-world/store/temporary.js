/**
 * Temporary "$_hello_world" store module, registered by the routes beforeEnter
 */
const state = () => ({
  visits: 0
})

const mutations = {
  VISIT: state => {
    state.visits++
  }
}

export default {
  namespaced: true,
  state,
  mutations
}
