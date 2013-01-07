module Gridzilla
  module Controller
    def self.included(base)
      base.send :extend, ClassMethods
    end

    module ClassMethods
      def gridzilla(&block)
        grid_builder = GridBuilder.new(self)
        block.bind(grid_builder).call
      end
    end

    class GridBuilder
      attr_accessor :context_object

      def initialize(context_object)
        @context_object = context_object
      end

      def method_missing(name, *args, &block)
        raise "No block given" unless block

        create_action("#{name}_grid") do
          block.bind(self).call
          unless performed?
            render :layout => false
          end
        end
      end

      private
      def create_action(name, &block)
        context_object.send(:define_method, name.to_sym, &block)
      end
    end
  end

  module View
    module InstanceMethods

      def grid(name, *args, &block)
        options    = args.extract_options!
        collection = args.shift

        raise ArgumentError, "Missing collection in grid definition" if !collection and block_given?

        grid_controller = params[:controller]

        if name =~ /\//
          name_parts      = name.split(/\//)
          grid_controller = name_parts.first
          name            = name_parts.last
        end
        grid_class = options[:class] || "gridzilla"
        data       = options[:data] || {}

        unless @gridzilla_script_loaded
          main_script =  <<-SCRIPT
            if (!gridzilla) { '';
              var gridzilla = {};

              (function(){

                var gridzilla_data = {};
                gridzilla.get_data = function(grid_name) {
                  return gridzilla_data[grid_name];
                }
                gridzilla.set_data = function(grid_name, data) {
                  gridzilla_data[grid_name] = data;
                }

                var gridzilla_is_loaded = {};
                gridzilla.is_loaded = function(grid_name) {
                  return gridzilla_is_loaded[grid_name];
                }
                gridzilla.set_loaded = function(grid_name) {
                  gridzilla_is_loaded[grid_name] = true;
                }
                gridzilla.set_unloaded = function(grid_name) {
                  gridzilla_is_loaded[grid_name] = false;
                }


                var gridzilla_options = {};
                gridzilla.get_option = function(grid_name, option_name) {
                  if (gridzilla_options[grid_name]) {
                    return gridzilla_options[grid_name][option_name];
                  }
                }
                gridzilla.set_option = function(grid_name, option_name, value) {
                  if (!gridzilla_options[grid_name]) {
                    gridzilla_options[grid_name] = {};
                  }
                  gridzilla_options[grid_name][option_name] = value;
                }

                gridzilla.setup = function(grid_name) {

                  if (gridzilla.get_option(grid_name, 'height') && $("#"+grid_name).is(":not(div > .#{Gridzilla::Css::Empty})")) {
                    if ($("#"+grid_name+" .#{Gridzilla::Css::Table}:first").height() > gridzilla.get_option(grid_name, 'height')) {
                      $("#"+grid_name+" .#{Gridzilla::Css::TableContainer}:first").height(gridzilla.get_option(grid_name, 'height')).fixedHeaderTable();
                      //$("#"+grid_name+" .#{Gridzilla::Css::Table}:first").Scrollable(gridzilla.get_option(grid_name, 'height'));
                    }
                  }

                  //Handle Check Boxes
                  $("#"+grid_name+"_select_all").click(function() {
                    if ($("#"+grid_name+" thead:first tr.ui-selected").length == 0) {
                      $("#"+grid_name+" tr").addClass("ui-selected").removeClass("ui-partial");
                      gridzilla.popup_multi_page_select(grid_name);
                    } else {
                      $("#"+grid_name+" tr").removeClass("ui-selected ui-partial");
                      gridzilla.deactivate_multi_page_select(grid_name);
                    }

                    if (gridzilla.get_option(grid_name, 'form_var')) {
                      $('#'+gridzilla.get_option(grid_name, 'form_var')).val(gridzilla.selected_values(grid_name));
                    }
                  });


                  $("#"+grid_name+" .#{Gridzilla::Css::TableContainer}:first thead:first .#{Gridzilla::Css::Sortable}").click(function() {
                    var column_header = $(this);
                    var sort_key      = $("input[name=sort_key]", this).val();

                    if (column_header.hasClass("#{Gridzilla::Css::SortAsc}")) {
                      var pagination_data = {sort_key: sort_key, sort_order: "DESC"};
                    } else if (column_header.hasClass("#{Gridzilla::Css::SortDesc}")) {
                      var pagination_data = {sort_key: "", sort_order: ""};
                    } else {
                      var pagination_data = {sort_key: sort_key, sort_order: "ASC", page: 1};
                    }

                    var new_gridzilla_data = $.extend(gridzilla.get_data(grid_name), pagination_data);

                    gridzilla.set_data(grid_name, new_gridzilla_data);
                    gridzilla.load(grid_name);
                  });

                  gridzilla.set_loaded(grid_name);
                };

                gridzilla.row_click = function(element) {
                  grid_name = $(element).parents('.gridzilla').get(0).id;

                  if ($(element).is("tr:has(.#{Gridzilla::Css::RadioButton})")) {
                    $(element).closest('.gridzilla').find("tr").removeClass("ui-selected");
                    $(element).addClass("ui-selected");
                  } else {
                    if ($(element).closest('tr').hasClass('ui-selected')){
                      gridzilla.deactivate_multi_page_select(grid_name);
                    }
                    $(element).toggleClass('ui-selected');
                    gridzilla.select_all_adorning($(element).closest('.gridzilla'), grid_name);
                  }

                  if (gridzilla.get_option(grid_name, 'form_var')) {
                    $('#'+gridzilla.get_option(grid_name, 'form_var')).val(gridzilla.selected_values(grid_name));
                  }
                };

                gridzilla.select_all_adorning = function(grid_jqo, grid_name) {
                  if ($("tbody td .#{Gridzilla::Css::Checkbox}", grid_jqo).length == $("tbody tr.ui-selected td .#{Gridzilla::Css::Checkbox}", grid_jqo).length) {
                    $("thead tr", grid_jqo).addClass('ui-selected');
                    $("thead tr", grid_jqo).removeClass('ui-partial');
                    gridzilla.popup_multi_page_select(grid_name);
                  } else if ($("tbody tr.ui-selected td .#{Gridzilla::Css::Checkbox}", grid_jqo).length == 0) {
                    $("thead tr", grid_jqo).removeClass('ui-selected');
                    $("thead tr", grid_jqo).removeClass('ui-partial');
                  } else {
                    $("thead tr", grid_jqo).removeClass('ui-selected');
                    $("thead tr", grid_jqo).addClass('ui-partial');
                  }
                };

                gridzilla.deselect_all = function(grid_name) {
                  $("#search_users .gz_table_container .fht_table_body .gz_table tbody tr").removeClass("ui-selected");
                  $("tr",'#'+grid_name).removeClass('ui-partial ui-selected');
                };

                gridzilla.selected_values = function(grid_name, attribute) {
                  if (gridzilla.get_option(grid_name,'multi_page_selected') && gridzilla.get_option(grid_name,'total_records') > 100){
                    x=gridzilla.get_data(grid_name);
                    a=[];
                    for(key in x){
                      if(x[key]!=''){
                        if ($.isArray(x[key]) && !key.match(/.*\\[\\]$/)){
                          a.push('"'+key+'[]":"'+x[key]+'"');
                        }else{
                          a.push('"'+key+'":"'+x[key]+'"');
                        }
                      }
                    };
                    return {"length":gridzilla.get_option(grid_name,'total_records'),join:function(charac){
                        return "{current_user:"+current_user_id+",current_school:"+current_school_id+',count:'+gridzilla.get_option(grid_name,'total_records')+
                        ",by:"+gridzilla.get_option(grid_name,'multi_page_selector')+",filters:{"+a.join(',')+'}}'
                      }}
                  } else {
                    return $.map($("#"+grid_name+" tr.ui-selected input[name="+grid_name+"_select]"), function(d) {
                      eval("var val = "+$(d).val());
                      if (attribute) {
                        return [val[attribute]];
                      } else {
                        return [val];
                      }
                    });
                  }
                };

                gridzilla.popup_multi_page_select = function(grid_name){
                  $("#"+grid_name+"_multi_select").show();
                  $(".gz_multi_clear,"+grid_name).click(function(){
                    gridzilla.deselect_all(grid_name);
                    gridzilla.deactivate_multi_page_select(grid_name)
                  });
                };

                gridzilla.activate_multi_page_select = function(grid_name){
                  $("."+grid_name+"_multi_select").toggle();
                  gridzilla.set_option(grid_name,'multi_page_selected',true);
                  $(".gz_button").hide();
                  $(".multi_page_button").show();
                };

                gridzilla.deactivate_multi_page_select = function(grid_name){
                  gridzilla.set_option(grid_name,'multi_page_selected',false);
                  $("."+grid_name+"_multi_select").show();
                  $("."+grid_name+"_multi_select.select_all").hide();
                  $("#"+grid_name+"_multi_select").hide();
                  $(".gz_button").show();
                };

                gridzilla.values = function(grid_name, attribute) {
                  return gridzilla.selected_values(grid_name, attribute);
                };

                gridzilla.unload = function(grid_name) {
                  $('#'+grid_name).html('');
                  gridzilla.set_unloaded(grid_name);
                };

                gridzilla.block = function(grid_name, message) {
                  $("#"+grid_name).block({
                    css: {
                           border: 'none',
                           padding: '10px',
                           backgroundColor: '#000',
                           '-webkit-border-radius': '5px',
                           '-moz-border-radius': '5px',
                           opacity: .7,
                           color: '#fff'
                         },
                    message: '<div class="gz_load"><img src="/assets/gridzilla/red_blk_loader.gif"/><h2>' + message + '</h2></div>'
                  });
                }

                gridzilla.load = function(grid_name, options, callback) {
                  if (!gridzilla.get_option(grid_name, "controller")) return;

                  if (grid_name && $("#"+grid_name).length > 0) {
                    options = options || {};
                    var reload = true;

                    if (options.passive) {
                      if (gridzilla.is_loaded(grid_name)) {
                        reload = false;
                      } else {
                        reload = true;
                      }
                    }

                    if (reload) {
                      if ($("#"+grid_name).is(':empty')) $("#"+grid_name).html('<div class="gz_load_spacer"></div>');
                      gridzilla.block(grid_name, 'Loading');
                      var grid_data = options.data || {};

                      if (options.keep_params) {
                        grid_data = merge(gridzilla.get_option(grid_name, "params"), grid_data);
                      }

                      for (attribute in gridzilla.get_data(grid_name)) {
                        if (grid_data[attribute] == undefined) {
                          grid_data[attribute] = gridzilla.get_data(grid_name)[attribute];
                        }
                      }

                      var grid_url = gridzilla.get_option(grid_name, "url") || '/gridzilla/'+gridzilla.get_option(grid_name, "controller")+'/'+grid_name+'_grid';


                      var data_str = (typeof(grid_data) === 'string') ? grid_data : $.param(grid_data, false);

                      $.get(grid_url, data_str, function(data) {
                        $('#'+grid_name).html(data);
                        gridzilla.setup(grid_name);
                        if (callback) callback();
                      });
                    }
                  }
                };

                gridzilla.action_function = function(function_name, grid_name, attribute, options) {
                  var selected_ids = gridzilla.values(grid_name, attribute);

                  var constraint_range = [1, Infinity];
                  if (options.selection_constraint == 'single') {
                    constraint_range = [1, 1];
                  } else if (options.selection_constraint instanceof Array) {
                    constraint_range = options.selection_constraint;
                  }

                  if (selected_ids.length < constraint_range[0] || selected_ids.length > constraint_range[1]) {
                    if (selected_ids.length == 0) {
                      alert(options.empty_message);
                    } else if (options.selection_constraint == 'single') {
                      alert(options.single_message);
                    } else if (constraint_range[1] == Infinity) {
                      alert('You must select ' + constraint_range[0] + ' or more items.');
                    } else {
                      alert('You must select ' + constraint_range[0] + '..' + constraint_range[1] + ' items.');
                    }
                  } else {
                    if (options.block_message) {
                      gridzilla.block(grid_name, options.block_message);
                    }

                    if (constraint_range[1] == 1) {
                      window[function_name](selected_ids[0]);
                    } else {
                      window[function_name](selected_ids);
                    }
                  }
                };

                gridzilla.add_class = function(element, css_class) {
                  $(element).addClass(css_class);
                };

                gridzilla.remove_class = function(element, css_class) {
                  $(element).removeClass(css_class);
                };

                var clone = function(obj) {
                  var copy = {};

                  for (attribute in obj) {
                    copy[attribute] = obj[attribute];
                  }

                  return copy;
                };

                var merge = function(first, second) {
                  var result = clone(first);

                  for (attribute in second) {
                    result[attribute] = second[attribute];
                  }

                  return result;
                };

              })();
            }
          SCRIPT
          concat(content_tag(:script,main_script.html_safe,nil,false))
          @gridzilla_script_loaded = true
        end

        concat(content_tag(:script, <<-SCRIPT, nil, false))
          gridzilla.set_data('#{name}', #{data.to_json});
          #{"gridzilla.set_option('#{name}', 'height', #{options[:height].to_json});" if options[:height]}
        #{"gridzilla.set_option('#{name}', 'form_var', #{options[:form_var].to_json});" if options[:form_var]}
        #{"gridzilla.set_option('#{name}', 'url', #{options[:url].to_json});" if options[:url]}
       SCRIPT

        if options[:form_var]
          concat("<input type='hidden' value='' id='#{options[:form_var]}' name='#{options[:form_var]}' />")
        end

        if block_given?
          @gridzilla ||= []
          @gridzilla.push({})
          @gridzilla.last[:grid_name]       = name
          @gridzilla.last[:grid_controller] = grid_controller
          @gridzilla.last[:collection]      = collection
          @gridzilla.last[:selected_items]  = options[:selected_items]

          concat(tag(:div, {:id => name, :class => grid_class}, true))
          view_dsl = Gridzilla::ViewDsl::Base.new(Gridzilla::View::Grid.new(self), self)
          view_dsl.instance_eval(&block)
          concat('</div>'.html_safe)

          concat(content_tag(:script, <<-SCRIPT,nil,false))
            setTimeout(function() {
              gridzilla.setup('#{name}');
              gridzilla.set_option('#{name}', 'controller', #{grid_controller.to_json});
              gridzilla.set_option('#{name}', 'params', #{request.query_parameters.to_json});
              gridzilla.set_option('#{name}', 'single_select', #{(!!@gridzilla.last[:single_select]).to_json});
              gridzilla.set_option('#{@gridzilla.last[:grid_name]}', 'multi_page_selected', false);
            }, 0);
          SCRIPT

          @gridzilla.pop
        else
          concat(content_tag(:div, "", :id => name, :class => grid_class))
          if options[:lazy]
            concat(content_tag(:script, <<-SCRIPT, nil, false))
              $(function() {
                gridzilla.set_option('#{name}', 'controller', #{grid_controller.to_json});
              });
            SCRIPT
          else
            concat(content_tag(:script, <<-SCRIPT, nil, false))
              $(function() {
                gridzilla.set_option('#{name}', 'controller', #{grid_controller.to_json});
                gridzilla.load('#{name}');
              });
            SCRIPT
          end

          if Rails.env.development?
            concat(content_tag(:div, content_tag(:a, 'reload grid', :href => '#', :onclick => "gridzilla.load('#{name}')", :class => 'reload_link'), :id => "#{name}_reloader"))
          end
        end
      end

      def ajax_grid(collection, *args, &block)
        options = args.extract_options!

        raise ArgumentError, "Missing block in ajax_grid definition" unless block_given?

        @gridzilla ||= []
        @gridzilla.push({})
        @gridzilla.last[:grid_controller] = params[:controller]
        @gridzilla.last[:grid_name]       = options[:grid_name] || params[:action][0..-6] # MAGIC_NUMBER(-6) removes the _grid on the action name
        @gridzilla.last[:collection]      = collection
        @gridzilla.last[:selected_items]  = options[:selected_items]
        @gridzilla.last[:multi_page_selector] = options[:multi_page_selector]
        view_dsl = Gridzilla::ViewDsl::Base.new(Gridzilla::View::AjaxGrid.new(self), self)
        view_dsl.instance_eval(&block)

        concat(content_tag(:script, <<-SCRIPT))
          gridzilla.set_option('#{@gridzilla.last[:grid_name]}', 'controller', #{@gridzilla.last[:grid_controller].to_json});
          gridzilla.set_option('#{@gridzilla.last[:grid_name]}', 'params', #{request.query_parameters.to_json});
          gridzilla.set_option('#{@gridzilla.last[:grid_name]}', 'single_select', #{(!!@gridzilla.last[:single_select]).to_json});
          gridzilla.set_option('#{@gridzilla.last[:grid_name]}', 'multi_page_selected', false);
        SCRIPT

        concat(content_tag(:script,<<-SCRIPT)) if options[:multi_page_selector]
          gridzilla.set_option('#{@gridzilla.last[:grid_name]}', 'multi_page_selector',#{options[:multi_page_selector].to_json});
          gridzilla.set_option('#{@gridzilla.last[:grid_name]}', 'total_records',#{collection.total_entries.to_json});
        SCRIPT

        @gridzilla.pop
      end

    end

    class Grid
      def initialize(view)
        @view      = view
        @gridzilla = @view.instance_variable_get('@gridzilla')
      end

      def title(*args, &block)
        options = args.extract_options!
        text    = args.shift

        raise ArgumentError, "Missing block or text in title definition" unless block_given? or text

        options[:class] = "#{Gridzilla::Css::Title} #{options[:class]}".strip

        if block_given?
          @view.concat(@view.tag(:div, options, true))
          yield
          @view.concat("</div>".html_safe)
        else
          @view.concat(@view.content_tag(:div, @view.content_tag(:h4, text), options))
        end
      end

      def panel(*args, &block)
        options = args.extract_options!

        options[:class] = "#{Gridzilla::Css::Panel} #{options[:class]}".strip

        raise ArgumentError, "Missing block in panel definition" unless block_given?

        view_dsl = Gridzilla::ViewDsl::Base.new(Gridzilla::View::Panel.new(@view), @view)

        @view.concat(@view.tag(:div, options, true))
        view_dsl.instance_eval(&block)
        @view.concat("<div class='clear'></div></div>".html_safe)
      end

      def rows(*args, &block)
        options = args.extract_options!

        raise ArgumentError, "Missing block in rows definition" unless block_given?

        view_dsl                     = Gridzilla::ViewDsl::Base.new(Gridzilla::View::Row.new(@view), @view)
        @gridzilla.last[:row_number] = if @gridzilla.last[:collection].respond_to? :total_pages
                                         @gridzilla.last[:collection].offset
                                       else
                                         0
                                       end

        if @gridzilla.last[:multi_page_selector] and @gridzilla.last[:collection].total_entries > @gridzilla.last[:collection].length
          @view.concat("<div class='#{Gridzilla::Css::Notice}' id='#{@gridzilla.last[:grid_name]}_multi_select'>")
          @view.concat("<span class='#{@gridzilla.last[:grid_name]}_multi_select'>#{@gridzilla.last[:collection].length} items on this page are selected. ")
          @view.concat("<span onclick='gridzilla.activate_multi_page_select(\"#{@gridzilla.last[:grid_name]}\")'")
          @view.concat(" class='link'>Select all #{@gridzilla.last[:collection].total_entries} items.</span>")
          @view.concat("</span>")
          @view.concat("<span class='#{@gridzilla.last[:grid_name]}_multi_select select_all'>")
          @view.concat("All #{@gridzilla.last[:collection].total_entries} items are selected. ")
          @view.concat("<span class='link gz_multi_clear'>Clear Selection.</span></span></div>")
        end
        @view.concat("<div class='#{Gridzilla::Css::TableContainer}'>".html_safe)
        @view.concat("<table class='#{Gridzilla::Css::Table}'>".html_safe)
        @view.concat("<thead>".html_safe)
        @view.concat("<tr>".html_safe)
        @gridzilla.last[:row_data] = nil
        if block.arity == 1
          view_dsl.instance_exec(Gridzilla::Gobbler.new, &block)
        else
          view_dsl.instance_exec(Gridzilla::Gobbler.new, @gridzilla.last[:collection], &block)
        end
        @view.concat("</tr>".html_safe)
        @view.concat("</thead>".html_safe)

        @view.concat("<tbody>".html_safe)

        row_css_class_option  = options[:class]
        row_css_id_option     = options[:id]

        options[:onmouseover] = "gridzilla.add_class(this, 'over');#{options[:onmouseover]}"
        options[:onmouseout]  = "gridzilla.remove_class(this, 'over');#{options[:onmouseout]}"
        options[:onclick]     = "gridzilla.row_click(this);#{options[:onclick]}"
        @gridzilla.last[:collection].each do |item|
          row_css_class = row_css_class_option.is_a?(Proc) ? row_css_class_option.call(item) : row_css_class_option
          row_css_id    = row_css_id_option.is_a?(Proc) ? row_css_id_option.call(item) : row_css_id_option

          if @gridzilla.last[:selected_items] and @gridzilla.last[:selected_items].include?(item)
            options[:class] = "#{row_css_class} ui-selected"
          else
            options[:class] = row_css_class
          end
          options[:id]    = row_css_id
          options[:class] = options[:class].to_s + @view.cycle(" alt", "")
          @view.concat(@view.tag(:tr, options, true).html_safe)
          @gridzilla.last[:row_data] = item
          if block.arity == 1
            view_dsl.instance_exec(item, &block)
          else
            view_dsl.instance_exec(item, @gridzilla.last[:collection], &block)
          end
          @view.concat("</tr>".html_safe)
        end
        @view.concat("</tbody>".html_safe)
        @view.concat("</table>".html_safe)
        @view.concat("</div>".html_safe)
        if @gridzilla.last[:collection].empty? and @gridzilla.last[:empty_block]
          empty_options         = @gridzilla.last[:empty_block_options] || {}
          empty_options[:class] = "#{Gridzilla::Css::Empty} #{empty_options[:class]}".strip

          @view.concat(@view.tag(:div, empty_options, true))
          @view.instance_eval &@gridzilla.last[:empty_block]
          @view.concat("</div>".html_safe)
        end
      end
    end

    class AjaxGrid < Gridzilla::View::Grid
    end

    class Panel
      def initialize(view)
        @view      = view
        @gridzilla = @view.instance_variable_get('@gridzilla')
      end

      def action_function(name, function_name, *args, &block)
        options = args.extract_options!

        options[:class] = "#{Gridzilla::Css::PanelAction} #{options[:class]}".strip

        json_options = {
          :empty_message        => options.delete(:empty_message) || Message::DefaultEmptySelection,
          :single_message       => options.delete(:single_message) || Message::DefaultSingleSelection,
          :selection_constraint => options.delete(:selection_constraint) || :multiple,
          :block_message        => options.delete(:block_message)
        }

        attribute_name = args.first

        @view.link_to_function name, "gridzilla.action_function(#{function_name.to_json}, #{@gridzilla.last[:grid_name].to_json}, #{attribute_name.to_json}, #{json_options.to_json})", options
      end

      def pagination_links(*args)
        options = args.extract_options!

        #SANSEI: WillPaginate::Collection ain't here no more, my hack asks if it quacks like a will_paginate
        if @gridzilla.last[:collection].respond_to? :total_pages
          @view.will_paginate(@gridzilla.last[:collection], renderer: PaginationLinkRenderer)
        end
      end
    end

    class Row
      def initialize(view)
        @view      = view
        @gridzilla = @view.instance_variable_get('@gridzilla')
      end

      def if_empty(*args, &block)
        options = args.extract_options!

        if @gridzilla.last[:row_data].nil?
          @gridzilla.last[:empty_block_options] = options
          @gridzilla.last[:empty_block]         = block
        end
      end

      def single_select_column(attribute, *args, &block)
        options = args.extract_options!
        options.merge!({:style => 'width: 12px;'})

        if @gridzilla.last[:row_data].nil?
          @view.concat(@view.tag(:th))
          @gridzilla.last[:single_select] = true
        elsif attribute.is_a?(Symbol)
          @view.concat(@view.content_tag(:td, @view.tag(:input, :type => "hidden", :name => "#{@gridzilla.last[:grid_name]}_select", :value => @gridzilla.last[:row_data].send(attribute).to_json, :id => nil)+@view.tag(:div, :class => Gridzilla::Css::RadioButton), options,false))
        else
          @view.concat(@view.content_tag(:td, @view.tag(:input, :type => "hidden", :name => "#{@gridzilla.last[:grid_name]}_select", :value => attribute.to_json, :id => nil)+@view.tag(:div, :class => Gridzilla::Css::RadioButton), options,false))
        end
      end

      def select_column(attribute, *args, &block)
        options = args.extract_options!
        options.merge!({:style => 'width: 12px;'})

        if @gridzilla.last[:row_data].nil?
          @view.concat(@view.content_tag(:th, @view.content_tag(:div, '', :class => Gridzilla::Css::Checkbox, :id => "#{@gridzilla.last[:grid_name]}_select_all")))
        elsif attribute.is_a?(Symbol)
          @view.concat(@view.content_tag(:td, @view.tag(:input, :type => "hidden", :name => "#{@gridzilla.last[:grid_name]}_select", :value => @gridzilla.last[:row_data].send(attribute).to_json, :id => nil)+@view.content_tag(:div, '', :class => Gridzilla::Css::Checkbox), options))
        else
          @view.concat(@view.content_tag(:td, @view.tag(:input, :type => "hidden", :name => "#{@gridzilla.last[:grid_name]}_select", :value => attribute.to_json, :id => nil)+@view.content_tag(:div, '', :class => Gridzilla::Css::Checkbox), options))
        end
      end

      def row_number_column(*args, &block)
        options = args.extract_options!

        if @gridzilla.last[:row_data].nil?
          @view.concat(@view.content_tag(:th, "&nbsp;", options,false))
        else
          @view.concat(@view.tag(:td, options, true))
          @view.concat("#{@gridzilla.last[:row_number] += 1}")
          @view.concat("</td>".html_safe)
        end
      end

      def column(name = "", *args, &block)
        options   = args.extract_options!
        attribute = args.shift

        sort_key = options.delete(:sort_key)

        raise ArgumentError, "Missing block or attribute in column definition" unless block_given? or attribute

        if @gridzilla.last[:row_data].nil?
          header_content = name
          if sort_key
            options[:class] = "#{Gridzilla::Css::Sortable} #{options[:class]}".strip
            header_content << @view.hidden_field_tag("sort_key", sort_key).html_safe

            if @view.params[:sort_key] == sort_key
              if @view.params[:sort_order] == "DESC"
                options[:class] = "#{Gridzilla::Css::SortDesc} #{options[:class]}".strip
              else
                options[:class] = "#{Gridzilla::Css::SortAsc} #{options[:class]}".strip
              end
            end
          end
          @view.concat(@view.content_tag(:th, header_content, options, false))
        else
          @view.concat(@view.tag(:td, options, true))
          if block_given?
            yield
          else
            @view.concat(@gridzilla.last[:row_data].send(attribute).to_s)
          end
          @view.concat("</td>".html_safe)
        end
      end
    end
  end
end

ActionController::Base.send :include, Gridzilla::Controller
ActionView::Base.send :include, Gridzilla::View::InstanceMethods
