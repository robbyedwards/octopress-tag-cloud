# Octopress tag cloud generator.
#
# Version: 0.1
#
# Copyright (c) 2012 Robby Edwards, http://robbyedwards.com.com/
# Licensed under the MIT license (http://www.opensource.org/licenses/mit-license.php)
#
# Octopress plugin to display tag clouds.
# Based on https://gist.github.com/1577100 by @tokkonopapa
#
# Defines a 'tag_cloud' tag that is rendered by Liquid into a tag cloud:
#
#     <div class='cloud'>
#         {% tag_cloud %}
#     </div>
#
# The tag cloud itself is a collection of anchor tags, styled dynamically
# with the 'font-size' CSS property. The range of values, and unit to use for
# 'font-size' can be specified with a very simple syntax:
#
#     {% tag_cloud font-size: 16 - 28px %}
#
# The output is automatically formatted to use the same number of decimal
# places as used in the argument:
#
#     {% tag_cloud font-size: 0.8  - 1.8em  %}  # => 1
#     {% tag_cloud font-size: 0.80 - 1.80em %}  # => 2
#
# Tags that have been used less than a certain number of times can be
# filtered out from the tag cloud with the optional 'threshold' parameter:
#
#     {% tag_cloud threshold: 2 %}
#
# The ouptput can be limited to a certain number of the most frequently occuring tags
# when the sort method is alphabetical or frequency:
#
#     {% tag_cloud limit: 8 %} => results in a tag cloud with the eight most frequent
#                                 tags sorted alphabetically
#
# When the sort method is random then output is randomly sorted and limited to @limit
# items. Setting the 'limit' parameter to zero (the default) will display all tags.
#
# The output can be sorted in three ways:
#
#     {% tag_cloud sort: freq|rand|alpha %}
#
#  -- freq will sort by the frequency of the tag's occurence
#  -- rand will sort randomly each time the cloud is generated
#  -- alpha (the default) will sort the tags in alphabetical order
#
# An optional 'order' parameter can also be set, which will change the sort order:
#
#     {% tag_cloud sort: freq|rand|alpha [asc|desc] %}
#
# By default, alphabetical sorts will be asc, and frequency sorts will be desc. The 
# 'order' parameter has no effect on random sorts.
#
# 
#
# Multiple parameters can be separated by a comma:
#
#     {% tag_cloud font-size: 50 - 150%, threshold: 2 %}

module Jekyll

  class TagCloud < Liquid::Tag
    safe = true

    # tag cloud variables - these are setup in 'initialize'
    attr_reader :size_min, :size_max, :precision, :unit, :threshold, :limit, :sort, :order, :style, :separator

    def initialize(name, params, tokens)
      # initialize default values
      @size_min, @size_max, @precision, @unit = 70, 170, 0, '%'
      @threshold                              = 1
      @limit                                  = 0
      @sort, @order                           = 'alpha', 'asc'
      @order = 'desc' if @sort == 'freq'
      @style, @tag_before, @tag_after, @separator = 'list', '<li>', '</li>', ', '

      # process parameters
      @params = Hash[*params.split(/(?:: *)|(?:, *)/)]
      process_font_size(@params['font-size'])
      process_threshold(@params['threshold'])
      process_limit(@params['limit'])
      process_sort(@params['sort'])
      process_style(@params['style'])

      super
    end

    def render(context)
      # get the directory for the tag links
      dir = context.registers[:site].config['tag_dir']

      # get an Array of [tag name, tag count] pairs
      count = context.registers[:site].tags.map do |name, posts|
        [name, posts.count] if posts.count >= threshold
      end

      # clear nils if any
      count.compact!

      # get the minimum, and maximum tag count
      min, max = count.map(&:last).minmax

      # map: [[tag name, tag count]] -> [[tag name, tag weight]]
      weighted = count.map do |name, count|
        # logarithmic distribution
        weight = (Math.log(count) - Math.log(min))/(Math.log(max) - Math.log(min))
        [name, weight]
      end

      # get the top @limit tag pairs when a limit is given, unless the sort method is random
      if @limit > 0 and @sort != 'rand'
        # sort the tag pairs by frequency in descending order
        weighted.sort! { |a,b| b[1] <=> a[1] }

        # then slice off the top @limit tag pairs
        weighted = weighted[0,@limit]
      end

      # sort the [tag name, tag weight] pairs
      case @sort
      when 'freq'
        if @order == 'asc'
          # sorts from least to most frequent
          weighted.sort! { |a,b| a[1] <=> b[1] }
        elsif @limit == 0
          # otherwise, sort from the most to least frequent
          weighted.sort! { |a,b| b[1] <=> a[1] }
        end
      when 'rand'
        weighted.sort_by! { rand }

        if @limit > 0
          # slice off the top @limit tag pairs
          weighted = weighted[0,@limit]
        end
      else
        if @order == 'desc'
          # sorts in reverse alphabetical order, i.e z to a
          weighted.sort! { |a,b| b <=> a }
        else
          # otherwise, sorts in alphabetical order, i.e a to z
          weighted.sort! { |a,b| a <=> b }
        end
      end

      html = ""

      # iterate over the weighted tag Array and create the tag items
      weighted.each_with_index do |tag, i|
        name, weight = tag
        size = size_min + ((size_max - size_min) * weight).to_f
        size = sprintf("%.#{@precision}f", size)
        @separator = "" if i == (weighted.size - 1)
        html << "#{@tag_before}<a style=\"font-size: #{size}#{unit}\" href=\"#{dir}/#{name.downcase}/\">#{name}</a>#{@separator}#{@tag_after}\n"
      end

      return html
    end

    private

    def process_font_size(param)
      /(\d*\.{0,1}(\d*)) *- *(\d*\.{0,1}(\d*)) *(%|em|px)/.match(param) do |m|
        @size_min  = m[1].to_f
        @size_max  = m[3].to_f
        @precision = [m[2].size, m[4].size].max
        @unit      = m[5]
      end
    end

    def process_threshold(param)
      /\d*/.match(param) do |m|
        @threshold = m[0].to_i
      end
    end

    def process_limit(param)
      /\d*/.match(param) do |m|
        @limit = m[0].to_i
      end
    end

    def process_sort(param)
      /(freq|rand|alpha) *(asc|desc)?/.match(param) do |m| #/
        @sort  = m[1]
        @order = m[2]
      end
    end

    def process_style(param)
      /(list|para) *({(.*)})?/.match(param) do |m| #/
        @style     = m[1]
        @separator = m[3]
      end

      @tag_before = @tag_after = "" if @style == "para"
      @separator = "" if @style == "list"
    end

  end

end

Liquid::Template.register_tag('tag_cloud', Jekyll::TagCloud)
