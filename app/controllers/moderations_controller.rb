class ModerationsController < ShikimoriController
  before_action :authenticate_user!
  before_action { breadcrumb t('application.top_menu.shikimori.moderations_content'), moderations_url }
  before_action { page_title t('application.top_menu.shikimori.moderations_content') }

  def show
  end

  def missing_screenshots
    page_title t("moderations.missing_screenshots.title")

    @collection = Rails.cache.fetch :missing_screenshots, expires_in: 10.minutes do
      Moderation::MissingScreenshotsQuery.new.fetch
    end
  end

  def missing_videos
    page_title t('moderations.show.missing_videos')

    if params[:kind]
      breadcrumb t('moderations.show.missing_videos'), missing_videos_moderations_url
      page_title t("moderations.missing_videos.#{params[:kind]}")
      @collection = Rails.cache.fetch [:missing_videos, params[:kind]], expires_in: 10.minutes do
        Moderation::MissingVideosQuery.new(params[:kind]).animes
      end
    end
  end

  def missing_episodes
    @anime = Anime.find params[:anime_id]
    @episodes = Moderation::MissingVideosQuery.new(params[:kind]).episodes @anime
  end
end
