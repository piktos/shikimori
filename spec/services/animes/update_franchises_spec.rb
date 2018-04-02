describe Animes::UpdateFranchises do
  subject(:call) { described_class.call }

  context 'no chronology' do
    let!(:anime) { create :anime, name: 'test: qweyt', franchise: 'zxc' }
    before { call }
    it { expect(anime.reload.franchise).to be_nil }
  end

  context 'has chronology' do
    let!(:anime_1) { create :anime, name: 'test: qweyt' }
    let!(:anime_2) { create :anime, name: 'testá fo' }
    let!(:anime_3) { create :anime, name: 'fofofo' }

    let!(:relation_12) { create :related_anime, source: anime_1, anime: anime_2 }
    let!(:relation_21) { create :related_anime, source: anime_2, anime: anime_1 }
    let!(:relation_23) { create :related_anime, source: anime_2, anime: anime_3 }
    let!(:relation_32) { create :related_anime, source: anime_3, anime: anime_2 }

    before { call }

    it do
      expect(anime_1.reload.franchise).to eq 'test'
      expect(anime_2.reload.franchise).to eq 'test'
      expect(anime_3.reload.franchise).to eq 'test'
    end
  end
end