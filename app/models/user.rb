# TODO: refactor UserNotifications module inclusion
class User < ActiveRecord::Base
  include PermissionsPolicy
  include UserNotifications
  include Commentable

  CommentForbiddenMessage = 'Вы не можете писать этому пользователю'
  CensoredIds = Set.new [4357]

  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :validatable, :omniauthable, :async

  has_one :preferences, dependent: :destroy, class_name: UserPreferences.name
  accepts_nested_attributes_for :preferences

  has_many :comments_all, class_name: Comment.name, dependent: :destroy
  has_many :abuse_requests, dependent: :destroy

  has_many :anime_rates, -> { where target_type: Anime.name },
    class_name: UserRate.name,
    source: :target_id,
    dependent: :destroy

  has_many :manga_rates, -> { where target_type: Manga.name },
    class_name: UserRate.name,
    source: :target_id,
    dependent: :destroy

  #has_many :topic_views
  has_many :history, class_name: UserHistory.name, dependent: :destroy

  has_many :friend_links, foreign_key: :src_id, dependent: :destroy
  has_many :friends, through: :friend_links, source: :dst, dependent: :destroy

  has_many :favourites, dependent: :destroy
  has_many :favourite_seyu, -> { where kind: Favourite::Seyu }, class_name: Favourite.name, dependent: :destroy
  has_many :favourite_producers, -> { where kind: Favourite::Producer }, class_name: Favourite.name, dependent: :destroy
  has_many :favourite_mangakas, -> { where kind: Favourite::Mangaka }, class_name: Favourite.name, dependent: :destroy
  has_many :favourite_persons, -> { where kind: Favourite::Person }, class_name: Favourite.name, dependent: :destroy

  has_many :fav_animes, through: :favourites, source: :linked, source_type: Anime.name
  has_many :fav_mangas, through: :favourites, source: :linked, source_type: Manga.name
  has_many :fav_characters, through: :favourites, source: :linked, source_type: Character.name
  has_many :fav_persons, through: :favourite_persons, source: :linked, source_type: Person.name
  has_many :fav_people, through: :favourites, source: :linked, source_type: Person.name
  has_many :fav_seyu, through: :favourite_seyu, source: :linked, source_type: Person.name
  has_many :fav_producers, through: :favourite_producers, source: :linked, source_type: Person.name
  has_many :fav_mangakas, through: :favourite_mangakas, source: :linked, source_type: Person.name

  has_many :messages, foreign_key: :to_id, dependent: :destroy

  has_many :reviews, dependent: :destroy
  has_many :votes, dependent: :destroy

  has_many :ignores, dependent: :destroy
  has_many :ignored_users, through: :ignores, source: :target

  has_many :group_roles, dependent: :destroy
  has_many :groups, through: :group_roles

  has_many :user_changes, dependent: :destroy

  has_many :subscriptions, dependent: :destroy
  has_many :contest_user_votes, dependent: :destroy

  has_many :comment_views, dependent: :destroy
  has_many :entry_views, dependent: :destroy

  has_many :nickname_changes, class_name: UserNicknameChange.name, dependent: :destroy

  has_many :recommendation_ignores, dependent: :destroy

  has_many :bans, dependent: :destroy

  has_many :user_tokens do
    def facebook
      target.detect {|t| t.provider == 'facebook' }
    end

    def twitter
      target.detect {|t| t.provider == 'twitter' }
    end
  end

  has_attached_file :avatar,
    styles: {
      #original: ['300x300>', :png],
      x160: ['160x160#', :png],
      x148: ['148x148#', :png],
      x80: ['80x80#', :png],
      x73: ['73x73#', :png],
      x64: ['64x64#', :png],
      x48: ['48x48#', :png],
      x32: ['32x32#', :png],
      x20: ['20x20#', :png],
      x16: ['16x16#', :png]
    },
    url: "/images/user/:style/:id.:extension",
    path: ":rails_root/public/images/user/:style/:id.:extension"

  validates :avatar, attachment_content_type: { content_type: /\Aimage/ }
  validates :nickname, presence: true, uniqueness: { case_sensitive: false }

  before_save :fix_nickname
  before_update :log_nickname_change

  # из этого хука падают спеки user_history_rate. хз почему. надо копаться.
  after_create :create_history_entry unless Rails.env.test?
  after_create :create_preferences!
  after_create :check_ban
  # personal message from me
  after_create :send_welcome_message unless Rails.env.test?

  LAST_ONLINE_CACHE_INTERVAL = 5.minutes

  GuestID = 5
  Blackchestnut_ID = 1077

  # access rights
  Admins = [1, Blackchestnut_ID]
  Moderators = (Admins + [921, 11, 188, 2033]).uniq # 2 - Adelor, 2033 - zmej1987
  ReviewsModerators = (Admins + []).uniq # + Moderators
  UserChangesModerators = (Admins + [11, 921, 188, 94, 942, 392]).uniq # 921 - sfairat, 188 - Forever Autumn, 11 - BlackMetalFan, 94 - AcidEmily, 942 - Иштаран, 392 - Tehanu
  AbuseRequestsModerators = (Admins + Moderators + [11, 188, 950]).uniq # Daiver
  NewsMakers = (Admins + []).uniq
  Translators = (Admins + [11, 28, 19, 31, 41, 188, 942]).uniq
  ContestsModerators = (Admins + [1483]).uniq # 1483 - Zula
  CosplayModerators = (Admins + [2043, 2046]).uniq # 2043 - laitqwerty, 2046 - Котейка
  VideoModerators = (Admins + []).uniq
  TrustedVideoUploaders = (Admins + [11496, 4099, 12771, 13893]).uniq # 11496 - АлхимиК, 4099 - sttany, 12771 - spinosa, 13893 - const

  def self.new_with_session(params, session)
    super.tap do |user|
      if data = session[:omniauth]
        user.user_tokens.build(provider: data['provider'], uid: data['uid'])
      end
    end
  end

  # allows for account creation from twitter & fb
  # allows saves w/o password
  def password_required?
    (!persisted? && user_tokens.empty?) || password.present? || password_confirmation.present?
  end

  # allows for account creation from twitter
  def email_required?
    user_tokens.empty?
  end

  def all_history
    @all_history ||= history.includes(:anime, :manga)
  end

  def anime_history
    @anime_history ||= history.where(target_type: [Anime.name, Manga.name]).includes(:anime).includes(:manga)
  end

  def anime_uniq_history
    @anime_uniq_history ||= anime_history.group(:target_id).order('max(updated_at) desc').select('*, max(updated_at) as updated_at')
  end

  def to_param
    nickname.gsub(/ /, '+')
  end

  def self.param_to text
    text.gsub(/\+/, ' ')
  end

  def self.find_by_nickname nick
    method_missing(:find_by_nickname, nick.gsub('+', ' '))
  end

  # мужчина ли это
  def male?
    self.sex && self.sex == 'male' ? true : false
  end

  # женщина ли это
  def female?
    self.sex && self.sex == 'female' ? true : false
  end

  # администратор ли пользователь?
  def admin?
    Admins.include? self.id
  end

  # модератор ли пользователь,
  def moderator?
    Moderators.include? self.id
  end

  # модератор ли пользовательских правок пользователь?
  def user_changes_moderator?
    UserChangesModerators.include? self.id
  end

  # модератор ли пользовательских правок пользователь?
  def abuse_requests_moderator?
    AbuseRequestsModerators.include? self.id
  end

  # модератор ли обзоров пользователь?
  def reviews_moderator?
    ReviewsModerators.include? self.id
  end

  # модератор ли контестов пользователь?
  def contests_moderator?
    ContestsModerators.include? self.id
  end

  # модератор ли косплея пользователь?
  def cosplay_moderator?
    CosplayModerators.include? self.id
  end

  # модератор ли видео пользователь?
  def video_moderator?
    VideoModerators.include? self.id
  end

  # ответственный ли за новости пользователь?
  def newsmaker?
    NewsMakers.include? self.id
  end

  # переводчик ли пользователь
  def translator?
    Translators.include? self.id
  end

  # бот ли пользователь
  def bot?
    BotsService.posters.include? self.id
  end

  # пользователь, за которым не проверяем залитое виде?
  def trusted_video_uploaders?
    TrustedVideoUploaders.include? self.id
  end

  # last online time from memcached/or from database
  def last_online_at
    cached = Rails.cache.read(self.last_online_cache_key)
    cached = DateTime.parse(cached) if cached
    [cached, self[:last_online_at], self.current_sign_in_at].compact.max
  end

  # updates user's last online date
  def update_last_online
    now = DateTime.now
    if now - User::LAST_ONLINE_CACHE_INTERVAL > self.last_online_at.to_datetime || self[:last_online_at].nil?
      User.record_timestamps = false
      self.update_attribute(:last_online_at, now)
      User.record_timestamps = true
    else
      Rails.cache.write(self.last_online_cache_key, now.to_s) # wtf? Rails is crushed when it loads DateTime type from memcached
    end
  end

  def last_online_cache_key
    'user_%d_last_online' % self.id
  end

  def can_post?
    !read_only_at || !banned?
  end

  # может ли пользователь сейчас голосовать за указанный контест?
  def can_vote? contest
    contest.started? && self[contest.user_vote_key]
  end
  # может ли пользователь сейчас голосовать за первый турнир?
  def can_vote_1?
    can_vote_1
  end
  # может ли пользователь сейчас голосовать за второй турнир?
  def can_vote_2?
    can_vote_2
  end
  # может ли пользователь сейчас голосовать за третий турнир?
  def can_vote_3?
    can_vote_3
  end

  def favoured? entry, kind=nil
    @favs ||= favourites.to_a
    @favs.any? { |v| v.linked_id == entry.id && v.linked_type == entry.class.name && (kind.nil? || v.kind == kind) }
  end

  # колбек, который вызовет comments_controller при добавлении комментария в профиле пользователя
  def comment_added comment
    return if self.messages.where(kind: MessageType::ProfileCommented).
                            where(read: false).
                            count > 0
    return if comment.user_id == comment.commentable_id &&
              comment.commentable_type == User.name
    Message.create(
      to_id: id,
      from_id: comment.user_id,
      kind: MessageType::ProfileCommented
    )
  end

  # подписка на элемент
  def subscribe entry
    subscriptions << Subscription.create!(user_id: id, target_id: entry.id, target_type: entry.class.name) unless subscribed?(entry)
  end

  # отписка от элемента
  def unsubscribe entry
    subscriptions
      .select {|v| v.target_id == entry.id && v.target_type == entry.class.name }
      .each {|v| v.destroy }
  end

  # подписан ли пользователь на элемент?
  def subscribed? entry
    subscriptions.any? {|v| v.target_id == entry.id && v.target_type == entry.class.name }
  end

  def ignores? user
    cached_ignores.any? { |v| v.target_id == user.id }
  end

  # ключ для кеша по дате изменения пользователя
  def cache_key
    "#{self.id}_#{self.updated_at.to_i}"
  end

  # повесить пользователю такой же бан, что и другим с тем же ip
  def prolongate_ban
    read_only_at = User
        .where(current_sign_in_ip: current_sign_in_ip)
        .select {|v| v.read_only_at.present? && v.read_only_at > DateTime.now }
        .map {|v| v.read_only_at }
        .max

    update_column :read_only_at, read_only_at
  end

  def banned?
    !!(read_only_at && read_only_at > DateTime.now)
  end

  def remember_me
    true
  end

  def avatar_url size
    if avatar.exists?
      if CensoredIds.include?(id)
        "http://www.gravatar.com/avatar/%s?s=%i&d=identicon" % [Digest::MD5.hexdigest('takandar+censored@gmail.com'), size]
      else
        avatar.url "x#{size}".to_sym
      end
    else
      "http://www.gravatar.com/avatar/%s?s=%i&d=identicon" % [Digest::MD5.hexdigest(email.downcase), size]
    end
  end

