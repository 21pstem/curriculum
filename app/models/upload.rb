
class Upload < BaseRec

  # LONG_HEADERS = [ "Area", "Component", "Outcome", "Indicator", "Grade band", "relevant KBE sectors (as determined from KBE spreadsheets)", "Explanation of how the indicator relates to KBE sector", "Closely related learning outcomes applicable to KBE sector", "Mathematics", "Geography", "Physics", "Biology", "ICT" ]
  # SHORT_HEADERS = [ :area, :component, :outcome, :indicator, :gradeBand, :relevantKbe, :sectorRelation, :chemistry, :mathematics, :geography, :physics, :biology, :computers]

  TO_SHORT_HASH = {
    :"en" => {
      :"row" => :row, # 0
      :"originalRow" => :"originalRow",
      :"area" => :area, # 1
      :"component" => :component, # 2
      :"outcome" => :outcome, # 3
      :"indicator" => :indicator, # 4
      :"gradeBand" => :gradeBand, # 5
      :"relevantKbe" => :relevantKbe, # 6
      :"sectorRelation" => :sectorRelation, # 7
      :"currentSubject" => :currentSubject, # 8
      :"chemistry" => :chemistry, # 8
      :"mathematics" => :mathematics, # 9
      :"geography" => :geography, # 10
      :"physics" => :physics, # 11
      :"biology" => :biology, # 12
      :"computers" => :computers, # 13
      :"bio_geo" => :bio_geo, # process this row with both biology and geology
      :"sheetID" => :row, # 0
      :"Area" => :area, # 1
      :"Component" => :component, # 2
      :"Outcome" => :outcome, # 3
      :"Indicator" => :indicator, # 4
      :"Grade band" => :gradeBand, # 5
      :"relevant KBE sectors (as determined from KBE spreadsheets)" => :relevantKbe, # 6
      :"Explanation of how the indicator relates to KBE sector" => :sectorRelation, # 7
      :"Closely related learning outcomes applicable to KBE sector" => :currentSubject, # 8
      :"Chemistry" => :chemistry, # 8
      :"Mathematics" => :mathematics, # 9
      :"Geography" => :geography, # 10
      :"Physics" => :physics, # 11
      :"Biology" => :biology, # 12
      :"ICT" => :computers # 13
    },
    :"bs" => {
      :"sheetID" => :row,
      :"Oblast" => :area,
      :"Komponenta" => :component,
      :"Ishod" => :outcome,
      :"Pokazatelj" => :indicator,
      :"Raspon" => :gradeBand,
      :"Relevantni sektori KBE" => :relevantKbe,
      :"Objašnjenje kako se indikator odnosi na KBE sektor" => :sectorRelation,
      :"Usko povezani ishodi učenja koji se odnose na KBE sektor:" => :currentSubject,
      :"Tijesno povezani ishodi uÄenja koji se odnose na KBE sektor:" => :currentSubject,
      :"Tijesno povezani ishodi učenja koji se odnose na KBE sektor:" => :currentSubject,
      :"Tijesno povezani ishodi učenja koji se odnose na KBE sector" => :currentSubject,
      :"Kemija" => :chemistry,
      :"Hemija" => :chemistry,
      :"Matematika" => :mathematics,
      :"Geografija" => :geography,
      :"Poznavanje društva, Priroda i društvo, Društvo, Geografija" => :geography,
      :"Moja okolina, Priroda i društvo" => :geography,
      :"Fizika" => :physics,
      :"Biologija" => :biology,
      :"IKT" => :computers,
      :"Informatika" => :computers
    },
    :"hr" => {
      :"sheetID" => :row,
      :"Oblast" => :area,
      :"Komponenta" => :component,
      :"Ishod" => :outcome,
      :"Pokazatelj" => :indicator,
      :"Raspon" => :gradeBand,
      :"Relevantni KBE sektori:" => :relevantKbe,
      :"Relevantni sektori KBE" => :relevantKbe,
      :"Objašnjenje kako se pokazatelji odnose prema KBE sektorima:" => :sectorRelation,
      :"Objašnjenje kako se indikator odnosi na KBE sektor" => :sectorRelation,
      :"Usko povezani ishodi učenja koji se odnose na KBE sektore:" => :currentSubject,
      :"Tijesno povezani ishodi učenja koji se odnose na KBE sektor" => :currentSubject,
      :"Kemija" => :chemistry,
      :"Matematika" => :mathematics,
      :"Geografija" => :geography,
      :"Moja okolina, Priroda i društvo" => :geography,
      :"Fizika" => :physics,
      :"Biologija" => :biology,
      :"IKT" => :computers,
      :"Informatika" => :computers
    },
    :"sr" =>{
      :"sheetID" => :row,
      :"Oblast" => :area,
      :"Komponenta" => :component,
      :"Ishod" => :outcome,
      :"Pokazatelj" => :indicator,
      :"Raspon" => :gradeBand,
      :"Релевантни сектори економије засноване на знању (ЕЗЗ)" => :relevantKbe,
      :"Рeлeвaнтни сектори економије засноване на знању (ЕЗЗ)" => :relevantKbe,
      :"Објашњење како се индикатор односи на секторе ЕЗЗ-а" => :sectorRelation,
      :"Тијесно повезани исходи учења који се односе на секторе ЕЗЗ-а" => :currentSubject,
      :"Oбjaшњeњe кaкo сe индикaтoр oднoси нa секторе ЕЗЗ-а" => :currentSubject,
      :"Хемија" => :chemistry,
      :"Хeмиja" => :chemistry,
      :"Математика" => :mathematics,
      :"Maтeмaтикa" => :mathematics,
      :"Географија" => :geography,
      :"Моја околина, Природа и друштво" => :geography,
      :"Физика" => :physics,
      :"Физикa" => :physics,
      :"Биологија" => :biology,
      :"ИКТ" => :computers,
      :"Информатика" => :computers
    }
  }
  SHORT_REQ = {
    :row => true,
    :area => true,
    :component => true,
    :outcome => true,
    :indicator => true,
    :gradeBand => true
  }

  TO_SUBJECT_CODE = {
    :currentSubject => '',
    :chemistry => 'Hem',
    :mathematics => 'Mat',
    :geography => 'Geo',
    :physics => 'Fiz',
    :biology => 'Bio',
    :computers => 'IT'
  }

  TO_SUBJECT_ID = {
    :currentSubject => 0,
    :chemistry => 4,
    :mathematics => 6,
    :geography => 3,
    :physics => 2,
    :biology => 1,
    :computers => 5
  }

  belongs_to :subject
  belongs_to :grade_band
  belongs_to :locale

  validates :subject, presence: true
  validates :grade_band, presence: true
  validates :locale, presence: true

  validates :status, presence: true, allow_blank: false

  scope :upload_listing, -> {
    order('subjects.code', 'grade_bands.code', 'locales.name')
    # where(active: true)
  }

  def self.get_short(locale, val, ix=0)
    # puts "locale: #{locale.inspect}"
    # puts "val: #{val.inspect}"
    locale_vals =  Upload::TO_SHORT_HASH[locale.to_sym]
    # puts "locale_vals: #{locale_vals.inspect}"
    # puts "locale_vals: #{locale_vals[val.to_sym]}"
    if !val.present?
      Rails.logger.debug("*** missing value")
      return ''
    elsif locale_vals[val.strip.to_sym].present?
      Rails.logger.debug("*** found value #{val}")
      return locale_vals[val.strip.to_sym]
    elsif ix == 8
      Rails.logger.debug("*** column 8 is currentSubject")
      return :currentSubject
    elsif val.include?('Geografija')
      Rails.logger.debug("*** matched Geography")
      return :geography
    elsif val.include?('друштво')
      Rails.logger.debug("*** matched Geography")
      return :geography
    elsif val.include?('Гeoгрaфиja')
      Rails.logger.debug("*** matched Geography")
      return :geography
    elsif val.include?('društvo')
      Rails.logger.debug("*** matched Geography")
      return :geography
    elsif val.include?('Informatika')
      Rails.logger.debug("*** matched Computers")
      return :computers
    elsif val.include?('Информатика')
      Rails.logger.debug("*** matched Computers")
      return :computers
    elsif val.include?('информатикa')
      Rails.logger.debug("*** matched Computers")
      return :computers
    elsif val.include?('Biologija')
      Rails.logger.debug("*** matched biology")
      return :biology
    elsif val.include?('Биологија')
      Rails.logger.debug("*** matched biology")
      return :biology
    elsif val.include?('Објашњење')
      Rails.logger.debug("*** matched sectorRelation")
      return :sectorRelation
    elsif val.include?('Релевантнисекториекономије')
      Rails.logger.debug("*** matched sectorRelation")
      return :relevantKbe
    else
      Rails.logger.debug("*** no matching at all for  #{val}")
      return ''
    end
  end

  # def self.reverse_hash
  #   return Hash[LONG_TO_SHORT_HASH.to_a.reverse]
  # end

  # def self.get_long(locale, val)
  #   to_long = self.reverse_hash(TO_SHORT_HASH[locale])
  #   return to_long[val]
  # end

end

