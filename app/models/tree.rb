class Tree < BaseRec

  # Note: Found english version of letters mixed in with cryllic
  # mapped english version of cyrillic letters to match the corresponding english letter so both versions of the letter would map out properly to the english
  # then mapped cyrillic letters, so english to cyrillic would return cryllic
  # INDICATOR_SEQ_ENG = ['a','e','j','k','a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','c']
  # INDICATOR_SEQ_CYR = ['a','e','j','k','а','б','в','г','д','ђ','е','ж','з','и','ј','к','л','љ','м','н','ц']
  INDICATOR_SEQ_ENG = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p']
  INDICATOR_SEQ_CYR = ['а', 'б', 'ц', 'д', 'е', 'ф', 'г', 'х', 'и', 'ј', 'к', 'л', 'м', 'н', 'о', 'п']
  # hash to return english letter for cyrillic letter
  GET_ENG_IND_H = INDICATOR_SEQ_CYR.zip(INDICATOR_SEQ_ENG).to_h
  # hash to return cyrillic letter for english letter
  GET_CYR_IND_H = INDICATOR_SEQ_ENG.zip(INDICATOR_SEQ_CYR).to_h


  belongs_to :tree_type
  belongs_to :version
  belongs_to :subject
  belongs_to :grade_band

  has_and_belongs_to_many :sectors
  # has_and_belongs_to_many :related_trees, class_name: "Tree", join_table: "related_trees_trees"
  has_and_belongs_to_many(:related_trees,
    :class_name => "Tree",
    :join_table => "related_trees_trees",
    :foreign_key => "tree_id",
    :association_foreign_key => "related_tree_id")

  # does not seem to be working ?
  # has_many :my_translations

  # are these necessary?
  validates :tree_type, presence: true
  validates :version, presence: true
  validates :subject, presence: true
  validates :grade_band, presence: true

  validates :code, presence: true, allow_blank: false

  # removed for testing issues.  set values in controller
  # # scope for hard coded variables
  # scope :otc_tree, -> {
  #   where(tree_type_id: TREE_TYPE_ID, version_id: VERSION_ID)
  # }
  scope :otc_listing, -> {
    order('subjects.code', 'grade_bands.code', 'locales.name')
    # where(active: true)
  }

  def code_by_ix(ix)
    if depth == 3
      if self.matching_codes.length > ix
        mcs = JSON.load(matching_codes)
        return mcs[ix]
      end
    end
    return code
  end


  def codeArray
    if self.code.present?
      return self.code.split('.')
    else
      return nil
    end
  end

  # return the last code in the code string (return c from a.b.c)
  def subCode
    if self.code.present?
      return self.codeArray[-1]
    else
      return nil
    end
  end

  def parentCode
    arr = self.codeArray
    if arr && arr.length > 0
      arr.pop(1)
      return arr.join('.')
    else
      return ''
    end
  end

  def area
    return self.codeArray[0]
  end

  def component
    if self.depth.present? && self.depth > 0
      return self.codeArray[1]
    else
      return nil
    end
  end

  def outcome
    if self.depth.present? && self.depth > 1
      return self.codeArray[2]
    else
      return nil
    end
  end

  def indicator
    if self.depth.present? && self.depth > 2
      return self.codeArray[3]
    else
      return nil
    end
  end

  def self.engIndicatorLetter(letter)
    if Tree.validCyrIndicatorLetter?(letter)
      return GET_ENG_IND_H[letter]
    else
      return "#{letter}(#{letter.bytes})-INVALID"
    end
  end

  def self.validCyrIndicatorLetter?(letter)
    if INDICATOR_SEQ_CYR.include?(letter)
      return true
    else
      return false
    end
  end

  # return the indicator letter by locale (translating SR to latin equivalent)
  #  (indicators have a simple mapping from english abcde... to абвгдђ...)
  def self.indicatorLetterByLocale(locale, letter)
    if locale == BaseRec::LOCALE_SR
      return Tree.engIndicatorLetter(letter)
    else
      if INDICATOR_SEQ_ENG.include?(letter)
        return letter
      else
        return "#{letter}(#{letter.bytes})-INVALID"
      end
    end
  end

  def self.cyrIndicatorCode(codeIn)
    # indicator code letter is in english - map to cyrillic
    codeArray = codeIn.split('.')
    if codeArray.length > 3
      indicLetter = codeArray[3]
      if INDICATOR_SEQ_ENG.include?(indicLetter)
        codeArray[3] = GET_CYR_IND_H[indicLetter]
        return codeArray.join('.')
      end
    end
  end

  def codeByLocale(locale, ix=0)
    retCode = code_by_ix(ix)
    if locale == BaseRec::LOCALE_SR
      return Tree.cyrIndicatorCode(code)
    else
      return retCode
    end
  end

  def self.buildNameKey(treeTypeRec, versionRec, subjectRec, gradeBandRec, fullCode)
    return "#{treeTypeRec.code}.#{versionRec.code}.#{subjectRec.code}.#{gradeBandRec.code}.#{fullCode}.name"
  end
  def buildNameKey
    return "#{self.tree_type.code}.#{self.version.code}.#{self.subject.code}.#{self.grade_band.code}.#{self.code}.name"
  end

  def self.buildBaseKey(treeTypeRec, versionRec, subjectRec, gradeBandRec, fullCode)
    return "#{treeTypeRec.code}.#{versionRec.code}.#{subjectRec.code}.#{gradeBandRec.code}.#{fullCode}"
  end
  def buildBaseKey
    return "#{self.tree_type.code}.#{self.version.code}.#{self.subject.code}.#{self.grade_band.code}.#{self.code}"
  end

  def buildRootKey
    return "#{self.tree_type.code}.#{self.version.code}.#{self.subject.code}.#{self.grade_band.code}"
  end

  # get parent record for this item (by hierarchy code as appropriate)
  def getParentRec
    outcomes = Tree.where(
      tree_type_id: self.tree_type_id,
      version_id: self.version_id,
      subject_id: self.subject_id,
      grade_band_id: self.grade_band_id,
      code: self.parentCode
    )

    if outcomes.count == 0
      return nil
    else
      return outcomes.first
    end
  end

  # get all parent records for this item as appropriate (e.g. Area, Componrnt, and Outcome for indicator record)
  def getAllParents
    parents = []
    parent = self.getParentRec
    while parent.present? do
      parents << parent
      parent = parent.getParentRec
    end
    return parents
  end

  # get all translation name keys needed for this record and parents (Area, Component and Outcome)
  def getAllTransNameKeys
    parents = self.getAllParents
    allRecs = parents.concat([self])
    treeKeys = (allRecs).map { |rec| rec.name_key}
  end


  # Tree.find_or_add_code_in_tree
  #   treeTypeRec - tree type 'OTC' record
  #   versionRec - version 'v01' record
  #   subjectRec - subject record
  #   gradeBandRec - grade band record
  #   fullCode - code including parent codes (e.g. 1.1.1.a for a indicator).
  #   codeArray - all indicator codes that match this indicator (when indicator has multiple codes)
  #   parentRec - parent (area for component, component for outcome, outcome for indicator)
  #   matchRec - last record processed (at this depth), to prevent attempting to add more than once.
  def self.find_or_add_code_in_tree(treeTypeRec, versionRec, subjectRec, gradeBandRec, fullCode, codeArray, parentRec, matchRec, depth)
    # if this record is the same as matchRec, then it was already updated.
    matchCode = (matchRec ? matchRec.code : '')
    # name_key = Tree.buildNameKey(treeTypeRec, versionRec, subjectRec, gradeBandRec, fullCode)
    if fullCode == matchCode
      return fullCode, matchRec, BaseRec::REC_SKIP, "#{fullCode}"
    else
      # get the tree records for this hierarchy item
  #   where()
      matched_codes = Tree.where(
        tree_type_id: treeTypeRec.id,
        version_id: versionRec.id,
        subject_id: subjectRec.id,
        grade_band_id: gradeBandRec.id,
        code: fullCode,
        depth: depth
        )
      if matched_codes.count == 0
        # It has not been uploaded yet.  create it.
        tree = Tree.new
        tree.tree_type_id = treeTypeRec.id
        tree.version_id = versionRec.id
        tree.subject_id = subjectRec.id
        tree.grade_band_id = gradeBandRec.id
        tree.code = fullCode
        tree.matching_codes = codeArray
        tree.depth = depth
        # fill in parent id if parent passed in, and parent codes match.
        tree.name_key = Tree.buildNameKey(treeTypeRec, versionRec, subjectRec, gradeBandRec, fullCode)
        tree.base_key = Tree.buildBaseKey(treeTypeRec, versionRec, subjectRec, gradeBandRec, fullCode)
        ret = tree.save
        if tree.errors.count > 0
          return fullCode, nil, BaseRec::REC_ERROR, "#{I18n.t('trees.errors.save_curriculum_code_error', code: fullCode)} #{tree.errors.full_messages}"
        else
          return fullCode, tree, BaseRec::REC_ADDED, "#{fullCode}"
        end
      elsif matched_codes.count == 1
        # it already exists, skip
        matched = matched_codes.first
        if matched.name_key.blank?
          # fixed if existing record is missing translation key or parent record id
          matched.name_key = matched.buildNameKey
          matched.base_key = matched.buildBaseKey
          matched.save
          # to do - do we need error checking here?
        end
        return fullCode, matched_codes.first, BaseRec::REC_NO_CHANGE, "#{fullCode}"
      else
        # too many matching items in database: system error.
        err_str = I18n.t('trees.errors.too_many_match_subject_gb_code', subject: @upload.subject_id, gb: @upload.grade_band_id, code: fullCode)
        Rails.logger.error("ERROR: #{err_str} ")
        return fullCode, nil, BaseRec::REC_ERROR, err_str
      end # if
    end # if code == matchCode
  end

  def self.find_code_in_tree(treeTypeRec, versionRec, subjectRec, gradeBandRec, fullCode)
    # get the tree records for this hierarchy item
    matched_codes = Tree.where(
      tree_type_id: treeTypeRec.id,
      version_id: versionRec.id,
      subject_id: subjectRec.id,
      grade_band_id: gradeBandRec.id,
      code: fullCode
    )
    Rails.logger.debug ("*** find code: #{fullCode}")
    if matched_codes.count == 1
      # it already exists, skip
      matched = matched_codes.first
      return matched
    elsif matched_codes.count == 0
      Rails.logger.error ("ERROR - missing tree rec for: #{subjectRec.code}, #{gradeBandRec.code}, #{fullCode}")
      return nil
    end # if
  end

end
