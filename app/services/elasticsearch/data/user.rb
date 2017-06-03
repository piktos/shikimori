class Elasticsearch::Data::User < Elasticsearch::Data::DataBase
  text_search_fields %i[nickname]
  data_fields %i[]
  track_changes_fields TEXT_SEARCH_FIELDS

private

  def nickname
    fix @entry.nickname
  end
end
