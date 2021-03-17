### jshint node:true ###
### jshint -W097 ###
'use strict'

through2 = require('through2')
base64 = require('base64-stream') 

retsHttp = require('../utils/retsHttp')
retsParsing = require('../utils/retsParsing')
queryOptionHelpers = require('../utils/queryOptions')
multipart = require('../utils/multipart')
headersHelper = require('../utils/headers')
errors = require('../utils/errors')


_insensitiveStartsWith = (str, prefix) ->
  str.toLowerCase().lastIndexOf(prefix.toLowerCase(), 0) == 0

_processBody = (retsContext, preDecoded) -> new Promise (resolve, reject) ->
  onError = (error) ->
    reject(errors.ensureRetsError(retsContext, error))
  if retsContext.headerInfo.location && retsContext.queryOptions.Location == 1
    resolve
      type: 'location'
      headerInfo: retsContext.headerInfo
  else if _insensitiveStartsWith(retsContext.headerInfo.contentType, 'text/xml')
    retsParser = retsParsing.getSimpleParser(retsContext, onError)
    retsContext.parser.pipe(retsParser.parser)
  else if _insensitiveStartsWith(retsContext.headerInfo.contentType, 'multipart')
    multipart.getObjectStream(retsContext, _processBody)
    .then (objectStream) ->
      resolve {
        type: 'objectStream'
        headerInfo: retsContext.headerInfo
        objectStream
      }
    .catch (error) ->
      onError(error)
  else
    if preDecoded || retsContext.headerInfo.transferEncoding in ['binary', '7bit', '8bit', undefined]
      resolve
        type: 'dataStream'
        headerInfo: retsContext.headerInfo
        dataStream: retsContext.parser
    else if retsContext.headerInfo.transferEncoding == 'base64'
      b64 = base64.decode()
      retsContext.parser.on 'error', (err) ->
        b64.emit('error', errors.ensureRetsError(retsContext, err))
      resolve
        type: 'dataStream'
        headerInfo: retsContext.headerInfo
        dataStream: retsContext.parser.pipe(b64)
    else
      resolve
        type: 'error'
        headerInfo: retsContext.headerInfo
        error: new errors.RetsProcessingError(retsContext, "unknown transfer encoding: #{JSON.stringify(retsContext.headerInfo.transferEncoding)}")
        

_annotateIds = (ids, suffix) ->
  if typeof(ids) == 'string'
    annotatedIds = "#{ids}:#{suffix}"
  else if Array.isArray(ids)
    annotatedIds = []
    for id in ids
      annotatedIds.push("#{id}:#{suffix}")
  annotatedIds


###
# All methods below take the following parameters:
#    resourceType: resource type (RETS Resource argument, ex: Property)
#    objectType: object type (RETS Type argument, ex: Photo)
#    ids: the ids of the objects to query, corresponding to the RETS ID argument; you really should know the RETS
#       standard to fully understand every possibility here.  (See the individual method descriptions below.)  Can be
#       one of 3 data types:
#       1. string: will use this literal value as the ID argument
#       2. array: will be joined with commas, then used as the ID argument
#       3. object: (valid for getObjects only) keys will be joined to values with a colon, and if a value is an array
#           it will be joined with colons
#    options: object of additional options.
#       Location: can be 0 (default) or 1; a 1 value requests URLs be returned instead of actual image data, but the
#           RETS server may ignore this
#       ObjectData: can be null (default), a string to be used directly as the ObjectData argument, or an array of
#           values to be joined with commas.  Requests that the server sets headers containing additional metadata
#           about the object(s) in the response.  The special value '*' requests all available metadata.  Any headers
#           set based on this argument will be parsed into a special object and set as the field 'objectData' in the
#           headerInfo object.
#       alwaysGroupObjects: can be false (default) or true.  If true, all of the methods below will return a result
#           formatted as if a multipart response was received, even if a request only returns a single result.  If you
#           will sometimes get multiple results back from a single query, this will simplify your code by making the
#           results more consistent.  However, if you know you are only making requests that return a single result,
#           it is probably more intuitive to leave this false/unset.
#
# Depending on the form of the response from the RETS server, all methods below will resolve or reject as follows:
# 1. If the HTTP response is not a 200/OK message, all methods will reject with a RetsServerError.
# 2. If the HTTP response is a 200/OK message, but the contentType is text/xml, all methods will reject with a
#    RetsReplyError.
# 3. If the HTTP response is a 200/OK message with a non-multipart contentType, and if the alwaysGroupObjects option is
#    not set, then the response is treated as a single-object response, and all methods will resolve to an object with
#    the following fields:
#       headerInfo: an object of metadata from the headers of the response
#       dataStream: a stream of the object's data
# 4. If the HTTP response is a 200/OK message with a multipart contentType, or if the alwaysGroupObjects option is set,
#    then all methods will resolve to an object with the following fields:
#       headerInfo: an object of metadata from the headers of the main response
#       objectStream: a stream of objects corresponding to the parts of the response; each object will have its own
            headerInfo field for the headers on its part, and either an error field or a dataStream field.
