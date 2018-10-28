class UploadsController < ApplicationController

  PROCESSING_DEPTH = 5
  CODE_DEPTH = 4
  ROCESSING_AREA = 0
  ROCESSING_COMPONENT = 1
  ROCESSING_OUTCOME = 2
  ROCESSING_INDICATOR = 3
  PROCESSING_SECTOR = 4

  # types of stacks
  RECS_STACK = 0
  NUM_ERRORS_STACK = 1
  IDS_STACK = 2
  CODES_STACK = 3


  before_action :authenticate_user!
  before_action :find_upload, only: [:show, :edit, :update, :start_upload, :do_upload]

  def index
    unauthorized() and return if !user_is_admin?(current_user)
    index_prep
    respond_to do |format|
      format.html
      format.json { render json: @uploads}
    end
  end

  # def index2
  #   uploads = Upload.includes([:subject, :grade_band, :locale]).all.upload_listing
  # end

  def new
    unauthorized() and return if !user_is_admin?(current_user)
    @upload = Upload.new()
  end

  def create
    unauthorized() and return if !user_is_admin?(current_user)
    @upload = Upload.new(upload_params)
    if @upload.save
      flash[:success] = "Upload for #{ @upload.subject.code } #{ @upload.grade_band.code } #{ @upload.locale.name } updated."
      redirect_to uploads_path()
    end
  end

  def show
    unauthorized() and return if !user_is_admin?(current_user)
  end

  def edit
    unauthorized() and return if !user_is_admin?(current_user)
  end

  def update
    unauthorized() and return if !user_is_admin?(current_user)
    if @upload.update(upload_params)
      flash[:notice] = "Upload for #{ @upload.subject.code } #{ @upload.grade_band.code } #{ @upload.locale.name } updated."
      redirect_to uploads_path()
    else
      render :edit
    end
  end

  def upload_summary
    unauthorized() and return if !user_is_admin?(current_user)
    index_prep
  end

  def start_upload
    unauthorized() and return if !user_is_admin?(current_user)
    if @upload
      @message = "Select file to upload to get to next step"
      @errs = []
      @rptRecs = []
      if !@upload.status_detail.present?
        @status_detail = ''
      else
        @status_detail = "Errors from last upload:<br>#{@upload.status_detail.split('$$$').join('<br>')}"
      end
      render :do_upload
    else
      flash[:notice] = 'Missing upload record.'
      index_prep
      render :index
    end
  end

  def do_upload
    unauthorized() and return if !user_is_admin?(current_user)
    require 'csv'

    # infomation to send back to user after completion
    row_num = 0
    @message = "Select file to upload to get to next step"
    @errs = []
    @rowErrs = []
    @treeErrs = false
    @sectorErrs = false
    @rptRecs = []
    abortRun = false
    @abortRow = false
    @status_detail = ''

    Rails.logger.debug ("*** upload: #{params['upload']}")
    Rails.logger.debug("*** params: #{params}")
    Rails.logger.debug("*** params['phase']: #{params['phase']}")

    @phaseOne =  (params['phase'] == '1') ? true : false
    @phaseTwo =  (params['phase'] == '2') ? true : false
    @phaseOne = true if !@phaseOne && !@phaseTwo

    Rails.logger.debug("*** @phaseOne: #{@phaseOne}")
    Rails.logger.debug("*** @phaseTwo: #{@phaseTwo}")

    if @upload && params['upload']
      @subjectRec = @upload.subject
      @gradeBandRec = @upload.grade_band
      @localeRec = @upload.locale
      tree_parent_code = ''

      # check filename
      if upload_params['file'].original_filename != @upload.filename
        flash[:alert] = I18n.translate('uploads.errors.incorrect_filename', filename: @upload.filename)
        abortRun = true
        Rails.logger.debug("*** seed filename: #{@upload.filename.inspect}")
        Rails.logger.debug("*** upload filename: #{upload_params['file'].original_filename.inspect}")
      elsif @upload.status == BaseRec::UPLOAD_DONE
        # skip processing if already done, otherwise process)
        flash[:notify] = I18n.translate('uploads.warnings.already_completed', filename: @upload.filename)
        abortRun = true
      else
        # process file to upload

        # stacks is an array whose elements correspond to the depth of the code tree (level of processing)
        #  - (e.g. 0 - Area, 1 - Component, 2 - Outcome, ...)
        stacks = Array.new
        stacks[RECS_STACK] = Array.new(CODE_DEPTH) {nil} # current records at each level of procesing
        stacks[NUM_ERRORS_STACK] = Array.new(PROCESSING_DEPTH) {0} # count of errors at each level of procesing
        stacks[IDS_STACK] = Array.new(PROCESSING_DEPTH) {[]} # ids of records at each level of procesing (Areas, ..., sectors, relations)


        # Create a stream using the original file.
        file = File.open upload_params['file'].path
        # Consume the first two CSV rows.
        line = file.gets
        # Rails.logger.debug("*** first line read: #{line.inspect}")
        line = file.gets
        # Rails.logger.debug("*** second line read: #{line.inspect}")
        infoLine = line.split(',')
        # Rails.logger.debug("*** second infoLine: #{line.inspect}")
        grade_band = 0
        begin
          grade_band = Integer(infoLine[3])
        rescue ArgumentError, TypeError
          grade_band = 0
        end
        raise "Invalid grade band on second header row: #{infoLine[2]}: #{infoLine[3]}" if infoLine[2] != 'Raspon:' || grade_band ==  0
        # Create your CSV object using the remainder of the stream.
        csv = CSV.new file, headers: true
        csv.each do |row|

          @rowErrs = []
          stacks[CODES_STACK] = Array.new(CODE_DEPTH) {''}
          row_num += 1

          Rails.logger.info("PROCESSING ROW: #{row_num}, #{row.inspect}")

          # skip rows if missing required fields (beside row number and grade band)
          # otherwise blank rows produce errors stopping the upload
          break if !validUploadRow?(@localeRec.code, row)

          # process each column of this row
          row.each_with_index do |(key, val), ix|
            @abortRow = false

            # validate grade band in this row matches this upload
            # return an error for this row if it is for the wrong grade level
            grade_band = get_grade_band(@localeRec.code, row)
            if grade_band != @gradeBandRec.code
              @rowErrs << I18n.translate('app.labels.row_num', num: row_num) + I18n.translate('app.errors.invalid_grade_band', grade_band: grade_band)
              @abortRow = true
            end

            # map csv headers to short symbols
            new_key = Upload.get_short(@localeRec.code, key)

            # # ensure required rows have data
            # if new_key.present? && Upload::SHORT_REQ[new_key.to_sym] && val.blank?
            #   @rowErrs << I18n.translate('app.labels.row_num', num: row_num) + I18n.translate('app.errors.missing_req_field', field: new_key)
            #   @abortRow = true
            # end

            # process this column for this row
            case new_key
            when :row
              if val.to_s != row_num.to_s
                # Rails.logger.error "ERROR: mismatched row num: #{val} != #{row_num}"
                @abortRow = true
                @rowErrs << I18n.translate('app.labels.row_num', num: row_num) + I18n.translate('app.errors.invalid_sheetID', code: val)
              end
            when :area
              # if @phaseOne || @upload.status == BaseRec::UPLOAD_NOT_UPLOADED || @upload.status == BaseRec::UPLOAD_TREE_UPLOADING
              if @phaseOne
                stacks = process_otc_tree(0, val, row_num, stacks, grade_band)
              end
            when :component
              # if @phaseOne || @upload.status == BaseRec::UPLOAD_NOT_UPLOADED || @upload.status == BaseRec::UPLOAD_TREE_UPLOADING
              if @phaseOne
                stacks = process_otc_tree(1, val, row_num, stacks, grade_band)
              end
            when :outcome
              # if @phaseOne || @upload.status == BaseRec::UPLOAD_NOT_UPLOADED || @upload.status == BaseRec::UPLOAD_TREE_UPLOADING
              if @phaseOne
                stacks = process_otc_tree(2, val, row_num, stacks, grade_band)
              end
            when :indicator
              # if @phaseOne || @upload.status == BaseRec::UPLOAD_NOT_UPLOADED || @upload.status == BaseRec::UPLOAD_TREE_UPLOADING
              if @phaseOne
                stacks = process_otc_tree(3, val, row_num, stacks, grade_band)
              end
            when :relevantKbe
              Rails.logger.debug("**** when Relevant KBE")
              # if @phaseOne || @upload.status == BaseRec::UPLOAD_TREE_UPLOADED
              if @phaseOne
                process_sector(val, row_num, stacks)
              end
            when :sectorRelation
              Rails.logger.debug("**** when sectorRelation")
              # if @phaseOne || @upload.status == BaseRec::UPLOAD_TREE_UPLOADED
              if @phaseOne
                process_sector_relation(val, row_num, stacks) if val.present?
              end
            when :currentSubject, :chemistry, :mathematics, :geography, :physics, :biology, :computers
              Rails.logger.debug("**** when subject: #{new_key} (#{key}), #{@localeRec.code}")
              if @phaseTwo
                process_subject_relation(val, row_num, stacks) if val.present?
              end
            end
            break if @abortRow || @rowErrs.count > 0
          end # row.each
          @errs.concat(@rowErrs)
        end # CSV.foreach
      end
    else
      Rails.logger.error("ERROR:  invalid params: #{params}")
      flash[:alert] = "ERROR: MISSING upload filename"
      abortRun = true
    end # if upload
    if abortRun
      index_prep
      render :index
    else
      # Update status level
      if stacks[IDS_STACK][ROCESSING_AREA].count > 0
        @upload.status = BaseRec::UPLOAD_TREE_UPLOADING
        if !@treeErrs
          @upload.status = BaseRec::UPLOAD_TREE_UPLOADED
          # to do - update this to wait till sector explanation done.
          if stacks[IDS_STACK][PROCESSING_SECTOR].count > 0 && !@sectorErrs
            @upload.status = BaseRec::UPLOAD_SECTOR_RELATED
          end
        end
        # save all errors into the upload status detail field for easy review of last run of errors
        @upload.status_detail = @errs.join('$$$')
        @upload.save
      end
      render :do_upload
    end
  end

  private

  def find_upload
    @upload = Upload.find(params[:id])
  end

  def upload_params
    params.require('upload').permit(:subject_id, :grade_band_id, :locale_id, :status, :file, :phase, :upload)
    # # ToDo - what is the upload param for ???
    # # params.permit(:subject_id, :grade_band_id, :locale_id, :status, :file, :phase, :upload)
    # params.permit(:utf8, :authenticity_token, :upload, :locale, :id, :phase)
  end

  def index_prep
    @uploads = Upload.order(:id).includes([:subject, :grade_band, :locale]).all.upload_listing
  end

  def parseSubCodeText(str, depth, stacks)
    if !str.present?
      return "BLANK", '', '', '[]'
    end
    if depth < 2
      # Area formatting: "AREA #: <name>""
      # Component formatting: "Component #: <name>""
      strArray = str.strip.split(/[:;\.\s]+/)
      label = strArray[0]
      code = strArray[1]
      desc = str[(label.length+code.length+2)..-1]
      text = desc.present? ? desc.lstrip : ''
      return code, text, '', '[]'
    elsif depth == 2
      # Outcome formatting: "Outcome: #. <name>""
      # Outcome formatting: "Outcome: #.#.#. <name>""
      strArray1 = str.strip.split(/[:\s]+/)
      label_length = strArray1[0].length+1
      str2 = str[label_length..str.length].strip
      strArray = str2.strip.split(/\./)
      label = strArray.first.present? ? strArray.first : ''
      skip_count = label_length
      strArray.each_with_index do |str, ix|
        if (Integer(str) rescue(-1)) >= 0
          label = str
          skip_count += str.length + 1
        end
      end
      desc = str[(skip_count+1)..-1]
      Rails.logger.debug("*** str: #{str.inspect}")
      Rails.logger.debug("*** str2 = #{str2.inspect}")
      Rails.logger.debug("*** skip_count: #{skip_count}, desc: #{desc.inspect}")
      text = desc.present? ? desc.lstrip : ''
      return label.gsub(/[^0-9]/, ""), text, '', '[]'
    else
      cs = stacks[CODES_STACK]
      outcomeCode = "#{cs[0]}.#{cs[1]}.#{cs[2]}"
      arrCodes = []
      arrDescs = []
      indicCodeFirst = ''
      # split multiple indicators and process each
      str.split(outcomeCode).each do |outc|
        if outc.strip.length > 0
          outcScan = StringScanner.new(outc)
          # skip any white space or punctuation to get the indicator code
          outcScan.skip_until /[\s[[:punct:]]]*/
          # get the indicator code
          indicCode = outcScan.scan /./
          # change cyrilliac codes to western (english sequence)
          indicCodeW = Tree.indicatorLetterByLocale(@localeRec.code, indicCode)
          # save off the first indicator code
          indicCodeFirst = indicCodeW if indicCodeFirst.blank?
          # skip any white space or punctuation to the text of the indicator
          outcScan.skip_until /[\s[[:punct:]]]*/
          arrCodes << "#{outcomeCode}.#{indicCodeW}"
          arrDescs << outcScan.rest.strip
          Rails.logger.debug("*** outc: #{outc.inspect}, indicCode: #{indicCode.inspect}, indicCodeW: #{indicCodeW.inspect}")
        end
      end
      return indicCodeFirst, JSON.dump(arrDescs), arrCodes.first, JSON.dump(arrCodes)
    end
  end

  def buildFullCode(codes_stack, depth)
    Rails.logger.debug("*** codes_stack: #{codes_stack.inspect}, depth: #{depth}")
    return codes_stack[0..depth].join('.')
  end

  def process_otc_tree(depth, val, row_num, stacks, grade_band)
    code_str, text, indicatorCode, indicCodeArr = parseSubCodeText(val, depth, stacks)

    Rails.logger.debug("*** parseSubCodeText(val=#{val.inspect}, depth=#{depth}")
    # Rails.logger.debug("*** parseSubCodeText(stacks=#{stacks.inspect}")
    Rails.logger.debug("*** returns:")
    Rails.logger.debug("*** code_str: #{code_str.inspect}")
    Rails.logger.debug("*** text: #{text.inspect}")
    Rails.logger.debug("*** indicatorCode: #{indicatorCode.inspect}")
    Rails.logger.debug("*** indicCodeArr: #{indicCodeArr.inspect}")
    stacks[CODES_STACK][depth] = code_str # save currant code in codes stack
    builtCode = buildFullCode(stacks[CODES_STACK], depth)
    Rails.logger.debug("*** depth: #{depth}, builtCode: #{builtCode.inspect}")
    if depth == 3

      if code_str.length < 1
        # no indicator is ok for grades 3 and 6
        #   (some indicators are only for higher grades)
        Rails.logger.debug("*** invalid indicator for higher gradeband")
        @abortRow = true
        if !['3', '6'].include?(grade_band)
          @rowErrs << I18n.translate('app.labels.row_num', num: row_num) + I18n.translate('app.errors.invalid_code', code: val)
        end
      elsif indicatorCode != builtCode
        # indicator code does not match code from Area, Component and Outcome.
        Rails.logger.debug("*** indicatorCode (#{indicatorCode}) != builtCode (#{builtCode}")
        @abortRow = true
        if !['3', '6'].include?(grade_band)
          @rowErrs << I18n.translate('app.labels.row_num', num: row_num) + I18n.translate('app.errors.invalid_code', code: indicatorCode)
        end
      elsif indicatorCode.include?('INVALID')
        Rails.logger.debug("*** indicatorCode has INVALID - val: #{val.inspect}, code_str: #{code_str.inspect}, indicatorCode: #{indicatorCode.inspect}")
        @abortRow = true
        @rowErrs << I18n.translate('app.labels.row_num', num: row_num) + I18n.translate('app.errors.invalid_indicator', indicator: "#{code_str[0]},
          #{text}")
      end
    end
    if @abortRow
      # don't process record if to be aborted.
      Rails.logger.debug("*** @abortRow")
      save_status = BaseRec::REC_ERROR
      message = ''
    else
      # insert record into tree
      new_code, node, save_status, message = Tree.find_or_add_code_in_tree(
        @treeTypeRec,
        @versionRec,
        @subjectRec,
        @gradeBandRec,
        builtCode,
        indicCodeArr,
        nil, # to do - set parent record for all records below area
        stacks[RECS_STACK][depth],
        depth
      )
    end

    if save_status != BaseRec::REC_SKIP

      # update text translation for this locale (if not skipped)
      if save_status == BaseRec::REC_ERROR
        @rowErrs << message if message.present?
        # stacks[NUM_ERRORS_STACK][depth] += 1
        # Note: no update of translation if error
        translation_val = ''
      else # if save_status ...
        # update current node in records stack, and save off id.
        stacks[RECS_STACK][depth] = node
        stacks[IDS_STACK][depth] << node.id if !stacks[IDS_STACK][depth].include?(node.id)
        # update translation if not an error and value changed
        transl, text_status, text_msg = Translation.find_or_update_translation(
          @localeRec.code,
          "#{@treeTypeRec.code}.#{@versionRec.code}.#{@subjectRec.code}.#{@gradeBandRec.code}.#{node.code}.name",
          text
        )
        if text_status == BaseRec::REC_ERROR
          @rowErrs << text_msg
        end
        translation_val = transl.value.present? ? transl.value : ''
      end # if save_status ...
      # statMsg = "#{BaseRec::SAVE_CODE_STATUS[save_status]}"
      statMsg = I18n.translate('uploads.labels.saved_code', code: builtCode) if save_status == BaseRec::REC_ADDED || save_status == BaseRec::REC_UPDATED
      statMsg = statMsg.blank? ? "#{@rowErrs.join(', ')}" : statMsg + ", #{@rowErrs.join(', ')}" if @rowErrs.count > 0

      # generate report record if not skipped
      rptRec = [row_num]
      rptRec.concat(stacks[CODES_STACK].clone)  # code stack for first four columns of report
      rptRec << new_code
      rptRec << translation_val
      rptRec << statMsg
      @rptRecs << rptRec

    end # if not skipped record
    @treeErrs = true if @rowErrs.count > 0
    return stacks
  end # process_otc_tree

  def process_sector(val, row_num, stacks)
    Rails.logger.debug("*** process_sector(#{val}, #{row_num}, #{stacks}")
    tree_rec = stacks[RECS_STACK][ROCESSING_INDICATOR] # get current indicator record from stacks
    errs = []
    relations = []
    # split by semi-colon and period and others!!!
    # Not split by comma (used in Sector Names)
    sectorNames = val.present? ? val.split(/[:;\.)]+/) : []
    Rails.logger.debug("*** sectorNames: #{sectorNames.inspect}")
    # get a hash of all sectors translations that return the sector code
    sectorTranslations = get_sectors_translations()
    Rails.logger.debug("*** sectorTranslations: #{sectorTranslations.inspect}")

    sectorNames.each do |s|
      # matching of descriptions
      Rails.logger.debug("*** sectorName: #{s.inspect}")
      clean_s = s.strip
      break if clean_s.blank?

      # hard coded sector names matches (when spreadsheet does not match db)
      case clean_s
      when 'IT', 'IKT', 'it', 'ikt', 'ИТ'
        sector_num = 1
      when 'Medicina i srodni sektori', 'medicina i srodni sektori', 'Медицина и сродни сектори'
        sector_num = 2
      when 'Tehnologija materijala', 'tehnologija materijala', 'Технологија материјала', 'технологија материјала'
        sector_num = 3
      when 'Proizvodnja energije, prenos i efikasnost', 'Energija i obnovljivi izvori', 'proizvodnja energije, prenos i efikasnost', 'energija i obnovljivi izvori', 'производња енергије, пренос и ефикасност', 'Производња енергије', 'пренос и ефикасност'
        sector_num = 4
      when 'Umjetnost', 'Umjetnost'
        sector_num = 6
      when 'Sport', 'sport'
        sector_num = 7
      when 'Poljoprivredna proizvodnja', 'poljoprivredna proizvodnja', 'пољопривредна производња'
        sector_num = 10
      when 'medicina i srodni sektoritehnologija materijalaITproizvodnja energije, prijenos i učinkovitost'
        sector_num = 98 # 2, 3, 1, 4
      when 'Svi KBE sektori', 'svi KBE sektori', 'Сви ЕЗЗ-а сектори'
        sector_num = 99 # all
      else
        # pull out leading sector number if there (split on space or period)
        begin
          lead_word = clean_s.split(/[\s\.;:']/).first # no commas, used in Sector Names
          sector_num = Integer(lead_word)
          Rails.logger.debug("*** found sector_num: #{sector_num}")
        rescue ArgumentError, TypeError
          sector_num = 0
        end
      end

      if sector_num == 98
        relations = ['1','2','3','4']
      elsif sector_num == 99
        relations = ['1','2','3','4','5','6','7','8','9','10']
      elsif sector_num > 0
        if !relations.include?(sector_num.to_s)
          relations << sector_num.to_s
        end
      end

    end
    sectorsAdded = []
    relations.each do |r|
      # get the KBE code from the looked up sector description in the translation table
      begin
        sectors = Sector.where(code: r)
        throw "Missing sector with code #{r.inspect}" if sectors.count < 1
        sector = sectors.first
        # check the sectors_trees table to see if it is joined already
        matchedTrees = sector.trees.where(id: tree_rec.id)
        # if not, join them
        if matchedTrees.count == 0
          sector.trees << tree_rec
          sectorsAdded << r
        end
      rescue ActiveRecord::ActiveRecordError => e
        errs << I18n.translate('uploads.errors.exception_relating_sector_to_tree', e: e)
      end
    end
    # get current list of related sector for this tree
    allSectors = []
    tree_rec.sectors.each do |s|
      # join tree and sector
      allSectors << s.code
      stacks[IDS_STACK][PROCESSING_SECTOR] << "#{tree_rec.id}-#{s.id}" if !stacks[IDS_STACK][PROCESSING_SECTOR].include?("#{tree_rec.id}-#{s.id}")
    end
    statMsg = I18n.translate('app.labels.new_sector_relations', sectors: sectorsAdded.join(', ') )
    if errs.count > 0
      statMsg += ', '+ errs.join(', ')
      @rowErrs << I18n.translate('app.labels.row_num', num: row_num) + errs.join(', ')
    end
    # generate report record
    rptRec = [row_num]
    rptRec.concat(Array.new(CODE_DEPTH) {''}) # blank out the first four columns of report
    rptRec << '' # blank out the code column of report
    rptRec << ((allSectors.count > 0) ? I18n.translate('app.labels.related_to_sectors', sectors: allSectors.join(', ')) : 'No related sectors.')
    rptRec << statMsg
    @rptRecs << rptRec


    @sectorErrs = true if @rowErrs.count > 0

  end

  def process_sector_relation(val, row_num, stacks)
    # to do - ensure this is run if the @process_fully flag is not set
    errs = []
    tree_rec = stacks[RECS_STACK][ROCESSING_INDICATOR] # get current indicator record from stacks
    explain, text_status, text_msg = Translation.find_or_update_translation(
      @localeRec.code,
      "#{tree_rec.base_key}.explain",
      val
    )
    if text_status == BaseRec::REC_ERROR
      err_str = text_msg
      errs << err_str
      @rowErrs << err_str
    end

    # generate report record
    rptRec = [row_num]
    rptRec.concat(Array.new(CODE_DEPTH) {''}) # blank out the first four columns of report
    rptRec << '' # blank out the code column of report
    rptRec << "#{I18n.translate('app.labels.sector_related_explain')}: #{explain.value}"
    rptRec << ((errs.count > 0) ? errs.to_s : '')
    @rptRecs << rptRec

    @sectorErrs = true if errs.count > 0

  end

  def get_sectors_translations
    sectorNameKeys = Sector.all.map { |s| s.name_key }
    translationByNames = Hash.new
    translations = Translation.where(key: sectorNameKeys).all
    translations.each do |t|
      translationByNames[t.value] = t.key[/[0-9]+/]
    end
    return translationByNames
  end

  def get_grade_band(locale, row)
    row.each do |key, val|
      if Upload.get_short(locale, key) == :gradeBand
        return val
      end
    end
    Rails.logger.error "ERROR: GradeBand - locale: #{locale} - row: #{row.inspect}"
    return "Cannot match :gradeBand"
  end


  # skip row if more than two blank required fields
  # - note some rows came in with only row and grade band filled in
  # otherwise process row and indicate errors
  def validUploadRow?(locale, row)
    missing_count = 0
    row.each do |key, val|
      shortKey = Upload.get_short(locale, key)
      if shortKey.present? && Upload::SHORT_REQ[shortKey.to_sym] && val.blank?
        puts "invalid upload row: #{shortKey} - #{row.inspect}"
        missing_count += 1
      end
    end
    return (missing_count > 2 ? false : true)
  end

end
