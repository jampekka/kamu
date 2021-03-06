class @MemberListSortButtonsView extends Backbone.View
    el: ".member-list-sort-buttons"
    template: _.template $.trim $("#member-list-sort-button-template").html()

    initialize: (options) ->
        @member_list_view = options.member_list_view
        @listenTo @member_list_view, 'sort-changed', @sort_changed

    events:
        'click button': 'handle_sort_button'

    handle_sort_button: (ev) ->
        btn = $(ev.currentTarget)
        ascending = true
        if btn.hasClass('active') and btn.hasClass('ascending')
            ascending = false

        field = $(btn).data "col"
        @member_list_view.set_sort_order field, ascending

    sort_changed: (field, ascending) ->
        @$el.find('button').removeClass('active').removeClass('ascending').find('i').remove()
        active_btn = @$el.find("[data-col='#{field.id}']")
        active_btn.addClass 'active'
        if ascending
            icon = 'arrow-up'
            active_btn.addClass 'ascending'
        else
            icon = 'arrow-down'
        active_btn.append $("<i class='typcn typcn-#{icon}'></i>")

    render: ->
        @$el.empty()
        category_elements = {}
        default_category = null
        for cat in MEMBER_LIST_FIELD_CATEGORIES
            cat_el = $("""<fieldset class="btn-group btn-group-sm"><legend>#{cat.name}</legend></fieldset>""").appendTo @$el
            for field in cat.fields ? []
                category_elements[field] = cat_el
            default_category = cat_el
            
        for f in MEMBER_LIST_FIELDS
            button_el = $(@template f)
            if @member_list_view.active_sort_field.id == f.id
                button_el.addClass 'active'
            
            cat = category_elements[f.id] ? default_category
            cat.append button_el
        return @

class MemberListItemView extends Backbone.View
    template: _.template $("#member-list-item-template").html()
    
    _do_render: ->
        attr = @model.toJSON()
        attr.party = @model.get_party(party_list)
        html = $($.trim(@template attr))
        @$el = html
        @el = @$el[0]
        @_is_rendered = true

    render: =>
        if not @_is_rendered
            @_do_render()
        return @

class @MemberListView extends Backbone.View
    el: "ul.member-list"
    spinner_el: ".spinner-container"
    search_el: "main .text-search"

    initialize: (options={}) ->
        @extra_filters = options.filters

        @spinner_el = $(@spinner_el)
        @spinner_el.spin top: 0

        @children = {}

        @collection = new MemberList
        @listenTo @collection, "add", @append_item
        @listenTo @collection, "reset", @render

        @index = new lunr.Index
        @index.field "name"
        @index.field "party"
        @index.field "district"
        @index.field "party_short"
        @index.field "titles"
        @index.ref "id"

        @search_el = $(@search_el)
        @search_el.input @_filter_listing

        @_setup_sort()
        
        data =
                thumbnail_dim: "104x156"
                current: true
                include: 'stats'
                activity_since: 'term'
                limit: 500
        
        data = _.extend data, @extra_filters

        @collection.fetch
            reset: true
            data: data
            processData: true

    _setup_sort: =>
        namesort = (a, b) -> a.model.attributes['name'].localeCompare b.model.attributes['name']
        statsort = (field) ->
            (aw, bw) ->
                a = aw.model.attributes.stats[field]
                b = bw.model.attributes.stats[field]
                if a == b
                    return namesort(aw, bw)
                if a > b
                    return -1
                else
                    return 1
        attrsort = (field) ->
            (aw, bw) ->
                a = aw.model.attributes[field]
                b = bw.model.attributes[field]
                if a == b
                    return namesort(aw, bw)
                if a > b
                    return -1
                else
                    return 1

        @_sort_funcs =
            name: namesort
            activity_score: attrsort('activity_score')
            attendance: statsort('attendance')
            party_agree: statsort('party_agree')
            session_agree: statsort('session_agree')
            term_count: statsort('term_count')
            age: attrsort('age')

        @_sort_fields = []
        for field in MEMBER_LIST_FIELDS
            # Copy the original object
            f = $.extend {}, field
            f.sort_func = @_sort_funcs[f.id]
            @_sort_fields.push f

        @_raw_sort_func = null
        @sort_order = 1
        @sort_func = (a, b) =>
            @sort_order*@_raw_sort_func(a, b)
        
        # Just to have something in the sort order,
        # this will be overriden once we get data
        @set_sort_order "activity_score"

    _calculate_rankings: (collection) =>
        for model in collection.models
            attr = model.attributes
            stats = attr.stats
            per_day_activity = attr.activity_score/attr.activity_days_included
            ranking = per_day_activity/ACTIVITY_BAR_CAP
            if ranking > 1.0
                ranking = 1.0
            stats['activity_ranking'] = ranking

    set_sort_order: (field, ascending=true) =>
            for f in @_sort_fields
                if f.id == field
                    break
            @active_sort_field = f

            func = f.sort_func
            if ascending
                @sort_order = -1
            else
                @sort_order = 1

            @_raw_sort_func = func
            @_filter_listing(field)

            @trigger 'sort-changed', f, ascending

    _update_search_hint: (col) =>
        i = Math.floor(Math.random()*(col.models.length))
        model = col.models[i]
        a = model.attributes
        hint = a.given_names.split(" ", 1)[0].split('-', 1)[0].toLowerCase() + " " +
            model.get_party(party_list).get('name').toLowerCase()[..2] + " " +
            a.district_name.toLowerCase()[..3]

        #$el = @search_el
        #$el.attr "placeholder", $el.attr("placeholder") + hint

    _filter_listing: =>
        # TODO: This would be more responsive with
        # asynchronous rendering of the elements. Maybe.
        # In some profiling runs clearing the parent element took
        # almost all the time.
        @$el.empty()
        query = @search_el.val()
        if not query
            result = (@children[key] for key of @children)
        else
            result = (@children[hit.ref] for hit in @index.search query)
        
        result.sort @sort_func
        
        children = []
        for hit in result
            hit.render(@active_sort_field.id)
            children.push hit.el
        
        @$el.append children
        @$el.find('.statistics-row').hide()

        css_class = switch @active_sort_field.id
            when 'attendance' then '.attendance-statistics-bar'
            when 'party_agree' then '.party-agree-statistics-bar'
            when 'party_agree' then '.party-agree-statistics-bar'
            else '.activity-ranking-statistics-bar'
        
        @$el.find(css_class).show()

    _process_children: (collection) =>
        @spinner_el.spin false
        for model in collection.models
            item_view = new MemberListItemView model: model
            @children[model.id] = item_view
            party = model.get_party party_list

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

    render: ->
        @_calculate_rankings @collection
        @_process_children @collection
        @_update_search_hint @collection
        @_filter_listing()
        @set_sort_order "activity_score", false


