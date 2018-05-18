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
client = require 'cheerio-httpcli'
generator = require 'generate-password'
XmlReader = require 'xml-reader'
xmlQuery = require 'xml-query'
moment = require 'moment'
_ = require 'lodash'

# 乱数を取得
getRandomInt = (max) ->
  return Math.floor(Math.random() * Math.floor(max));

# 指定秒数待機する
sleep = (waitSeconds, data) ->
  return new Promise (resolve) ->
    setTimeout () ->
      resolve(data)
    , waitSeconds * 1000

# ランチ処理のパラメータ
lunchSearch = {
  url: "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
  photoUrl: "https://maps.googleapis.com/maps/api/place/photo?key=#{process.env.GOOGLE_PLACE_APIKEY}&maxheight=300"
  tabelogUrl: "https://tabelog.com/rstLst/"
  params: {
    language: "ja"
    type: "restaurant"
    key: process.env.GOOGLE_PLACE_APIKEY
  }
}

# 指定ページ数GooglePlaceAPIを呼び出す
getPagePlace = (page, location, radius, keyword) ->
  return Array(page).fill(0).reduce( (response) ->
    return response.then( (r) ->
      params = Object.assign {}, lunchSearch.params, {
        location: location
        radius: radius
      }
      if keyword? is not ''
        params.keyword = keyword
      if !r?
        return axios.get(lunchSearch.url, {params: params}).then (r) -> sleep(5, r)
      else if r.data.next_page_token?
        params.pagetoken = r.data.next_page_token
        return axios.get(lunchSearch.url, {params: params}).then (r) -> sleep(5, r)
      else
        return r
    )
  , Promise.resolve())

# ランチ候補のお店をランダムで表示する
lunchHandler = (res) ->
  (argv) ->
    page = (getRandomInt 3) + 1
    getPagePlace(page, argv.location, argv.radius, argv.keyword)
      .then (response) ->
        if response.data.results.length is 0 and response.data.status is 'ZERO_RESULTS'
          err = new Error()
          err.notFound = true
          throw err
        itemIdx = getRandomInt(response.data.results.length)
        item = response.data.results[itemIdx]
        return {google: item, count: response.data.results.length}
      .then (item) ->
        client.fetch("#{lunchSearch.tabelogUrl}?sw=#{encodeURIComponent(item.google.name)}")
          .then (result) ->
            if Number(result.$('.list-condition__count').text()) is 0
              return item
            $target = result.$('.list-rst').eq(0)
            item.tabelog = {
              link: $target.find('a.list-rst__rst-name-target').attr('href')
              rating: $target.find('.list-rst__rating-val').text()
              thumb_url: $target.find('.list-rst__image-target img').attr('data-original')
            }
            return item
          .catch (err) ->
            console.error err
            return item
      .then (item) ->
        if item.tabelog? and item.tabelog.thumb_url? is not ''
          return item
        if !item.google.photos? or item.google.photos.length is 0 or !item.google.photos[0].photo_reference?
          return item
        axios.get("#{lunchSearch.photoUrl}&photoreference=#{item.google.photos[0].photo_reference}")
          .then (response) ->
            item.google.thumb_url = response.request.res.responseUrl
            return item
      .then (item) ->
        rateText = "評価: Google *`#{if item.google?.rating? then item.google.rating else 'なし'}`*"
        rateText += "　食べログ *`#{if item.tabelog?.rating? then item.tabelog.rating else 'なし'}`*"

        attachment =
          title: item.google.name
          text: """#{rateText}
アクセス: #{item.google.vicinity}
ヒット件数： #{if item.count == 20 then '20件以上' else "#{item.count}件"}
"""

        thumbURL = item.google.thumb_url
        if item.tabelog? and item.tabelog.thumb_url?
          thumbURL = item.tabelog.thumb_url
        if thumbURL?
          attachment.thumb_url = thumbURL

        if item.tabelog?
          attachment.title_link = item.tabelog.link

        res.send
          attachments: JSON.stringify [attachment]
      .catch (err) ->
        if err.notFound
          res.reply """検索条件に一致するお店が見つかりませんでした。"""
        else
          console.error err
          res.reply """エラーが発生しました。
#{err.message}
"""

# ランダムな数値を出力する
genRandHandler = (res) ->
  (argv) ->
    val = getRandomInt(argv.max)
    res.send 
      attachments: JSON.stringify [
        {
          title: "generated random numbers max #{argv.max}"
          text: "value: `#{val}`"
        }
      ]

# パスワードを生成する
genPassowrdHandler = (res) ->
  (argv) ->
    pass = generator.generate argv
    res.send 
      attachments: JSON.stringify [
        {
          title: "generated password"
          text: "password: `#{pass}`"
        }
      ]

# 配列から要素をランダムに取得する
choiceHandler = (res) ->
  (argv) ->
    try
      items = argv.items.split(/\s*,\s*/)
      i = getRandomInt items.length
    
      res.send 
        attachments: JSON.stringify [
          {
            title: argv.title || "choiced one at random"
            text: (argv.label || "choice") +  ": `#{items[i]}`"
          }
        ]
    catch error
      res.send "```Error: #{error}```"

vulnConf = {
  url: "https://jvndb.jvn.jp/myjvn"
  params: {
    method: "getVulnOverviewList"
    feed: "hnd"
    rangeDatePublic: ""
    rangeDateFirstPublished: ""
    rangeDatePublished: ""
    keyword: ""
  }
}

