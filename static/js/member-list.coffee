class MemberListItemView extends Backbone.View
    template: _.template $("#member-list-item-template").html()
    
    _do_render: ->
        attr = @model.toJSON()
        attr.party = @model.get_party()
        html = $($.trim(@template attr))
        @$el = html
        @el = @$el[0]
        @_is_rendered = true

    render: =>
        if not @_is_rendered
            @_do_render()
        return @

class @MemberListView
    constructor: (el, options={}) ->
        @$el = el
        @extra_filters = options.filters

        @children = {}

        @index = new lunr.Index
        @index.field "name"
        @index.field "party"
        @index.field "district"
        @index.field "party_short"
        @index.field "titles"
        @index.ref "id"
        
        nancmp = (a, b, ord) ->
            switch
                when not a? or a != a then -ord
                when not b? or a != a then ord
                when a > b then ord
                when a < b then -ord
                else 0
               
        namesort = (ord) -> (a, b) ->
            ord * (a.model.attributes['name'].localeCompare b.model.attributes['name'])
            
        fsort = (getter, failback) -> (ord) ->
            (aw, bw) ->
                ret = nancmp getter(aw), getter(bw), ord
                if ret isnt 0 then ret
                else
                    failback(ord)(aw, bw)
                
        statsort = (field) ->
            fsort ((x) -> x.model.attributes.stats[field]), namesort
        attrsort = (field) ->
            fsort ((x) -> x.model.attributes[field]), namesort

        @_sort_funcs =
            name: namesort
            activity_score: attrsort('activity_score')
            attendance: statsort('attendance')
            party_agree: statsort('party_agree')
            session_agree: statsort('session_agree')
            term_count: statsort('term_count')
            age: attrsort('age')

        data =
                thumbnail_dim: "104x156"
                current: true
                include: 'stats'
                activity_since: 'term'
                limit: 500
        
        data = _.extend data, @extra_filters

        @collection = new MemberList
        @ready = @collection.fetch
            reset: true
            data: data
            processData: true
        .then =>
            @_calculate_rankings @collection
            @_process_children @collection

    _calculate_rankings: (collection) =>
        for model in collection.models
            attr = model.attributes
            stats = attr.stats
            per_day_activity = attr.activity_score/attr.activity_days_included
            ranking = per_day_activity/ACTIVITY_BAR_CAP
            if ranking > 1.0
                ranking = 1.0
            stats['activity_ranking'] = ranking

    filter: ({search, sort}) =>
        # TODO: This would be more responsive with
        # asynchronous rendering of the elements. Maybe.
        # In some profiling runs clearing the parent element took
        # almost all the time.
        @$el.empty()
        if not search?
            result = (@children[key] for key of @children)
        else
            result = (@children[hit.ref] for hit in @index.search search)
        
        order = if JSON.parse(sort.asc ? 'false') then 1 else -1
        sort_func = @_sort_funcs[sort.by](order)

        result.sort sort_func
        
        children = []
        for hit in result
            hit.render(sort.by)
            children.push hit.el
        @$el.append children
        hits = @$el.find(".statistics-bars > *").addClass "display-none"
        .filter(".#{sort.by}-statistics-bar").removeClass "display-none"
        if hits.length == 0
            @$el.find(".activity_score-statistics-bar").removeClass "display-none"


    _process_children: (collection) =>
        for model in collection.models
            item_view = new MemberListItemView model: model
            item_view.render()
            @children[model.id] = item_view
            party = model.get_party()

            titles = []
            if model.is_minister()
                titles.push MINISTER_TRANSLATION
            
            @index.add
                id: model.id
                name: model.get('name')
                party: party.get('name')
                party_short: party.get('abbreviation')
                district: model.attributes.district_name
                titles: titles.join(', ')

    
