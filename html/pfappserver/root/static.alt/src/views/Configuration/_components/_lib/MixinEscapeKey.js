export default {
  name: 'MixinEscapeKey',
  methods: {
    close () {
      this.$router.push({ name: 'roles' })
    },
    onKeyup (event) {
      switch (event.keyCode) {
        case 27: // escape
          this.close()
      }
    }
  },
  mounted () {
    document.addEventListener('keyup', this.onKeyup)
  },
  beforeDestroy () {
    document.removeEventListener('keyup', this.onKeyup)
  }
}