###


###
# getObjects: Use this if you need to specify exactly what images/objects to retrieve.  `ids` can be a single string,
#     an array, or an object.  This is the only method that lets you specify object UIDs instead of resourceIds.
###

getObjects = (resourceType, objectType, ids, _options={}) -> Promise.try () =>
  if !resourceType
    throw new errors.RetsParamError('Resource type id is required')
  if !objectType
    throw new errors.RetsParamError('Object type id is required')
  if !ids
    throw new errors.RetsParamError('Ids are required')

  idString = ''
  if typeof(ids) == 'string'
    idString = ids
  else if Array.isArray(ids)
    idString = ids.join(',')
  else
    idArray = []
    for resourceId,objectIds of ids
      if Array.isArray(objectIds)
        objectIds = objectIds.join(':')
      if objectIds
        idArray.push("#{resourceId}:#{objectIds}")
      else
        idArray.push(resourceId)
    idString = idArray.join(',')

  mainOptions =
    Type: objectType
    Resource: resourceType
    ID: idString
  queryOptions = queryOptionHelpers.mergeOptions(mainOptions, _options, {Location: 0})
  
  if Array.isArray(queryOptions.ObjectData)
    queryOptions.ObjectData = queryOptions.ObjectData.join(',')
  
  alwaysGroupObjects = !!queryOptions.alwaysGroupObjects
  delete queryOptions.alwaysGroupObjects

  #pipe object data to stream buffer
  new Promise (resolve, reject) =>
    errorHandler = (error) ->
      return reject(errors.ensureRetsError(retsContext, error))
    responseHandler = (response) ->
      _processBody(retsContext, true)
      .then (result) ->
        resolve(result)
      .catch (error) ->
        errorHandler(error)
    retsContext = {retsMethod: 'getObject', queryOptions, errorHandler, responseHandler, parser: through2()}
    retsHttp.streamRetsMethod(retsContext, @retsSession, @client)
  .then (result) ->
    if result.objectStream || !alwaysGroupObjects
      return result
    wrappedResult =
      type: 'objectStream'
      headerInfo: result.headerInfo
      objectStream: through2.obj()
    wrappedResult.objectStream.write(type: 'headerInfo', headerInfo: result.headerInfo)
    wrappedResult.objectStream.write(result)
    wrappedResult.objectStream.end()
    wrappedResult


###
# getAllObjects: Use this if you want to get all associated images/objects for all resources (i.e. listingIds or
#     agentIds) specified.  `ids` can be a single string or an array; a ':*' suffix is appended to each id.
###

getAllObjects = (resourceType, objectType, ids, queryOptions) ->
  @getObjects(resourceType, objectType, _annotateIds(ids, '*'), queryOptions)


###
# getPreferredObjects: Use this if you want to get a single 'preferred' image/object for each resource (i.e. listingId
#  or agentIds) specified.  `ids` can be a single string or an array; a ':0' suffix is appended to each id.  
###

getPreferredObjects = (resourceType, objectType, ids, queryOptions) ->
  @getObjects(resourceType, objectType, _annotateIds(ids, '0'), queryOptions)


module.exports = (_retsSession, _client) ->
  if !_retsSession
    throw new errors.RetsParamError('System data not set; invoke login().')
  retsSession: _retsSession
  client: _client
  getObjects: getObjects
  getAllObjects: getAllObjects
  getPreferredObjects: getPreferredObjects
