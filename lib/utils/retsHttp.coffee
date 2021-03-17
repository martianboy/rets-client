### jshint node:true ###
### jshint -W097 ###
'use strict'

debug = require('debug')('rets-client:main')
expat = require('node-expat')

errors = require('./errors')
headersHelper = require('./headers')


callRetsMethod = (retsContext, promisifiedRetsSession, client) ->
  debug("RETS #{retsContext.retsMethod}:", retsContext.queryOptions)
  Promise.try () ->
    request = {}
    if client.settings.method == 'POST'
      request.form = retsContext.queryOptions
    else
      request.qs = retsContext.queryOptions
    promisifiedRetsSession(request)
  .catch (error) ->
    debug("RETS #{retsContext.retsMethod} error:", error)
    Promise.reject(error)
  .spread (response, body) ->
    if response.statusCode != 200
      error = new errors.RetsServerError(retsContext, response.statusCode, response.statusMessage)
      debug("RETS #{retsContext.retsMethod} error: #{error.message}")
      return Promise.reject(error)
    retsContext.headerInfo = headersHelper.processHeaders(response.rawHeaders)
    retsContext.body = body
    retsContext.response = response
    return retsContext


streamRetsMethod = (retsContext, regularRetsSession, client) ->
  debug("RETS #{retsContext.retsMethod} (streaming)", retsContext.queryOptions)
  done = false
  errorHandler = (error) ->
    if done
      return
    done = true
    debug("RETS #{retsContext.retsMethod} (streaming) error:", error)
    retsContext.errorHandler(error)
  responseHandler = (response) ->
    if done
      return
    done = true
    retsContext.headerInfo = headersHelper.processHeaders(response.rawHeaders)
    if response.statusCode != 200
      error = new errors.RetsServerError(retsContext, response.statusCode, response.statusMessage)
      debug("RETS #{retsContext.retsMethod} (streaming) error: #{error.message}")
      retsContext.errorHandler?(error)
    else
      retsContext.responseHandler?(response)
  request = {}
  if client.settings.method == 'POST'
    request.form = retsContext.queryOptions
  else
    request.qs = retsContext.queryOptions
  if retsContext.retsMethod == 'getObject'
    request.headers = { Accept: '*/*' }
  stream = regularRetsSession(request)
  stream.on('error', errorHandler)
  stream.on('response', responseHandler)
  stream.pipe(retsContext.parser)
  return retsContext


module.exports =
  callRetsMethod: callRetsMethod
  streamRetsMethod: streamRetsMethod
