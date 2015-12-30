xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0" do
  xml.channel do
    xml.title "Новости #{Site::DOMAIN}"
    xml.description "Аниме новости и овости сайта #{Site::DOMAIN}"
    xml.link root_url

    @topics.each do |topic|
      xml.item do
        xml.title topic.title
        xml.description format_rss_urls(BbCodeFormatter.instance.format_comment topic.text)
        xml.pubDate Time.at(topic.updated_at.to_i)
        xml.link topic_url(topic)
        xml.guid "entry-#{topic.id}"
      end
    end
  end
end
