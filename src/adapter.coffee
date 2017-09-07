#
# Hubot adapter for SAP Jam
# 

try
  {Robot,User,Adapter,Response,TextMessage} = require 'hubot'
catch
  prequire = require('parent-require')
  {Robot,User,Adapter,Response,TextMessage} = prequire 'hubot'

Notifications = require('./notifications')
Client = require('./client')

class JamAdapter extends Adapter

  send: (envelope, strings...) ->
    for content in strings
      payload = _preprocess_payload(envelope.room, content)
      @jam_client.post_entity(envelope.room, payload)

  reply: (envelope, strings...) ->
    private_message_room = {type: "Member", navigation: "Messages", keys: {Id: envelope.user.id}, property: "Text"}
    for content in strings
      payload = _preprocess_payload(private_message_room, content)
      @jam_client.post_entity(private_message_room, payload)

  emote: (envelope, strings...) ->
    @send envelope, strings.map((str) -> "*#{str}*")...

  fetch: (entity, callback) ->
    @jam_client.get_entity(entity, callback)

  do: (service, params, callback) ->
    @jam_client.post_service(service, params, callback)

  run: () ->
    @robot.logger.info("Robot name: #{@robot.name}.")
    
    options =
      server: process.env.HUBOT_SAPJAM_SERVER
      verification_token: process.env.HUBOT_SAPJAM_VERIFICATION_TOKEN
      oauth_token: process.env.HUBOT_SAPJAM_OAUTH_TOKEN
      bot_id: process.env.HUBOT_SAPJAM_BOT_ID

    @jam_client = new Client(options)
    @jam_notifications = new Notifications(@robot, options)
    @jam_notifications.listen()

    @robot.logger.info "Robot is online!"
    @emit 'connected'

  _preprocess_payload = (room, content) ->
    navigation = room.navigation
    property = room.property
    payload = {}
    atmention_pattern = /@\((.+?)\)\(([A-Za-z0-9]+)\)/

    if atmention_pattern.test(content)
      atmentions = []
      atmention_index = 0

      while atmention_pattern.test(content)
        matches = atmention_pattern.exec(content)
        if navigation is "Messages"
          content = content.replace(atmention_pattern, "@#{matches[1]}")
        else
          content = content.replace(atmention_pattern, "@@m{#{atmention_index}}")
          atmention_index++
          atmentions.push({"__metadata": {"uri": "Members('#{matches[2]}')"}})

      payload["AtMentions"] = atmentions if atmentions.length > 0

    payload[property] = content
    payload

exports.use = (robot) ->
  new JamAdapter(robot)
