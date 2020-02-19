![](https://img.shields.io/badge/STATUS-NOT%20CURRENTLY%20MAINTAINED-red.svg?longCache=true&style=flat)

# Important Notice
We have decided to stop the maintenance of this public GitHub repository.


# SAP Jam Adapter for Hubot

## Description

The SAP Jam Adapter allows Hubot to easily communicate with Jam users through Jam Messages, Feed Entries, Forums and more. Little to no knowledge of the Jam OData API or its webhook notifications is needed, making the development of Hubot scripts for Jam extremely simple.

## Requirements

This adapater requires access to an SAP Jam Collaboration Enterprise Edition tenant. A developer tenant of SAP Jam is also available as part of the SAP Cloud Platform Free Trial Account.

For more information on the SAP Cloud Platform Free Trial Account, please visit https://cloudplatform.sap.com/try.html

For more information on SAP Jam, please visit https://www.sap.com/products/enterprise-social-collaboration.html


## Download and Installation

First, you need to [set up a Jam alias user and webhook notification](https://help.sap.com/viewer/u_collaboration_dev_help/a711035f7d824819a38764b530e0b5a9.html) for your bot with the following callback URL: `https://your-bot-host-here/hubot/sapjam-listener`

Then, you'll need to [install Node.js and NPM](https://docs.npmjs.com/getting-started/installing-node), followed by [setup for your Hubot](https://hubot.github.com/docs/). Next, clone this repository into directory which will contain your bot code. The repository should be cloned to sub-directory of your bot, and should be named 'hubot-sapjam'. Finally, generate your bot using the SAP Jam adapter as the default adapter, using the Yeoman Hubot generator:

```
yo hubot --adapter=sapjam
```

## Configuration

To use the adapter, set the following environment variables:

- `HUBOT_SAPJAM_SERVER` Your Jam host (e.g. https://developer.sapjam.com)
- `HUBOT_SAPJAM_BOT_ID` Your bot's Jam alias user ID
- `HUBOT_SAPJAM_OAUTH_TOKEN` Your bot's Jam alias user OAuth token
- `HUBOT_SAPJAM_VERIFICATION_TOKEN` Your bot's Jam webhook notification verification token

You can then run Hubot with the following command:

```
bin/hubot --name your-bot-alias-username-here --adapter sapjam
```

And that's it! [Hubot scripts](https://www.npmjs.com/browse/keyword/hubot-scripts) compatible with the base Hubot can now talk to Jam - simply follow the setup and configuration instructions for each script as normal.

## Scripting

The Jam adapter supports the standard Hubot methods used for [scripting](https://hubot.github.com/docs/scripting/):

- `hear` Responds to all matching text content received through webhook notifications
- `respond` Responds to matching text content that is prepended with the bot's name, or if the bot is mentioned/notified in Jam (the bot's name is automatically prepended)
- `send` Sends text to the "room" the text content came from; Whether that's a Message Thread, a Feed Entry or something else, the adapter handles the tedious details
- `reply` Sends text as a private message to the user whose actions generated the notification

The adapter also comes with the following additional methods (accessed through `robot.adapter` rather than `robot`), which require more knowledge of the Jam OData API and webhook notifications to use:

- `fetch` Used to GET content from the Jam OData API. Example:

```coffeescript
robot.on "sapjam_wiki_created", (envelope, jam_event) ->
  wiki = {
    type: "ContentItem"
    navigation: "$value"
    keys: {
      Id: jam_event.Id
      ContentItemType: "Page"
    }
  }

  robot.adapter.fetch wiki, (err, text) ->
    if err
      robot.logger.error "Could not fetch wiki"
    else
      robot.logger.info text
      robot.reply envelope, "Nice wiki #{envelope.user.name}!"
```

- `do` Used to POST service operations to the Jam OData API. Example:

```coffeescript
# Automatic acceptance of group invite and Terms of Use
robot.on "sapjam_group_invite_received", (envelope, jam_event) ->
  group_name = jam_event['@sapjam.event.group'].Name
  robot.adapter.do "Notification_Accept", {Id: jam_event.Id}, (err, body) ->
    if err
      robot.logger.error "Could not accept group invite"
      robot.send envelope, "I couldn't accept your invite to #{group_name}"
    else
      robot.adapter.do "Group_AcceptTermsOfUse", {Id: jam_event.Group.Id}
      robot.send envelope, "I accepted your invitation to #{group_name}!"
```

The adapter will trigger `hear` and `respond` listeners if a webhook notification contains relevant text content, and will always emit a `sapjam_` prepended event for every notification.

Any notification being handled by a `hear` or `respond` listener will have a "room" to `send` to. However, the concept of a room does not apply to all emitted events, such as `sapjam_group_invite_received`, in which case the `send` method will behave as a `reply`. To `send` a message elsewhere, overwrite `envelope.room`. Example:

```coffeescript
# Automatic acceptance of group invite and Terms of Use
robot.on "sapjam_group_invite_received", (envelope, jam_event) ->
  group_name = jam_event['@sapjam.event.group'].Name
  robot.adapter.do "Notification_Accept", {Id: jam_event.Id}, (err, body) ->
    if err
      robot.logger.error "Could not accept group invite"
      robot.send envelope, "I couldn't accept your invite to #{group_name}"
    else
      group_id = jam_event.Group.Id
      robot.adapter.do "Group_AcceptTermsOfUse", {Id: group_id}
      robot.send envelope, "I accepted your invitation to #{group_name}!"
      envelope.room = {
        type: "Group"
        navigation: "FeedEntries"
        keys: {Id: group_id}
        property: "Text"
      }
      robot.send envelope, "I'm so happy to be part of #{group_name}!"
```

The fields of a room object relate to the structure of the Jam OData API. For more details, see the [API documentation](https://developer.sapjam.com/ODataDocs/ui).

Lastly, the adapter also supports at-mentions for `send` and `reply`, using the format `@(default-name-here)(member-ID-here)`. If the message destination is a room that does not support at-mentions, the default name provided will be used. Otherwise, the member ID will be used to generate an at-mention. For example, the last line of the previous sample code could be changed to use an at-mention:

```coffeescript
      robot.send envelope, "I'm so happy to be part of #{group_name}! Thanks for inviting me, @(#{envelope.user.name})(#{envelope.user.id})!"
```

## How to obtain support

Please visit the following page if you require support: https://www.sap.com/products/enterprise-social-collaboration.html#support


# License
This project is licensed under the Apache Software License, v. 2 except as noted otherwise in the LICENSE file.
