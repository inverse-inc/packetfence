export default {
  name: 'pfMixinCtrlKey',
  data () {
    return {
      ctrlKey: false
    }
  },
  methods: {
    onCtrlKey (event) {
      this.ctrlKey = event.ctrlKey
    }
  },
  mounted () {
    document.addEventListener('keydown', this.onCtrlKey)
    document.addEventListener('keyup', this.onCtrlKey)
  },
  beforeDestroy () {
    document.removeEventListener('keydown', this.onCtrlKey)
    document.removeEventListener('keyup', this.onCtrlKey)
  }
}
