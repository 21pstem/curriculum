# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

# create an initial admin user to get things going.
# to do - turn off admin flag for production.
if User.count < 1
  User.create(
    email: 'bih@sample.com',
    password: 'password',
    password_confirmation: 'password',
    given_name: 'BiH',
    family_name: 'Web App',
    roles: 'admin',
    govt_level: "1",
    govt_level_name: "govt_level_name",
    municipality: "municipality",
    institute_type: "1",
    institute_name_loc: "institute_name_loc",
    position_type: "1",
    subject1: "subject1",
    subject2: "subject2",
    gender: "2",
    education_level: "1",
    work_phone: "work_phone",
    work_address: "work_address",
    terms_accepted: true,
    confirmed_at: DateTime.now
  )
end
throw "Invalid User Count" if User.count < 1
@bih = User.where(email: 'bih@sample.com').first

########################################################################
# Note: the code below is copied to test/helpers/seeds_testing_helper.rb

if Version.count < 1
  Version.create(
    code: 'v01'
  )
end
throw "Invalid Version Count" if Version.count > 1
@v01 = Version.last

if TreeType.count < 1
  TreeType.create(
    code: 'OTC'
  )
end
throw "Invalid TreeType Count" if TreeType.count > 1
@otc = TreeType.last

if Locale.count < 1
  Locale.create(
    code: 'bs',
    name: 'bosanski'
  )
  Locale.create(
    code: 'hr',
    name: 'hrvatski'
  )
  Locale.create(
    code: 'sr',
    name: 'српски'
  )
  loc_en = Locale.create(
    code: 'en',
    name: 'English'
  )
end
throw "Invalid Locale Count" if Locale.count != 4
@loc_bs = Locale.first
@loc_hr = Locale.second
@loc_sr = Locale.third
@loc_en = Locale.fourth

if GradeBand.count < 4
  GradeBand.create(
    tree_type_id: @otc.id,
    code: '3'
  )
  GradeBand.create(
    tree_type_id: @otc.id,
    code: '6'
  )
  GradeBand.create(
    tree_type_id: @otc.id,
    code: '9'
  )
  GradeBand.create(
    tree_type_id: @otc.id,
    code: '13'
  )
end

throw "Invalid GradeBand Count" if GradeBand.count != 4
@gb_03 = GradeBand.first
@gb_06 = GradeBand.second
@gb_09 = GradeBand.third
@gb_13 = GradeBand.fourth
@grade_bands = GradeBand.all

if Subject.count != 6
  Subject.create(
    tree_type_id: @otc.id,
    code: 'Bio'
  )
  Subject.create(
    tree_type_id: @otc.id,
    code: 'Fiz'
  )
  Subject.create(
    tree_type_id: @otc.id,
    code: 'Geo'
  )
  Subject.create(
    tree_type_id: @otc.id,
    code: 'Hem'
  )
  Subject.create(
    tree_type_id: @otc.id,
    code: 'IT'
  )
  Subject.create(
    tree_type_id: @otc.id,
    code: 'Mat'
  )
end
throw "Invalid Subject Count" if Subject.count != 6
@bio = Subject.first
@fiz = Subject.second
@geo = Subject.third
@hem = Subject.fourth
@it = Subject.fifth
@mat = Subject.last
@subjects = Subject.all


if Upload.count != 80
  @subjects.each do |s|
    @grade_bands.each do |gb|
      # don't create grades 3 and 6 for Hem (Chemistry) and Fiz (Physics)
      if (
          !['Hem', 'Fiz'].include?(s.code) ||
          !['3', '6'].include?(gb.code)
        )
        Upload.create(
          subject_id: s.id,
          grade_band_id: gb.id,
          locale_id: @loc_bs.id,
          status: 0,
          filename: "#{s.code}_#{gb.code}_bs.csv"
        )
        Upload.create(
          subject_id: s.id,
          grade_band_id: gb.id,
          locale_id: @loc_hr.id,
          status: 0,
          filename: "#{s.code}_#{gb.code}_hr.csv"
        )
        Upload.create(
          subject_id: s.id,
          grade_band_id: gb.id,
          locale_id: @loc_sr.id,
          status: 0,
          filename: "#{s.code}_#{gb.code}_sr.csv"
        )
        Upload.create(
          subject_id: s.id,
          grade_band_id: gb.id,
          locale_id: @loc_en.id,
          status: 0,
          filename: "#{s.code}_#{gb.code}_en.csv"
        )
      end
    end
  end
  # Upload.create(
  #   subject_id: @hem.id,
  #   grade_band_id: @gb_09.id,
  #   locale_id: @loc_en.id,
  #   status: 0,
  #   filename: 'Hem_9_en.csv'
  # )
  # Upload.create(
  #   subject_id: @hem.id,
  #   grade_band_id: @gb_13.id,
  #   locale_id: @loc_en.id,
  #   status: 0,
  #   filename: 'Hem_13_en.csv'
  # )
  # Upload.create(
  #   subject_id: @mat.id,
  #   grade_band_id: @gb_03.id,
  #   locale_id: @loc_en.id,
  #   status: 0,
  #   filename: 'mat_3_en.csv'
  # )
