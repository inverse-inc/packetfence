/* eslint-disable no-undef, no-unused-vars */
import { factory } from '@/utils/test'
import Component from './pfFormInputTest'

describe('Component', () => {
  it('has scoped data', () => {
    expect(Component.data.constructor).toBe(Function)
  })
})

describe('Methods', () => {

  let wrapper, vm

  beforeEach(() => {
      wrapper = factory(Component)
      vm = wrapper.vm
  })

  afterEach(() => {
      wrapper.destroy()
  })

  it('when :test="falsy" not has <button ref="button-test">', async () => {
    wrapper.setProps({ test: false })
    await vm.$nextTick()

    // assert button-test ref exists
    expect(wrapper.findComponent({ ref: 'button-test' }).exists()).toBe(false)
  })

  it('when :test="fn" has <button ref="button-test">', async () => {
    wrapper.setProps({ test: () => {} })
    await vm.$nextTick()

    // assert button-test ref exists
    expect(wrapper.findComponent({ ref: 'button-test' }).exists()).toBe(true)
  })

  it('when :value="" => disable button', async () => {
    wrapper.setProps({ test: () => {} })
    wrapper.find('input[type="text"]').setValue('')
    await vm.$nextTick()

    // assert button is disabled when value is empty
    expect(wrapper.findComponent({ ref: 'button-test' }).attributes('disabled')).toBe('disabled')
  })

  it('when :value="defined" => enable button', async () => {
    wrapper.setProps({ test: () => {} })
    wrapper.find('input[type="text"]').setValue('test')
    await vm.$nextTick()

    // assert button is enabled when value is not empty
    expect(wrapper.findComponent({ ref: 'button-test' }).attributes('disabled')).toBe(undefined)
  })

  it('when :disabled="true" (and :value="defined") => disable button', async () => {
    wrapper.setProps({ test: () => {}, disabled: true })
    await vm.$nextTick()

    // assert button is disabled when :disabled="true"
    expect(wrapper.findComponent({ ref: 'button-test' }).attributes('disabled')).toBe('disabled')
  })

  it('when :disabled="false" (and :value="defined") => enable button', async () => {
    wrapper.setProps({ test: () => {}, disabled: false })
    wrapper.find('input[type="text"]').setValue('test')
    await vm.$nextTick()

    // assert button is enabled when :value="defined" && :disabled="false"
    expect(wrapper.findComponent({ ref: 'button-test' }).attributes('disabled')).toBe(undefined)
  })

  it('when :readonly="true" (and :value="defined") => enable button', async () => {
    wrapper.find('input[type="text"]').setValue('test')
    wrapper.setProps({ test: () => {}, readonly: false })
    await vm.$nextTick()

    // assert button is enabled when :value="defined" && :readonly="true"
    expect(wrapper.findComponent({ ref: 'button-test' }).attributes('disabled')).toBe(undefined)
  })

  it('when :state="false" (and :value="defined") => disable button', async () => {
    wrapper.setProps({ test: () => {}, state: false })
    wrapper.find('input[type="text"]').setValue('test')
    await vm.$nextTick()

    // assert button is disabled when :state="false"
    expect(wrapper.findComponent({ ref: 'button-test' }).attributes('disabled')).toBe('disabled')
  })


  it('when :value="defined" and button is not clicked => :test="fn" is not called', async () => {
    wrapper.setProps({ test: jest.fn() })
    wrapper.find('input[type="text"]').setValue('test')
    await vm.$nextTick()

    // assert test function is not called
    expect(vm.test).not.toHaveBeenCalled()
  })

  it('when :value="defined" and button is clicked => :test="fn" is called', async () => {
    wrapper.setProps({ test: jest.fn() })
    wrapper.find('input[type="text"]').setValue('test')
    await vm.$nextTick()

    wrapper.findComponent({ ref: 'button-test' }).trigger('click')
    await vm.$nextTick()

    // assert test function is called
    expect(vm.test).toHaveBeenCalled()
  })

  it('when :test="fn" is called => button is disabled', async () => {
    let timeout
    wrapper.find('input[type="text"]').setValue('test')
    wrapper.setProps({
      test:  () => new Promise((resolve, reject) => {
        timeout = setTimeout(resolve, 3000)
      })
    })
    await vm.$nextTick()

    // assert button is enabled
    expect(wrapper.findComponent({ ref: 'button-test' }).attributes('disabled')).toBe(undefined)

    vm.doRunTest()
    await vm.$nextTick()

    // assert button is disabled
    expect(wrapper.findComponent({ ref: 'button-test' }).attributes('disabled')).toBe('disabled')

    clearTimeout(timeout)
  })

  it('after :test="fn" is called => button is enabled', async () => {
    wrapper.find('input[type="text"]').setValue('test')
    wrapper.setProps({
      test:  () => true
    })
    await vm.$nextTick()

    // assert button is enabled
    expect(wrapper.findComponent({ ref: 'button-test' }).attributes('disabled')).toBe(undefined)

    vm.doRunTest()
    await vm.$nextTick()

    // assert button is enabled
    expect(wrapper.findComponent({ ref: 'button-test' }).attributes('disabled')).toBe(undefined)
  })

  it('emits @pass on :test="fn" success', async () => {
    // assert no event emitted after mount
    expect(wrapper.emitted().pass).toBeFalsy()

    wrapper.setProps({
      test: () => {
        return new Promise((resolve, reject) => {
          resolve('test')
        })
      }
    })
    vm.doRunTest()
    await vm.$nextTick()

    // assert event has been emitted
    expect(wrapper.emitted().pass).toBeTruthy()

    // assert event count
    expect(wrapper.emitted().pass.length).toBe(1)

    // assert event payload
    expect(wrapper.emitted().pass[0]).toEqual(['test'])
  })

  it('emits @fail on :test="fn" failure', async () => {
    // assert no event emitted after mount
    expect(wrapper.emitted().fail).toBeFalsy()

    wrapper.setProps({
      test: () => {
        return new Promise((resolve, reject) => {
          reject('test')
        })
      }
    })
    vm.doRunTest()
    await vm.$nextTick()

    // assert event has been emitted
    expect(wrapper.emitted().fail).toBeTruthy()

    // assert event count
    expect(wrapper.emitted().fail.length).toBe(1)

    // assert event payload
    expect(wrapper.emitted().fail[0]).toEqual(['test'])
  })
})

describe('Props', () => {

  let wrapper, vm

  beforeEach(() => {
      wrapper = factory(Component)
      vm = wrapper.vm
  })

  afterEach(() => {
      wrapper.destroy()
  })

  it('propagates :testLabel => <button>{{ testLabel }}</button>', async () => {
    wrapper.find('input[type="text"]').setValue('test')
    wrapper.setProps({
      test:  () => true,
      testLabel: 'foo'
    })
    await vm.$nextTick()

    // assert property was mutated
    expect(wrapper.findComponent({ ref: 'button-test' }).html()).toContain('foo')
  })

})
