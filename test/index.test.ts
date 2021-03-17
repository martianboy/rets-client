import * as RetsClient from '../index'
import { expect } from 'chai'
const rets: typeof RetsClient = require('../dist/api')

describe('rets-client', function () {
  it('should export Client', function () {
    expect(rets.Client).to.be.a('function')
    expect(rets.getAutoLogoutClient).to.be.a('function')
  })
  it('should export Client ctor and functions', function () {
    const client = new rets.Client({} as any)
    expect(client.settings).to.be.a('object')
    expect(client.logout).to.be.a('function')
    expect(client.login).to.be.a('function')
  })
  it('should export Errors', function () {
    let retsContext: RetsClient.RetsContext = {
      retsMethod: 'search'
    } as any
    expect(new rets.RetsError()).to.be.a.instanceOf(Error)
    expect(new rets.RetsReplyError(retsContext)).to.be.a.instanceOf(Error)
    expect(new rets.RetsParamError).to.be.a.instanceOf(rets.RetsError)
    expect(new rets.RetsProcessingError(retsContext)).to.be.a.instanceOf(rets.RetsError)
    expect(new rets.RetsServerError(retsContext)).to.be.a.instanceOf(rets.RetsError)
  })
})
