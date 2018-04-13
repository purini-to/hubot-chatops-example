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

getRandomInt = (max) ->
  return Math.floor(Math.random() * Math.floor(max));

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
      .help()
      .parse res.message.rawText, (err, argv, output) ->
        # output help message
        if output
          res.reply """```#{output}```"""
