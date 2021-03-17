### jshint node:true ###
### jshint -W097 ###
'use strict'

replyCodes = require('./replyCodes')
headersHelper = require('./headers')
util = require('util')


getErrorMessage = (err) ->
  if !err?
    return JSON.stringify(err)
  if err.message
    return err.message
  if err.toString() == '[object Object]'
    inspect = util.inspect(err, depth: null)
    return inspect.replace(/,?\n +\w+: undefined/g, '')  # filter out unnecessary fields
  else
    return err.toString()


class RetsError extends Error

  
class RetsReplyError extends RetsError
  constructor: (retsContext, @replyCode, @replyText) ->
    super()
    @name = 'RetsReplyError'
    @replyTag = if replyCodes.tagMap[@replyCode]? then replyCodes.tagMap[@replyCode] else 'unknown reply code'
    {@retsMethod, @queryOptions, @headerInfo} = retsContext
    @message = "RETS Server reply while attempting #{@retsMethod} - ReplyCode #{@replyCode} (#{@replyTag}); ReplyText: #{@replyText}"
    Error.captureStackTrace(this, RetsReplyError)


class RetsServerError extends RetsError
  constructor: (retsContext, @httpStatus, @httpStatusMessage) ->
    super()
    @name = 'RetsServerError'
    {@retsMethod, @queryOptions, @headerInfo} = retsContext
    @message = "RETS Server error while attempting #{@retsMethod} - HTTP Status #{@httpStatus} returned (#{@httpStatusMessage})"
    Error.captureStackTrace(this, RetsServerError)


class RetsProcessingError extends RetsError
  constructor: (retsContext, @sourceError) ->
    super()
    @name = 'RetsProcessingError'
    {@retsMethod, @queryOptions, @headerInfo} = retsContext
    @message = "Error while processing RETS response for #{@retsMethod} - #{getErrorMessage(@sourceError)}"
    Error.captureStackTrace(this, RetsProcessingError)


class RetsParamError extends RetsError
  constructor: (@message) ->
    super()
    @name = 'RetsParamError'
    Error.captureStackTrace(this, RetsParamError)

class RetsPermissionError extends RetsError
  constructor: (missing = []) ->
    super()
    @name = 'RetsPermissionError'
    @message = "Login was successful, but this account does not have the proper permissions."
    if missing.length
      @message += " Missing the following permissions: #{missing.join(', ')}"
    Error.captureStackTrace(this, RetsPermissionError)

ensureRetsError = (retsContext, error) ->
  if error instanceof RetsError
    return error
  else
    return new RetsProcessingError(retsContext, error)


module.exports = {
  RetsError
  RetsReplyError
  RetsServerError
  RetsProcessingError
  RetsParamError
  RetsPermissionError
  ensureRetsError
  getErrorMessage
}
