describe NameMatcher do
  let(:service) { NameMatcher.new Anime }

  describe '#match' do
    describe 'single match' do
      let!(:anime) { create :anime, :tv, name: 'My anime', synonyms: ['My little anime', 'My : little anime', 'My Little Anime', 'MyAnim'] }

      it { expect(service.matches(anime.name)).to eq [anime] }
      it { expect(service.matches("#{anime.synonyms.last}!")).to eq [anime] }
      it { expect(service.matches("#{anime.name} TV")).to eq [anime] }
      it { expect(service.matches(anime.synonyms.first)).to eq [anime] }
      it { expect(service.matches("#{anime.synonyms.first} TV")).to eq [anime] }
      it { expect(service.matches("#{anime.synonyms.first}, with comma")).to eq [anime] }
    end

    describe '"&" with "and"' do
      subject { service.matches 'test and test' }
      let!(:anime) { create :anime, :tv, name: 'test & test' }
      it { is_expected.to eq [anime] }
    end

    describe '"and" with "&"' do
      subject { service.matches 'test and test' }
      let!(:anime) { create :anime, :tv, name: 'test and test' }
      it { is_expected.to eq [anime] }
    end

    describe '"S3" with "Season 3"' do
      subject { service.matches 'Anime S3' }
      let!(:anime) { create :anime, :tv, name: 'Anime Season 3' }
      it { is_expected.to eq [anime] }
    end

    describe '"The anime" with "anime"' do
      subject { service.matches 'The anime' }
      let!(:anime) { create :anime, :tv, name: 'anime' }
      it { is_expected.to eq [anime] }
    end

    describe '"anime" with "The anime"' do
      subject { service.matches 'anime' }
      let!(:anime) { create :anime, :tv, name: 'The anime' }
      it { is_expected.to eq [anime] }
    end

    describe '"Season 3" with "S3"' do
      let!(:anime) { create :anime, :tv, name: 'Anime S3' }
      it { expect(service.match("Anime Season 3")).to eq anime }
    end

    describe 'Madoka' do
      subject { service.matches 'Mahou Shoujo Madoka Magica' }
      let!(:anime) { create :anime, :tv, name: 'Mahou Shoujo Madoka★Magika', synonyms: ['Mahou Shoujo Madoka Magika'] }
      it { is_expected.to eq [anime] }
    end

    describe 'downcase' do
      subject { service.matches 'mahou shoujo madoka magica' }
      let!(:anime) { create :anime, :tv, name: 'Mahou Shoujo Madoka★Magika', synonyms: ['Mahou Shoujo Madoka Magika'] }
      it { is_expected.to eq [anime] }
    end

    describe 'does not prefer anything' do
      subject { service.matches anime2.name }
      let!(:anime1) { create :anime, :tv, name: 'test' }
      let!(:anime2) { create :anime, :movie, name: anime1.name }

      it { is_expected.to eq [anime1, anime2] }
    end

    describe '2nd season' do
      subject { service.matches 'Kingdom 2' }
      let!(:anime) { create :anime, :tv, name: 'Kingdom 2nd Season' }
      it { is_expected.to eq [anime] }
    end

    describe 'more 2nd season' do
      subject { service.matches 'Major 2nd Season' }
      let!(:anime) { create :anime, :tv, name: 'Major S2' }
      it { is_expected.to eq [anime] }
    end

    describe '3rd season' do
      subject { service.matches 'Kingdom 3' }
      let!(:anime) { create :anime, :tv, name: 'Kingdom 3rd Season' }
      it { is_expected.to eq [anime] }
    end

    describe '4th season' do
      subject { service.matches 'Kingdom 4' }
      let!(:anime) { create :anime, :tv, name: 'Kingdom 4th Season' }
      it { is_expected.to eq [anime] }
    end

    describe 'reversed 2nd season' do
      subject { service.matches 'Kingdom 2nd Season' }
      let!(:anime) { create :anime, :tv, name: 'Kingdom 2' }
      it { is_expected.to eq [anime] }
    end

    describe 'series' do
      subject { service.matches 'Kigeki [Sweat Punch Series]' }
      let!(:anime) { create :anime, :tv, name: 'Sweat Punch' }
      it { is_expected.to eq [anime] }
    end

    describe 'long lines in brackets' do
      subject { service.matches 'My youth romantic comedy is wrong as I expected. (Yahari ore no seishun rabukome wa machigatte iru.)' }
      let!(:anime) { create :anime, :tv, name: 'Yahari Ore no Seishun Love Come wa Machigatteiru.', english: ["My youth romantic comedy is wrong as I expected."] }
      it { is_expected.to eq [anime] }
    end

    describe 'without [ТВ-N]' do
      subject { service.matches 'Hayate no Gotoku! Cuties [ТВ- 4]' }
      let!(:anime) { create :anime, :tv, name: 'Hayate no Gotoku! Cuties' }
      it { is_expected.to eq [anime] }
    end

    describe 'without ТВ-N' do
      subject { service.matches 'Buzzer Beater ТВ-1' }
      let!(:anime) { create :anime, :tv, name: 'Buzzer Beater' }
      it { is_expected.to eq [anime] }
    end

    describe 'without TV' do
      subject { service.matches 'Tenchi Universe' }
      let!(:anime) { create :anime, :tv, name: 'Tenchi Universe TV' }
      it { is_expected.to eq [anime] }
    end

    describe 'without [OVA-N]' do
      subject { service.matches 'JoJo no na Bouken [OVA-2]' }
      let!(:anime) { create :anime, :tv, name: 'JoJo no na Bouken' }
      it { is_expected.to eq [anime] }
    end

    describe 'without year' do
      subject { service.matches 'JoJo no Kimyou na Bouken' }
      let!(:anime) { create :anime, :tv, name: 'JoJo no Kimyou na Bouken (2000)' }
      it { is_expected.to eq [anime] }
    end

    describe 'with year' do
      subject { service.matches 'JoJo no Kimyou na Bouken (2014)' }
      let!(:anime) { create :anime, :tv, name: 'JoJo no Kimyou na Bouken', aired_on: '2014-05-05' }
      it { is_expected.to eq [anime] }
    end

    describe 'with year #2' do
      subject { service.matches 'Fairy Tail (2014)' }
      let!(:anime) { create :anime, :tv, name: 'Fairy Tail (2014)' }
      let!(:anime_2) { create :anime, :tv, name: 'Fairy Tail' }
      it { is_expected.to eq [anime] }
    end

    describe 'with year at end' do
      subject { service.matches 'The Genius Bakabon 1975' }
      let!(:anime) { create :anime, :tv, name: 'The Genius Bakabon', aired_on: DateTime.parse('1975-01-01') }
      it { is_expected.to eq [anime] }
    end

    describe 'short lines in brackets' do
      subject { service.matches 'Cyborg009 (1968ver.)' }
      let!(:anime) { create :anime, :tv, name: 'Cyborg 009' }
      it { is_expected.to eq [anime] }
    end

    describe 'reversed words' do
      subject { service.matches 'Lain - Serial Experiments' }
      let!(:anime) { create :anime, :tv, name: 'Serial Experiments Lain' }
      it { is_expected.to eq [anime] }
    end

    describe 'without brackets' do
      subject { service.matches 'HUNTER x HUNTER 2011' }
      let!(:anime) { create :anime, :tv, name: 'Hunter x Hunter (2011)' }
      it { is_expected.to eq [anime] }
    end

    describe '/' do
      subject { service.matches 'Fate Zero' }
      let!(:anime) { create :anime, :tv, name: 'Fate/Zero' }
      it { is_expected.to eq [anime] }
    end

    describe '!' do
      subject { service.matches 'Upotte' }
      let!(:anime) { create :anime, :tv, name: 'Upotte!!' }
      it { is_expected.to eq [anime] }
    end

    describe '! #2' do
      subject { service.matches 'WORKING!!!' }
      let!(:anime) { create :anime, :tv, name: 'Working!!!' }
      let!(:anime_2) { create :anime, :tv, name: 'Working!!' }
      it { is_expected.to eq [anime] }
    end

    describe '"' do
      subject { service.matches 'Boku no Imouto wa Osaka Okan' }
      let!(:anime) { create :anime, :tv, name: 'Boku no Imouto wa "Osaka Okan": Haishin Gentei Osaka Okan.' }
      it { is_expected.to eq [anime] }
    end

    describe 'russian with !' do
      subject { service.matches 'Гинтама: Финальная арка: Йорозуя навсегда' }
      let!(:anime) { create :anime, :tv, russian: 'Гинтама: Финальная арка: Йорозуя навсегда!' }
      it { is_expected.to eq [anime] }
    end

    describe '～' do
      subject { service.matches 'Little Busters～Refrain～' }
      let!(:anime) { create :anime, :tv, name: 'Little Busters!: Refrain' }
      it { is_expected.to eq [anime] }
    end

    describe 'space delimiter' do
      subject { service.matches 'Kyousougig' }
      let!(:anime) { create :anime, :tv, name: 'Kyousou Gig (TV)' }
      it { is_expected.to eq [anime] }
    end

    describe 'russian' do
      subject { service.matches 'Раз героем мне не стать - самое время работу искать!' }
      let!(:anime) { create :anime, :tv, russian: 'Раз героем мне не стать - самое время работу искать!' }
      it { is_expected.to eq [anime] }
    end

    describe 'the animation' do
      subject { service.matches 'Baton The Animation' }
      let!(:anime) { create :anime, :tv, name: 'Baton' }
      it { is_expected.to eq [anime] }
    end

    describe '"s" as "sh"' do
      subject { service.matches 'YuShibu' }
      let!(:anime) { create :anime, :tv, name: 'Yusibu' }
      it { is_expected.to eq [anime] }
    end

    describe '"ō" as "o"' do
      subject { service.matches 'shōjo' }
      let!(:anime) { create :anime, :tv, name: 'shojo' }
      it { is_expected.to eq [anime] }
    end

    describe '"ß" as "ss"' do
      subject { service.matches 'Weiss Kreuz Gluhen' }
      let!(:anime) { create :anime, :tv, name: 'Weiß Kreuz Gluhen' }
      it { is_expected.to eq [anime] }
    end

    describe '"ü" as "u"' do
      subject { service.matches 'Weiss Kreuz Gluhen' }
      let!(:anime) { create :anime, :tv, name: 'Weiss Kreuz Glühen' }
      it { is_expected.to eq [anime] }
    end

    describe '"ū" as "u"' do
      subject { service.matches 'Weiss Kreuz Gluhen' }
      let!(:anime) { create :anime, :tv, name: 'Weiss Kreuz Glūhen' }
      it { is_expected.to eq [anime] }
    end

    describe '"o" as "h"' do
      subject { service.matches "Yuu-Gi-Ou! 5D's" }
      let!(:anime) { create :anime, :tv, name: "Yu-Gi-Oh! 5D's" }
      it { is_expected.to eq [anime] }
    end
    describe '"u" as "uu"' do
      subject { service.matches 'Kyuu' }
      let!(:anime) { create :anime, :tv, name: 'Kyu' }
      it { is_expected.to eq [anime] }
    end

    describe '" o " as " wo "' do
      subject { service.matches 'Papa no Iukoto o Kikinasai! OVA' }
      let!(:anime) { create :anime, :tv, name: 'Papa no Iukoto wo Kikinasai! OVA' }
      it { is_expected.to eq [anime] }
    end

    describe 'heroine -> kanojo ' do
      subject { service.matches 'Saenai Heroine no Sodatekata' }
      let!(:anime) { create :anime, :tv, name: 'Saenai Kanojo no Sodate-kata' }
      it { is_expected.to eq [anime] }
    end

    describe '"o" as "ou"' do
      subject { service.matches 'Rouaaaa' }
      let!(:anime) { create :anime, :tv, name: 'Roaaaa' }
      it { is_expected.to eq [anime] }
    end

    describe '"o" as "ou" #2' do
      subject { service.matches 'Monster Musume no Iru Nichijō' }
      let!(:anime) { create :anime, :tv, name: 'Monster Musume no Iru Nichijou' }
      it { is_expected.to eq [anime] }
      #it { .times { service.matches 'Monster Musume no Iru Nichijō' } }
    end

    describe '"o" as "ou" #3' do
      subject { service.matches 'Kūsen Madōshi Kōhosei no Kyōkan' }
      let!(:anime) { create :anime, :tv, name: 'Kuusen Madoushi Kouhosei no Kyoukan' }
      it { is_expected.to eq [anime] }
    end

    describe '"Plus" as "+"' do
      subject { service.matches 'Amagami SS Plus' }
      let!(:anime) { create :anime, :tv, name: 'Amagami SS+' }
      it { is_expected.to eq [anime] }
    end

    describe '"special" as "specials"' do
      subject { service.matches 'Suisei no Gargantia Special' }
      let!(:anime) { create :anime, :tv, name: 'Suisei no Gargantia Specials' }
      it { is_expected.to eq [anime] }
    end

    describe '"II" as "2"' do
      subject { service.matches 'Sekai-ichi Hatsukoi II' }
      let!(:anime) { create :anime, :tv, name: 'Sekai-ichi Hatsukoi 2' }
      it { is_expected.to eq [anime] }
    end

    describe '"I" as nothing' do
      subject { service.matches 'Sekai-ichi Hatsukoi I' }
      let!(:anime) { create :anime, :tv, name: 'Sekai-ichi Hatsukoi' }
      it { is_expected.to eq [anime] }
    end

    describe 'multiple replacements' do
      subject { service.matches 'Rou Kyuu Bu! SS' }
      let!(:anime) { create :anime, :tv, name: 'Ro-Kyu-Bu! SS' }
      it { is_expected.to eq [anime] }
    end

    describe 'multiple replacements #2' do
      subject { service.matches 'Tamagotchi! Tama Tomo Daishū GO!' }
      let!(:anime) { create :anime, :tv, name: 'Tamagotchi! Tamatomo Daishuu GO' }
      it { is_expected.to eq [anime] }
    end

    describe 'alternative names from config' do
      subject { service.matches 'Охотник х Охотник [ТВ -2]' }
      let!(:anime) { create :anime, :tv, id: 11061 }
      it { is_expected.to eq [anime] }
    end

    describe 'nosplit variants are checked first' do
      subject { service.matches 'Black Jack: Heian Sento' }
      let!(:anime) { create :anime, name: 'Black Jack: Heian Sento' }
      let!(:anime2) { create :anime, name: 'Black Jack' }
      it { is_expected.to eq [anime] }
    end
  end

  describe 'matches' do
    describe 'common_case' do
      subject { service.matches anime2.name, year: 2001 }
      let!(:anime1) { create :anime, :tv, aired_on: DateTime.parse('2001-01-01'), name: 'test' }
      let!(:anime2) { create :anime, :movie, name: anime1.name }
      let!(:anime3) { create :anime, aired_on: DateTime.parse('2001-01-01'), name: anime1.name }

      it { is_expected.to eq [anime1, anime3] }
    end

    describe 'only_one_match' do
      subject { service.matches anime1.name, year: 2001 }
      let!(:anime1) { create :anime, name: 'Yowamushi Pedal' }
      let!(:anime2) { create :anime, name: 'Yowamushi Pedal: Special Ride' }

      it { is_expected.to eq [anime1] }
    end
  end

  describe 'fetch' do
    subject { service.fetch 'The Genius' }
    let!(:anime1) { create :anime, :tv, name: 'The Genius Bakabon' }
    let!(:anime2) { create :anime, :tv, name: 'zzz' }

    it { is_expected.to eq anime1 }
  end

  describe 'by_link' do
    subject { service.by_link link.identifier, :findanime }
    let(:service) { NameMatcher.new Anime, nil, [:findanime] }
    let!(:anime) { create :anime }
    let!(:link) { create :anime_link, service: :findanime, identifier: 'zxcvbn', anime: anime }

    it { is_expected.to eq anime }
  end
end