private
  # создание первой записи в историю - о регистрации на сайте
  def create_history_entry
    history.create! action: UserHistoryAction::Registration
  end

  # запоминаем предыдущие никнеймы пользователя
  def log_nickname_change
    if changes.include?('nickname') && (created_at + 1.day) < DateTime.now && changes['nickname'][0] !~ /^Новый пользователь\d+/ && comments.count > 10
      nickname_changes.create! value: changes['nickname'][0]

      Message.wo_antispam do
        FriendLink.where(dst_id: id).includes(:src).each do |link|
          Message.create!(
            from_id: BotsService.get_poster.id,
            to_id: link.src.id,
            kind: MessageType::NicknameChanged,
            body: female? ?
              "Ваша подруга [profile=#{id}]#{changes['nickname'][0]}[/profile] изменила никнейм на [profile=#{id}]#{changes['nickname'][1]}[/profile]." :
              "Ваш друг [profile=#{id}]#{changes['nickname'][0]}[/profile] изменил никнейм на [profile=#{id}]#{changes['nickname'][1]}[/profile]."
          ) if link.src.notifications & User::NICKNAME_CHANGE_NOTIFICATIONS != 0
        end
      end
    end
  rescue ActiveRecord::RecordNotUnique
  end

  # зачистка никнейма от запрещённых символов
  def fix_nickname
    self.nickname = nickname
      .gsub(/[%&#\/\\?+\]\[:,]+/, '')
      .strip
      .gsub(/^\.$/, 'точка')
  end

  # создание послерегистрационного приветственного сообщения пользователю
  def send_welcome_message
    Message.create!(
      from_id: 1,
      to_id: self.id,
      kind: MessageType::Notification,
      body: "Добро пожаловать.
[url=http://shikimori.org/s/85018-FAQ-Chasto-zadavaemye-voprosy]Здесь[/url] находятся овтеты на наиболее часто задаваемые вопросы.
Импортировать список аниме и манги из [url=http://myanimelist.net]myanimelist.net[/url] или [url=http://anime-planet.com]anime-planet.com[/url] можно в [url=/#{to_param}/settings]настройках профиля[/url]. Там же можно изменить свой никнейм.
Перед постингом на форуме рекомендуем ознакомиться с [url=http://shikimori.org/s/79042-Pravila-sayta]правилами сайта[/url].

Если возникнут вопросы или пожелания - пишите, мы постараемся вам ответить."
    )
  end

  def twitter_client
    client = TwitterOAuth::Client.new(
      consumer_key: ::TWITTER_CONSUMER_KEY,
      consumer_secret: ::TWITTER_SECRET_KEY,
      token: user_tokens.twitter.token,
      secret: user_tokens.twitter.secret
    )
  end

  def truncated_message_with_url message="", url="", length=140
    if message.size + url.size > 140
      share = message[0..(136-url.size)] + "..." + url
    else
      share = message + " " + url
    end
    share
  end

  def cached_ignores
    @ignores ||= ignores
  end

  def self.find_by_nickname nickname
    self.where(nickname: nickname).select {|v| v.nickname == nickname }.first
  end

  def check_ban
    ProlongateBan.delay_for(10.seconds).perform_async id
  end
end
