### jshint node:true ###
### jshint -W097 ###
'use strict'

through2 = require('through2')
promiseTry = require('es6-promise-try');

replyCodes = require('../utils/replyCodes')
retsHttp = require('../utils/retsHttp')
retsParsing = require('../utils/retsParsing')
errors = require('../utils/errors')


_getMetadataImpl = (retsSession, type, queryOptions, client) -> new Promise (resolve, reject) ->
  retsContext = retsParsing.getStreamParser({retsMethod: 'getMetadata', queryOptions}, type)
  retsHttp.streamRetsMethod(retsContext, retsSession, client)

  result =
    results: []
    type: type
  currEntry = null

  retsContext.retsStream.pipe through2.obj (event, encoding, callback) ->
    switch event.type
      when 'data'
        currEntry.metadata.push(event.payload)
      when 'metadataStart'
        currEntry =
          info: event.payload
          metadata: []
        result.results.push(currEntry)
      when 'metadataEnd'
        currEntry.info.rowsReceived = event.payload
      when 'headerInfo'
        result.headerInfo = event.payload
      when 'status'
        for own key, value of event.payload
          result[key] = value
      when 'done'
        for own key, value of event.payload
          result[key] = value
        resolve(result)
      when 'error'
        reject(event.payload)
    callback()


###
# Retrieves RETS Metadata.
#
# @param type Metadata type (i.e METADATA-RESOURCE, METADATA-CLASS)
# @param id Metadata id
# @param format Data format (i.e. COMPACT, COMPACT-DECODED), defaults to 'COMPACT'
###

getMetadata = (type, id, format='COMPACT') -> promiseTry () =>
  if !type
    throw new errors.RetsParamError('Metadata type is required')
  if !id
    throw new errors.RetsParamError('Resource type id is required (or for some types of metadata, "0" retrieves for all resource types)')
  queryOptions =
    Type: type
    ID: id
    Format: format
  retsHttp.callRetsMethod({retsMethod: 'getMetadata', queryOptions}, @retsSession, @client)


###
# Helper that retrieves RETS system metadata
###

getSystem = () ->
  @getMetadata('METADATA-SYSTEM', '0')
  .then (retsContext) -> new Promise (resolve, reject) ->
    result = {}
    retsParser = retsParsing.getSimpleParser(retsContext, reject)

    gotMetaDataInfo = false
    gotSystemInfo = false
    comment = null
    comments = []
    retsParser.parser.on 'startElement', (name, attrs) ->
      switch name
        when 'METADATA-SYSTEM'
          gotMetaDataInfo = true
          result.metadataVersion = attrs.Version
          result.metadataDate = attrs.Date
        when 'SYSTEM'
          gotSystemInfo = true
          result.systemId = attrs.SystemID
          result.systemDescription = attrs.SystemDescription
          result.timeZoneOffset = attrs.TimeZoneOffset
        when 'COMMENTS'
          comment = ''
          
    retsParser.parser.on 'text', (text) ->
      if retsParser.currElementName == 'COMMENTS'
        comment += text

    retsParser.parser.on 'endElement', (name) ->
      if name == 'COMMENTS'
        comment = comment.trim()
        if comment.length > 0
          comments.push(comment)
      if name != 'RETS'
        return
      retsParser.finish()
      if !gotSystemInfo || !gotMetaDataInfo
        reject(new errors.RetsProcessingError(retsContext, 'Failed to parse data'))
      else
        if comments.length > 0
          result.comments = comments
        result.headerInfo = retsContext.headerInfo
        resolve(result)
    
    retsParser.parser.write(retsContext.body)
    retsParser.parser.end()


module.exports = (_retsSession, _client) ->
  if !_retsSession
    throw new errors.RetsParamError('System data not set; invoke login().')
  

  _getParsedMetadataFactory = (type, format='COMPACT') ->
    (id, classType) -> promiseTry () ->
      if !id
        throw new errors.RetsParamError('Resource type id is required (or for some types of metadata, "0" retrieves for all resource types)')
      options =
        Type: type
        ID: if classType then "#{id}:#{classType}" else id
        Format: format
      _getMetadataImpl(_retsSession, type, options, _client)
  
  
  _getParsedAllMetadataFactory = (type, format='COMPACT') ->
    options =
      Type: type
      ID: '0'
      Format: format
    () -> _getMetadataImpl(_retsSession, type, options, _client)
  
  
  retsSession: _retsSession
  client: _client
  getMetadata: getMetadata
  getSystem: getSystem
  getResources:       _getParsedMetadataFactory('METADATA-RESOURCE').bind(null, '0')
  getForeignKeys:     _getParsedMetadataFactory('METADATA-FOREIGN_KEYS')
  getClass:           _getParsedMetadataFactory('METADATA-CLASS')
  getTable:           _getParsedMetadataFactory('METADATA-TABLE')
  getLookups:         _getParsedMetadataFactory('METADATA-LOOKUP')
  getLookupTypes:     _getParsedMetadataFactory('METADATA-LOOKUP_TYPE')
  getObject:          _getParsedMetadataFactory('METADATA-OBJECT')
  getAllForeignKeys:  _getParsedAllMetadataFactory('METADATA-FOREIGN_KEYS')
  getAllClass:        _getParsedAllMetadataFactory('METADATA-CLASS')
  getAllTable:        _getParsedAllMetadataFactory('METADATA-TABLE')
  getAllLookups:      _getParsedAllMetadataFactory('METADATA-LOOKUP')
  getAllLookupTypes:  _getParsedAllMetadataFactory('METADATA-LOOKUP_TYPE')
