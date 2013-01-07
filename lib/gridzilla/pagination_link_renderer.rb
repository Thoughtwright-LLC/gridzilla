require 'will_paginate/view_helpers/link_renderer'
module Gridzilla
  class PaginationLinkRenderer < WillPaginate::ViewHelpers::LinkRenderer
    protected

    def page_number(page)
      if page == current_page
        tag(:span, page, class: 'current')
      else
        grid_name = @template.instance_eval("@gridzilla.last[:grid_name].to_json")
        options        = HashWithIndifferentAccess.new.merge(@template.request.query_parameters.clone)
        options[:page] = page
        extra_options = @template.instance_eval do
          Gridzilla::PaginationLinkRenderer.to_flat_json(options)
        end


        @template.link_to_function(page, 
          "gridzilla.set_data(#{grid_name}, $.extend(gridzilla.get_data(#{grid_name}), {page: #{page}})); gridzilla.load(#{grid_name}, {data: {#{extra_options}}})")
      end
    end

    def previous_or_next_page(page, text, classname)
      if page
        page_num = current_page + 1
        if classname == "previous_page"
          classname = "prev_page"
          page_num = current_page - 1
        end

        grid_name = @template.instance_eval("@gridzilla.last[:grid_name].to_json")
        options        = HashWithIndifferentAccess.new.merge(@template.request.query_parameters.clone)
        options[:page] = page
        extra_options = @template.instance_eval do
          Gridzilla::PaginationLinkRenderer.to_flat_json(options)
        end

        @template.link_to_function(text.html_safe,
          "gridzilla.set_data(#{grid_name}, $.extend(gridzilla.get_data(#{grid_name}), {page: #{page_num}})); gridzilla.load(#{grid_name}, {data: {#{extra_options}}})")
      else
        tag(:span, text, :class => classname + " disabled")
      end
    end

    class << self
      def to_flat_json(hash, parent_array = [])
        json = hash.map do |key, value|
          if value.is_a?(Hash)
            to_flat_json(value, parent_array + [key])
          else
            "#{array_to_json_key(key, parent_array.clone).to_json}: #{value.to_json}"
          end
        end.flatten.join(", ")
        json
      end

      def array_to_json_key(key, parent_array)
        unless parent_array.empty?
          response_string = parent_array.shift
          parent_array.each do |string|
            response_string << "[#{string}]"
          end
          "#{response_string}[#{key}]"
        else
          key
        end
      end
    end
  end
end
