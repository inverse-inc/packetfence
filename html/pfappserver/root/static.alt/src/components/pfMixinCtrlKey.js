export default {
  name: 'pfMixinCtrlKey',
  data () {
    return {
      ctrlKey: false
    }
  },
  methods: {
    onCtrlKey (event) {
      this.ctrlKey = event.ctrlKey || event.metaKey
    },
    onWindowBlur (event) {
      this.ctrlKey = false
    }
  },
  mounted () {
    document.addEventListener('keydown', this.onCtrlKey)
    document.addEventListener('keyup', this.onCtrlKey)
    window.addEventListener('blur', this.onWindowBlur)
  },
  beforeDestroy () {
    document.removeEventListener('keydown', this.onCtrlKey)
    document.removeEventListener('keyup', this.onCtrlKey)
    window.removeEventListener('blur', this.onWindowBlur)
  }
}
