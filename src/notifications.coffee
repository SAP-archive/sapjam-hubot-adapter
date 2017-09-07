#
# Implements the SAP Jam push notifications handler in Hubot
# 

try
  {TextMessage} = require 'hubot'
catch
  prequire = require('parent-require')
  {TextMessage} = prequire 'hubot'

striptags = require('striptags')

class Notifications

  messagethread_room_categories = [
    "message_received"
    "added_to_message_thread"
  ]

  qid_room_categories = [
    "discussion_created"
    "question_created"
    "idea_created"
  ]

  feedentry_room_categories = [
    "commented_on_blog"
    "commented_on_document"
    "commented_on_group_wall"
    "commented_on_wiki"
    "document_annotated"
    "question_answered"
    "replied_to_feed_item"
    "commented_on_profile_wall"
  ]

  constructor: (robot, options) ->
    @robot = robot
    @options = options
    @robot.logger.info("Constructed notification listener")

  listen: ->
    @robot.logger.info("Now listening for SAP Jam event notifications")
    @robot.router.post "/hubot/sapjam-listener", (req, res) =>
      try
        @robot.logger.info "Received SAP Jam notification: #{JSON.stringify(req.body)}"
        if req.body['@sapjam.hub.verificationToken'] is @options.verification_token
          for jam_event in req.body.value
            do (jam_event) =>
              jam_actor = jam_event['@sapjam.event.actor']

              # Ignore messages from ourselves
              return if jam_actor.Id is @options.bot_id

              entity_type = jam_event['@sapjam.event.entityType']
              feed_entry = jam_event['@sapjam.event.feedEntry']
              event_categories = jam_event['@sapjam.event.categories']
              mentioned = "mentioned" in event_categories
              event_categories = event_categories.filter (category) -> category != "mentioned"
              event_category = event_categories[0]

              event_actor = @robot.brain.userForId jam_actor.Id, {
                name: jam_actor.FullName
                email_address: jam_actor.Email
                room: {type: "Member", navigation: "Messages", keys: {Id: jam_actor.Id}, property: "Text"}
              }

              if event_category in messagethread_room_categories
                event_actor.room = {type: "MessageThread", navigation: "Messages", keys: {Id: jam_event.MessageThread?.Id or jam_event.Id}, property: "Text"}
                if jam_event.Text
                  event_text = @preprocess_text(jam_event.Text)
                  if jam_event.MessageThread?.ThreadScope is "single_member" and not event_text.match(@robot.respondPattern(''))
                    event_text = "@#{@robot.name} #{event_text}"
              else if event_category in qid_room_categories
                switch entity_type
                  when "Question"
                    navigation = "Answers"
                    property = "Comment"
                  when "Idea"
                    navigation = "Posts"
                    property = "Comment"
                  when "Discussion"
                    navigation = "Comments"
                    property = "Text"
                event_actor.room = {type: entity_type, navigation: navigation, keys: {Id: jam_event.Id}, property: property}
                event_text = @preprocess_text(jam_event.Content)
              else if event_category in feedentry_room_categories or entity_type is "FeedEntry" or entity_type is "Comment"
                event_actor.room = {type: "FeedEntry", navigation: "Replies", keys: {Id: (jam_event.ParentFeedEntry?.Id or jam_event.Id)}, property: "Text"}
                event_text = @extract_text_with_placeholders(mentioned, jam_event.TextWithPlaceholders, jam_event.AtMentions)
              # Handle other webhook events that have an associated feed entry
              else if feed_entry and feed_entry.TextWithPlaceholders
                event_actor.room = {type: "FeedEntry", navigation: "Replies", keys: {Id: (feed_entry.Id)}, property: "Text"}
                event_text = @extract_text_with_placeholders(mentioned, feed_entry.TextWithPlaceholders, feed_entry.AtMentions)

              if event_text
                message = new TextMessage(event_actor, event_text, jam_event.Id)
                message.jam_event = jam_event
                @robot.receive message

              envelope = {user: event_actor, room: event_actor.room}
              @robot.emit "sapjam_#{event_category}", envelope, jam_event

          # Let Jam know we received the message
          res.send(req.body['@sapjam.hub.challenge'])
        else
          res.status(403).send("Push notification token failed to validate. Please double-check the value of HUBOT_SAPJAM_VERIFICATION_TOKEN environment variable")
      catch error
        @robot.logger.error "SAP Jam Notification webhook listener error: #{error.stack}. Request: #{req}"

  preprocess_text: (text) ->
    # Strip non-printable characters, HTML tags and excess whitespace
    text = text.replace(/[^\x20-\x7E]+/g, '')
    text = striptags(text)
    text = text.trim()
    text

  extract_text_with_placeholders: (mentioned, text, mentions) ->
    for mention, i in mentions
      text = if mention.FullName is @robot.name then text.replace("@@m{#{i}}", '') else text.replace("@m{#{i}}", mention.FullName)

    text = @preprocess_text(text)
    if mentioned and text and not text.match(@robot.respondPattern('')) then text = "@#{@robot.name} #{text}"
    text

module.exports = Notifications
