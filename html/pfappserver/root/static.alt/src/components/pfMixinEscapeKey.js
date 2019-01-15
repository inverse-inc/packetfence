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
    }
  },
  beforeDestroy () {
    document.removeEventListener('keyup', this.onEscapeKeyup)
  }
}
