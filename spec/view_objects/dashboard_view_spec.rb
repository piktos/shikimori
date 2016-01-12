describe DashboardView do
  include_context :view_object_warden_stub

  let(:user) { seed :user }
  let(:view) { DashboardView.new }

  describe '#ongoings' do
    let!(:anons) { create :anime, :anons }
    let!(:released) { create :anime, :released }
    let!(:ongoing_1) { create :anime, :ongoing, ranked: 10, score: 8 }
    let!(:ongoing_2) { create :anime, :ongoing, ranked: 5, score: 8 }
    let!(:ongoing_3) { create :anime, :ongoing, ranked: 5, score: 7 }

    it { expect(view.ongoings).to eq [ongoing_2, ongoing_1] }
  end

  describe '#db_seasons' do
    it { expect(view.db_seasons(Anime).first).to be_kind_of Titles::StatusTitle }
    it { expect(view.db_seasons(Anime).last).to be_kind_of Titles::SeasonTitle }
    it { expect(view.db_seasons(Anime)).to have(5).items }
  end

  describe '#manga_kinds' do
    it do
      expect(view.manga_kinds.first).to be_kind_of Titles::KindTitle
      expect(view.manga_kinds.map(&:text)).to eq %w(
        manga manhwa manhua novel one_shot doujin
      )
    end
  end

  describe '#db_others' do
    it { expect(view.db_others(Anime).first).to be_kind_of Titles::StatusTitle }
    it { expect(view.db_others(Anime).last).to be_kind_of Titles::SeasonTitle }
    it { expect(view.db_others(Anime)).to have(4).items }
  end

  describe '#reviews' do
    let!(:review) { create :review }
    it { expect(view.reviews).to have(1).item }
  end

  describe '#user_news' do
    let!(:news_topic) { create :news_topic, generated: false }
    it { expect(view.user_news).to have(1).item }
  end

  describe '#generated_news' do
    let!(:news_topic) { create :news_topic, generated: true }
    it { expect(view.generated_news).to have(1).item }
  end

  describe '#contests' do
    let!(:contest) { create :contest, :proposing }
    it { expect(view.contests).to have(1).item }
  end

  describe '#lists_counts' do
    it { expect(view.list_counts(:anime)).to have(6).items }
  end

  describe '#history' do
    let!(:user_history) { create :user_history, user: user, target: create(:anime) }
    it { expect(view.history).to have(1).item }
  end

  describe '#pages' do
    it { expect(view.pages).to have_at_least(5).items }
  end

  describe '#forums' do
    it { expect(view.forums).to have_at_least(2).items }
  end

  #describe 'favourites' do
    #let!(:user) { create :user, fav_animes: [anime_1] }
    #let!(:anime_1) { create :anime }
    #let!(:anime_2) { create :anime }

    #it { expect(view.favourites).to eq [anime_1] }
  #end
end
