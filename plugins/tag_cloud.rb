module Jekyll
  class TagCloud < Liquid::Tag
    safe = true

    def render(context)
      s = StringIO.new
      begin
        tags = context['site']['tags'].map{|tag|
          {
            "title"    => tag[0],
            "posts"    => tag[1]
          }
        }
        unless tags.nil?
          min_count = tags.min{|a, b| a["posts"].length <=> b["posts"].length }["posts"].length
          max_count = tags.max{|a, b| a["posts"].length <=> b["posts"].length }["posts"].length

          weights = tags.inject({}){|result, tag| result[tag["title"]] = ( ((tag["posts"].length - min_count) * (280 - 75)) / (max_count - min_count) ) + 75; result }

          tags.inject("") { |html, tag|
            s << "<span style='font-size: #{sprintf("%d", weights[tag['title']])}%'>"
            s << "<a href='/tag/#{tag['title'].gsub(/_|\W/, '-')}/'>#{tag["title"]}</a>"
            s << "</span>\n"
          }
        end
      rescue => boom
        p boom
      end
      s.string
    end
  end
end

Liquid::Template.register_tag('tag_cloud', Jekyll::TagCloud)
