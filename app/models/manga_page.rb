class MangaPage < ApplicationRecord
  belongs_to :chapter,
    class_name: MangaChapter.name,
    foreign_key: :manga_chapter_id

  has_attached_file :image,
    url: '/system/manga_pages/:style/:manga_id_mod/:manga_id/:chapter_name/:number.:extension',
    path: ':rails_root/public/system/manga_pages/:style/:manga_id_mod/:manga_id/:chapter_name/:number.:extension'

  validates :url, presence: true, url: true, uniqueness: true
  validates :number, presence: true
  validates :image, attachment_content_type: { content_type: /\Aimage/ }

  def load_image
    self.image = open_image url
    self.save
  end

  def chapter_name
    Zaru.sanitize! Russian.translit(chapter.name)
  end

  def manga_id
    chapter.manga_id
  end

  def manga_id_mod
    chapter.manga_id % 250
  end
end
