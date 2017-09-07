#
# SAP Jam OData client
# 

pluralize = require('pluralize')
request = require ('request')

ODATA_PREFIX = "/api/v1/OData"

class Client

  constructor: (options) ->
    @options = options

  get_entity: (entity, callback) ->
    @get_odata(@entity_uri_string(entity.type, entity.navigation, entity.keys), callback)

  post_service: (service, params, callback) ->
    @post_odata(@service_uri_string(service, params), null, callback)

  post_entity: (entity, payload) ->
    @post_odata(@entity_uri_string(entity.type, entity.navigation, entity.keys), payload)

  # ----------- Helper methods -------------

  # Assemble service operation URI string
  service_uri_string: (service, params) ->
    key_value_pairs = for key, value of params
      "#{key}='#{value}'"

    params_string = key_value_pairs.join("&")

    uri = "/#{service}?#{params_string}"

  # Assemble OData URI string
  entity_uri_string: (type, navigation, keys) ->
    type_pattern = /(.*)([A-Z][a-z]+)/
    matches = type.match type_pattern

    type = matches[1] + pluralize(matches[2])

    key_value_pairs = for key, value of keys
      "#{key}='#{value.replace(/'/g, "''")}'"

    keys_string = key_value_pairs.join(",%20")
    navigation_string = if navigation then "/#{navigation}" else ""

    uri = "/#{type}(#{keys_string})#{navigation_string}"

  # GET call to Jam
  get_odata: (path, callback) ->
    console.log("GET: #{@options.server}#{ODATA_PREFIX}#{path}")

    request {
      method: 'GET'
      uri: "#{@options.server}#{ODATA_PREFIX}#{path}"
      headers: {
        "Authorization": "Bearer #{@options.oauth_token}",
        "Accept": "application/json"
      }
    }, (err, res, body) ->
      if err?
        console.error("Error from SAP Jam Adapter: #{err}")
        typeof callback is "function" and callback(true, null)
      else if res.statusCode isnt 200
        console.error("Unexpected #{res.statusCode} response from SAP Jam API: #{body}")
        typeof callback is "function" and callback(true, null)
      else
        typeof callback is "function" and callback(null, body)

  # POST call to Jam
  post_odata: (path, payload, callback) ->
    console.log("POST: #{@options.server}#{ODATA_PREFIX}#{path}")

    request {
      method: 'POST'
      uri: "#{@options.server}#{ODATA_PREFIX}#{path}"
      headers: {
        "Authorization": "Bearer #{@options.oauth_token}",
        "Accept": "application/json",
        "Content-Type": "application/json"
      }
      body: if payload then JSON.stringify(payload) else null
    }, (err, res, body) ->
      if err?
        console.error("Error from SAP Jam Adapter: #{err}")
        typeof callback is "function" and callback(true, null)
      else if res.statusCode not in [201, 204]
        console.error("Unexpected #{res.statusCode} response from SAP Jam API: #{body}")
        typeof callback is "function" and callback(true, null)
      else
        typeof callback is "function" and callback(null, body)

module.exports = Client