end
# valid count:
#   96 (4 grade bands * 6 subjects * 4 languages)
#   - 16 physics and chemistry for grades 3 and 6 for 4 languages
#   = 80 valid uploads
throw "Invalid Upload Count" if Upload.count != 80
@hem_09 = Upload.where(filename: 'Hem_9_en.csv').first
@hem_13 = Upload.where(filename: 'Hem_13_en.csv').first
@bio_03 = Upload.where(filename: 'Bio_3_bs.csv').first




################################
# Populate the Sector table and its translations for all four languages
if Sector.count > 0 && Sector.count != 10
  throw "Invalid KBE Sector count #{Sector.count}"
elsif Sector.count == 10
  # puts "Sectors entered already!"
  # entered already
else
  Sector.create(code: '1', name_key: 'sector.1.name', base_key: 'sector.1')
  Sector.create(code: '2', name_key: 'sector.2.name', base_key: 'sector.2')
  Sector.create(code: '3', name_key: 'sector.3.name', base_key: 'sector.3')
  Sector.create(code: '4', name_key: 'sector.4.name', base_key: 'sector.4')
  Sector.create(code: '5', name_key: 'sector.5.name', base_key: 'sector.5')
  Sector.create(code: '6', name_key: 'sector.6.name', base_key: 'sector.6')
  Sector.create(code: '7', name_key: 'sector.7.name', base_key: 'sector.7')
  Sector.create(code: '8', name_key: 'sector.8.name', base_key: 'sector.8')
  Sector.create(code: '9', name_key: 'sector.9.name', base_key: 'sector.9')
  Sector.create(code: '10', name_key: 'sector.10.name', base_key: 'sector.10')
end
throw "Invalid Sector Count" if Sector.count != 10
@sector1 = Sector.where(name_key: 'sector.1.name').first
@sector2 = Sector.where(name_key: 'sector.2.name').first
@sector3 = Sector.where(name_key: 'sector.3.name').first
@sector4 = Sector.where(name_key: 'sector.4.name').first
@sector5 = Sector.where(name_key: 'sector.5.name').first
@sector6 = Sector.where(name_key: 'sector.6.name').first
@sector7 = Sector.where(name_key: 'sector.7.name').first
@sector8 = Sector.where(name_key: 'sector.8.name').first
@sector9 = Sector.where(name_key: 'sector.9.name').first
@sector10 = Sector.where(name_key: 'sector.10.name').first

rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_BS, 'sector.1.name', 'Informaciono-komunikacijske tehnologije (IKT)')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_BS, 'sector.2.name', 'Zdravstvo')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_BS, 'sector.3.name', 'Tehnologija materijala i visokotehnološka proizvodnja')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_BS, 'sector.4.name', 'Proizvodnja energije, prenos, efikasnost')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_BS, 'sector.5.name', 'Finansije i biznis')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_BS, 'sector.6.name', 'Umjetnost, zabava i mediji')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_BS, 'sector.7.name', 'Sport ')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_BS, 'sector.8.name', 'Turizam')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_BS, 'sector.9.name', 'Poduzetništvo')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_BS, 'sector.10.name', 'Savremena poljoprivredna proizvodnja')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR

rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_HR, 'sector.1.name', 'Informacijske i komunikacijske tehnologije (IKT)')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_HR, 'sector.2.name', 'Zdravstvo')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_HR, 'sector.3.name', 'Tehnologija materijala i visokotehnološka proizvodnja')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_HR, 'sector.4.name', 'Proizvodnja energije, prijenos, učinkovitost')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_HR, 'sector.5.name', 'Financije i poslovanje')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_HR, 'sector.6.name', 'Umjetnost, zabava i mediji')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_HR, 'sector.7.name', 'Sport')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_HR, 'sector.8.name', 'Turizam')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_HR, 'sector.9.name', 'Poduzetništvo')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_HR, 'sector.10.name', 'Suvremena poljoprivredna proizvodnja')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR

rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_SR, 'sector.1.name', 'Инфoрмaтичко-кoмуникaциoнe тeхнoлoгиje (ИКТ)')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_SR, 'sector.2.name', 'Здрaвствo')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_SR, 'sector.3.name', 'Teхнoлoгиja мaтeриjaлa и висoкoтeхнoлoшкa прoизвoдњa')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_SR, 'sector.4.name', 'Прoизвoдњa eнeргиje, прeнoс, eфикaснoст')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_SR, 'sector.5.name', 'Финaнсиje и бизнис')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_SR, 'sector.6.name', 'Умjeтнoст, зaбaвa и мeдиjи')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_SR, 'sector.7.name', 'Спoрт')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_SR, 'sector.8.name', 'Tуризaм')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_SR, 'sector.9.name', 'Предузетништво')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_SR, 'sector.10.name', 'Сaврeмeнa пoљoприврeднa прoизвoдњa')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR

rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_EN, 'sector.1.name', 'Information Communication Technology (ICT)')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_EN, 'sector.2.name', 'Health')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_EN, 'sector.3.name', 'Technology of materials and high-tech production')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_EN, 'sector.4.name', 'Energy production, transmission, efficiency')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_EN, 'sector.5.name', 'Finance and business')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_EN, 'sector.6.name', 'Art, entertainment and media')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_EN, 'sector.7.name', 'Sport')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_EN, 'sector.8.name', 'Tourism')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_EN, 'sector.9.name', 'Entrepreneurship')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
rec, status, message = Translation.find_or_update_translation(BaseRec::LOCALE_EN, 'sector.10.name', 'Contemporary agricultural production')
throw "ERROR updating sector translation: #{message}" if status == BaseRec::REC_ERROR
