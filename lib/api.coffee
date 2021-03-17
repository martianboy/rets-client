### jshint node:true ###
### jshint -W097 ###
'use strict'

Client = require('./client')
replyCodes = require('./utils/replyCodes')
errors = require('./utils/errors')


###
  Available login settings:
      loginUrl: RETS login URL (i.e http://<MLS_DOMAIN>/rets/login.ashx)
      username: username credential
      password: password credential
      version: rets version

      //RETS-UA-Authorization
      userAgent
      userAgentPassword
      sessionId
###

module.exports =
  RetsError: errors.RetsError
  RetsReplyError: errors.RetsReplyError
  RetsServerError: errors.RetsServerError
  RetsProcessingError: errors.RetsProcessingError
  RetsParamError: errors.RetsParamError
  Client: Client
  getAutoLogoutClient: Client.getAutoLogoutClient
  getReplyTag: replyCodes.getReplyTag
