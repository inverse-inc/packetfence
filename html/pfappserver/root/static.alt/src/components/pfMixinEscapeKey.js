export default {
  name: 'pfMixinEscapeKey',
  methods: {
    onEscapeKeyup (event) {
      switch (event.keyCode) {
        case 27: // escape
          this.close()
      }
    }
  },
  mounted () {
    if ('close' in this) {
      document.addEventListener('keyup', this.onEscapeKeyup)
      return
    }
    throw new Error(`Missing 'close' method in component ${this.$options.name}`)
  },
  beforeDestroy () {
    document.removeEventListener('keyup', this.onEscapeKeyup)
  }
}
