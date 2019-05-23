/**
 * "events" store module
 *
 * This store module globally manages window/document events. It binds itself
 *    to the window/document event listeners only once, eliminating the need
 *    to bind/unbind document listeners multiple-times throughout the
 *    application.
 */
const state = {
  keyCodes: {
    Backspace: 8,
    Tab: 9,
    Enter: 13,
    NumpadEnter: 13,
    ShiftLeft: 16,
    ShiftRight: 16,
    ControlLeft: 17,
    ControlRight: 17,
    AltLeft: 18,
    AltRight: 18,
    Pause: 19,
    CapsLock: 20,
    Escape: 27,
    PageUp: 33,
    PageDown: 34,
    End: 35,
    Home: 36,
    ArrowLeft: 37,
    ArrowUp: 38,
    ArrowRight: 39,
    ArrowDown: 40,
    Insert: 45,
    Delete: 46,
    Digit0: 48,
    Digit1: 49,
    Digit2: 50,
    Digit3: 51,
    Digit4: 52,
    Digit5: 53,
    Digit6: 54,
    Digit7: 55,
    Digit8: 56,
    Digit9: 57,
    KeyA: 65,
    KeyB: 66,
    KeyC: 67,
    KeyD: 68,
    KeyE: 69,
    KeyF: 70,
    KeyG: 71,
    KeyH: 72,
    KeyI: 73,
    KeyJ: 74,
    KeyK: 75,
    KeyL: 76,
    KeyM: 77,
    KeyN: 78,
    KeyO: 79,
    KeyP: 80,
    KeyQ: 81,
    KeyR: 82,
    KeyS: 83,
    KeyT: 84,
    KeyU: 85,
    KeyV: 86,
    KeyW: 87,
    KeyX: 88,
    KeyY: 89,
    KeyZ: 90,
    LEFT_WINDOWS_KEY: 91,
    RIGHT_WINDOWS_KEY: 92,
    SELECT_KEY: 93,
    Numpad0: 96,
    Numpad1: 97,
    Numpad2: 98,
    Numpad3: 99,
    Numpad4: 100,
    Numpad5: 101,
    Numpad6: 102,
    Numpad7: 103,
    Numpad8: 104,
    Numpad9: 105,
    NumpadMultiply: 106,
    NumpadAdd: 107,
    NumpadSubtract: 109,
    NumpadDecimal: 110,
    NumpadDivide: 111,
    F1: 112,
    F2: 113,
    F3: 114,
    F4: 115,
    F5: 116,
    F6: 117,
    F7: 118,
    F8: 119,
    F9: 120,
    F10: 121,
    F11: 122,
    F12: 123,
    NumLock: 144,
    ScrollLock: 145,
    SemiColon: 186,
    Equal: 187,
    Comma: 188,
    Minus: 189,
    Period: 190,
    Slash: 191,
    Backquote: 192,
    BracketLeft: 219,
    Backslash: 220,
    BracketRight: 221,
    Quote: 222
  },
  keyDown: false,
  focus: true,
  event: {
    keyCode: null,
    altKey: false,
    ctrlKey: false,
    shiftKey: false
  }
}

const getters = {
  isKey: state => key => (state.focus && (key in state.keyCodes) && (state.event.keyCode || null) === state.keyCodes[key]),
  isKeyCode: state => keyCode => (state.focus && (state.event.keyCode || null) === keyCode),
  keyCode: state => state.event.keyCode,
  focus: state => state.focus,
  keyDown: state => state.focus && state.keyDown,
  altKey: state => state.focus && state.event.altKey,
  ctrlKey: state => state.focus && state.event.ctrlKey,
  shiftKey: state => state.focus && state.event.shiftKey,
  escapeKey: state => state.focus && state.event.keyCode === state.keyCodes['Escape'],
  altShiftAKey: state => state.focus && state.event.altKey && state.event.shiftKey && state.event.keyCode === state.keyCodes['KeyA'],
  altShiftCKey: state => state.focus && state.event.altKey && state.event.shiftKey && state.event.keyCode === state.keyCodes['KeyC'],
  altShiftFKey: state => state.focus && state.event.altKey && state.event.shiftKey && state.event.keyCode === state.keyCodes['KeyF'],
  altShiftNKey: state => state.focus && state.event.altKey && state.event.shiftKey && state.event.keyCode === state.keyCodes['KeyN'],
  altShiftRKey: state => state.focus && state.event.altKey && state.event.shiftKey && state.event.keyCode === state.keyCodes['KeyR'],
  altShiftSKey: state => state.focus && state.event.altKey && state.event.shiftKey && state.event.keyCode === state.keyCodes['KeyS'],
  altShiftUKey: state => state.focus && state.event.altKey && state.event.shiftKey && state.event.keyCode === state.keyCodes['KeyU'],
}

const actions = {
  bind: ({ dispatch }) => {
    document.addEventListener('keydown', (event) => dispatch('onKeyDown', event))
    document.addEventListener('keyup', (event) => dispatch('onKeyUp', event))
    window.addEventListener('blur', (event) => dispatch('onBlur', event))
    window.addEventListener('focus', (event) => dispatch('onFocus', event))
  },
  onKeyDown: ({ commit }, event) => {
console.log('keydown', event)
    commit('KEY_DOWN', event)
  },
  onKeyUp: ({ commit }, event) => {
    commit('KEY_UP', event)
  },
  onBlur: ({ commit }, event) => {
    commit('BLUR', event)
  },
  onFocus: ({ commit }, event) => {
    commit('FOCUS', event)
  }
}

const mutations = {
  KEY_DOWN: (state, event) => {
    state.event = event // cache the last event
    state.keyDown = true
  },
  KEY_UP: (state, event) => {
    state.event = { // reset the last event on keyup
      keyCode: null,
      altKey: false,
      ctrlKey: false,
      shiftKey: false
    }
    state.keyDown = false
  },
  BLUR: (state, event) => {
    state.focus = false
    state.keyDown = false
  },
  FOCUS: (state, event) => {
    state.event = { // reset the last event when re-focused to avoid residual key-presses before on blur
      keyCode: null,
      altKey: false,
      ctrlKey: false,
      shiftKey: false
    }
    state.focus = true
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
