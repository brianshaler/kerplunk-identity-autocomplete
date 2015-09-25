module.exports = (System) ->
  Identity = System.getModel 'Identity'

  globals:
    public:
      css:
        'kerplunk-identity-autocomplete:input': 'kerplunk-identity-autocomplete/css/identity-autocomplete.css'

  init: (next) ->
    searchSocket = System.getSocket 'identity-autocomplete'
    searchSocket.on 'receive', (spark, data) ->
      if data?.query
        queries = data.query
          .toLowerCase()
          .replace /(^\s+)|(\s+$)/g, ''
          .replace /\s+/g, ' '
          .split ' '
          .map (q) -> "\\b#{q.replace /([^a-z0-9])/gi, '\\$1'}"
        return unless queries.length > 0
        matcher = new RegExp queries.join('|'), 'i'
        Identity
        .where
          '$or': [
            {fullName: matcher}
            {userName: matcher}
          ]
        .sort
          lastInteraction: -1
        .limit 20
        .find (err, identities) ->
          if err
            return console.log err?.stack ? err
          # unless identities?.length > 0
          #   console.log 'query yielded no identities', data.query
          for identity in identities
            spark.write
              identity: identity
      else
        console.log 'client said what?', data
    # searchSocket.on 'connection', (spark, data) ->
    #   console.log 'identity-autocomplete connection'
    next()
