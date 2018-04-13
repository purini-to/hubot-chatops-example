# Description:
#   Example scripts for you to examine and try out.
#
# Notes:
#   They are commented out by default, because most of them are pretty silly and
#   wouldn't be useful and amusing enough for day to day huboting.
#   Uncomment the ones you want to try and experiment with.
#
#   These are from the scripting documentation: https://github.com/github/hubot/blob/master/docs/scripting.md

process.argv = ["@#{process.env.HUBOT_SLACK_BOTNAME}"]

yargs = require 'yargs/yargs'
axios = require 'axios'

getRandomInt = (max) ->
  return Math.floor(Math.random() * Math.floor(max));

# ランチのレコメンド
lunchSearch = {
  url: "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
  photoUrl: "https://maps.googleapis.com/maps/api/place/photo?key=#{process.env.GOOGLE_PLACE_APIKEY}&maxheight=300"
  params: {
    language: "ja"
    type: "restaurant"
    key: process.env.GOOGLE_PLACE_APIKEY
  }
}
lunchHandler = (res) ->
  (argv) ->
    params = Object.assign {}, lunchSearch.params, {
      location: argv.location
      radius: argv.radius
    }
    axios.get(lunchSearch.url, {params: params})
      .then (response) ->
        itemIdx = getRandomInt(response.data.results.length)
        item = response.data.results[itemIdx]
        attachment =
          title: item.name
          text: """おすすめ： #{item.rating}
  場所： #{item.vicinity}
  """
        return {item: item, attachment: attachment}
      .then (msg) ->
        if msg.item.photos.length is 0 or !msg.item.photos[0].photo_reference?
          return msg.attachment

        axios.get("#{lunchSearch.photoUrl}&photoreference=#{msg.item.photos[0].photo_reference}")
          .then (response) ->
            msg.attachment.thumb_url = response.request.res.responseUrl
            return msg.attachment
      .then (attachment) ->
        res.reply
          attachments: JSON.stringify [attachment]

randomCountHandler = (res) ->
  (argv) ->
    val = getRandomInt(argv.max)
    res.reply 
      attachments: JSON.stringify [
        {
          title: "generated random numbers max #{argv.max}"
          text: "value: `#{val}`"
        }
      ]

helloHandler = (res) ->
  (argv) ->
    res.reply 
      attachments: JSON.stringify [
        {
          title: "Hello World!"
        }
      ]

module.exports = (robot) ->

  robot.respond /.*/i, (res) ->
    parser = yargs().exitProcess(false)
      .usage("Usage: $0 <command> [options]")
      .command(
        command: 'hello'
        desc: 'Hello Worldを出力する'
        handler: helloHandler(res)

      )
      .command(
        command: 'random [options]'
        desc: 'ランダムな数値を出力する'
        builder: (yargs) ->
          yargs.option('max'
            alias: 'm'
            describe: 'ランダム生成の最大値'
            type: 'number'
            default: 10
          )
        handler: randomCountHandler(res)
      )
      .command(
        command: 'lunch'
        desc: 'ランチ候補のお店をランダムで表示する'
        builder: (yargs) ->
          yargs.option('location'
            alias: 'l'
            describe: '検索対象の位置情報 デフォルト: 新宿'
            type: 'string'
            default: '35.7015239,139.6916546'
          ).option('radius'
            alias: 'r'
            describe: '位置情報からの検索半径(m)'
            type: 'number'
            default: 500
          )
        handler: lunchHandler(res)
      )
      .help()
      .parse res.message.rawText, (err, argv, output) ->
        # output help message
        if output
          res.reply """```#{output}```"""