# 脆弱性一覧を取得する
vulnHandler = (res) ->
  (argv) ->
    params = _.pick Object.assign({}, vulnConf.params, argv), Object.keys(vulnConf.params)
    if argv.previousPublished is true
      preDays = moment().add(-1, 'days')
      params.datePublishedStartY = preDays.year()
      params.datePublishedEndY = preDays.year()
      params.datePublishedStartM = preDays.month() + 1
      params.datePublishedEndM = preDays.month() + 1
      params.datePublishedStartD = preDays.date()
      params.datePublishedEndD = preDays.date()

    axios.get(vulnConf.url, {params: params})
      .then (r) ->
        xq = xmlQuery XmlReader.parseSync(r.data)
        if Number(xq.find('status:Status').attr('totalRes')) is 0
          return if argv.silent
          return res.send "`#{params.keyword}`の脆弱性は見つかりません"
        vulns = xq.find('item').map (n) ->
          q = xmlQuery n
          severity = ""
          if q.has('sec:cvss') is true
            severity = " (#{q.find('sec:cvss').eq(0).attr("severity")})"
          "<#{q.find('link').text()}|#{q.find('title').text()}>#{severity}"

        res.send 
          attachments: JSON.stringify [
            {
              color: "E91E63"
              title: "#{params.keyword} の脆弱性 (#{vulns.length}件)"
              text: "#{vulns.join("\n")}"
            }
          ]

# Hello Worldを出力する
helloHandler = (res) ->
  (argv) ->
    res.send 
      attachments: JSON.stringify [
        {
          title: "Hello World!"
        }
      ]

factoryParser = (res) ->
  yargs().exitProcess(false)
    .usage("Usage: $0 <command> [options]")
    .command(
      command: 'hello'
      desc: 'Hello Worldを出力する'
      handler: helloHandler(res)
    ).command(
      command: 'gen <command> [options]'
      desc: '生成便利ツール(数値/パスワード...etc)'
      builder: (yargs) ->
        yargs.command(
          command: 'rand [options]'
          desc: 'ランダムな数値を出力する'
          builder: (yargs) ->
            yargs.option('max'
              alias: 'm'
              describe: 'ランダム生成の最大値'
              type: 'number'
              default: 10
            )
          handler: genRandHandler(res)
        ).command(
          command: 'pass [options]'
          desc: 'パスワードを生成する\nboolean値のオプションは --no を先頭に付与することにより false に設定できる'
          builder: (yargs) ->
            yargs.option('length'
              alias: 'l'
              describe: 'パスワードの長さ'
              type: 'number'
              default: 16
            ).option('numbers'
              alias: 'n'
              describe: 'パスワードに数字を含める'
              type: 'boolean'
              default: true
            ).option('symbols'
              alias: 's'
              describe: 'パスワードに記号を含める'
              type: 'boolean'
              default: false
            ).option('uppercase'
              alias: 'u'
              describe: 'パスワードに大文字を含める'
              type: 'boolean'
              default: true
            ).option('strict'
              describe: 'パスワードは、各フラグから少なくとも1文字を含む文字を生成する'
              type: 'boolean'
              default: true
            ).example('$0 gen pass --no-u', '大文字を含めないパスワードを生成する')
          handler: genPassowrdHandler(res)
        )
    ).command(
      command: 'lunch [keyword] [options]'
      desc: 'ランチ候補のお店をランダムで表示する\n※GooglePlaceAPIの仕様で3~10秒の遅延あり'
      builder: (yargs) ->
        yargs.positional('keyword'
          describe: '検索キーワード 例：肉'
          type: 'string'
        ).option('location'
          alias: 'l'
          describe: '検索対象の位置情報(緯度,経度) デフォルト: 新宿'
          type: 'string'
          default: '35.7015239,139.6916546'
        ).option('radius'
          alias: 'r'
          describe: '位置情報からの検索半径(m)'
          type: 'number'
          default: 300
        )
      handler: lunchHandler(res)
    ).command(
      command: 'choice <items> [options]'
      desc: '配列から要素をランダムに取得する'
      builder: (yargs) ->
        yargs.positional('items'
          describe: 'カンマ区切りの要素 例：1,2,3,4,5'
          type: 'string'
        ).option('title'
          alias: 't'
          describe: 'タイトル'
          type: 'string'
        ).option('label'
          alias: 'l'
          describe: 'ラベル'
          type: 'string'
        )
      handler: choiceHandler(res)
    ).command(
      command: 'vuln <keyword> [options]'
      desc: '脆弱性情報を検索する'
      builder: (yargs) ->
        yargs.positional('keyword'
          describe: 'キーワード(部分一致)'
          type: 'string'
        ).option('previousPublished'
          alias: 'p'
          describe: '前日に更新のあった脆弱性情報のみ表示'
          default: 'false'
          type: 'boolean'
        ).option('rangeDatePublic'
          alias: 'd'
          describe: '発見日の範囲指定 n:範囲指定なし、w:過去1週間[2]、m:過去1ヶ月[3]'
          default: 'n'
          type: 'string'
        ).option('rangeDatePublished'
          alias: 'u'
          describe: '更新日の範囲指定 n:範囲指定なし、w:過去1週間[2]、m:過去1ヶ月[3]'
          default: 'w'
          type: 'string'
        ).option('rangeDateFirstPublished'
          alias: 'n'
          describe: '発行日の範囲指定 n:範囲指定なし、w:過去1週間[2]、m:過去1ヶ月[3]'
          default: 'n'
          type: 'string'
        ).option('silent'
          describe: '脆弱性が見つからない場合は返信しない'
          default: 'false'
          type: 'boolean'
        )
      handler: vulnHandler res
    ).help()

module.exports = (robot) ->

  robot.respond /(.+)/i, (res) ->
    factoryParser(res).parse res.match[1], (err, argv, output) ->
      # output help message
      if output
        res.send """```#{output}```"""
