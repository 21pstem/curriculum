class UploadsController < ApplicationController

  PROCESSING_DEPTH = 7
  CODE_DEPTH = 4
  ROCESSING_AREA = 0
  ROCESSING_COMPONENT = 1
  ROCESSING_OUTCOME = 2
  PROCESSING_INDICATOR = 3
  PROCESSING_SECTOR = 4
  PROCESSING_SECTOR_EXPLAIN = 5
  PROCESSING_SUBJECT_REL = 6

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
        @status_detail = "<h5>Errors from Phase 1 upload:</h5>#{@upload.status_detail.split('$$$').join('<br>')}"
      end
      if @upload.statusPhase2.present?
        @status_detail += "<br><h5>Errors from Phase 2 upload:</h5>#{@upload.statusPhase2.split('$$$').join('<br>')}"
      end
      Rails.logger.debug("*** @status_detail: #{@status_detail.inspect}")
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
    @subjectErrs = false
    @rptRecs = []
    abortRun = false
    @abortRow = false
    @status_detail = ''

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

      Rails.logger.debug("*** @upload.status: #{@upload.status} ==? #{BaseRec::UPLOAD_SECTOR_RELATED}")
      # check filename
      if upload_params['file'].original_filename != @upload.filename
        flash[:alert] = I18n.translate('uploads.errors.incorrect_filename', filename: @upload.filename)
        abortRun = true
        Rails.logger.debug("*** seed filename: #{@upload.filename.inspect}")
        Rails.logger.debug("*** upload filename: #{upload_params['file'].original_filename.inspect}")
      elsif @upload.status == BaseRec::UPLOAD_DONE
        # skip processing if already done, otherwise process)
        Rails.logger.debug("*** file done")
        flash[:notify] = I18n.translate('uploads.warnings.already_completed', filename: @upload.filename)
        abortRun = true
      # elsif @phaseTwo && @upload.status < 3
      #   # do not process phase 2 until LO tree is uploaded
      #   Rails.logger.debug("*** cannot process file, @phaseTwo: #{@phaseTwo}, status: #{@upload.status}")
      #   flash[:notify] = "Cannot process Phase 2 for #{@upload.filename} until Learning Outcomes are successfully loaded and Sectors are related"
      #   abortRun = true
      else
        Rails.logger.debug("*** process file")
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
        Rails.logger.debug("*** first line read: #{line.inspect}")
        line = file.gets
        Rails.logger.debug("*** second line read: #{line.inspect}")
        infoLine = line.split(',')
        # Rails.logger.debug("*** second infoLine: #{line.inspect}")
        # detect if shifted over for english extra row column
        gradeCol = 0
        Rails.logger.debug("*** infoLine[2]: #{infoLine[2].inspect}")
        Rails.logger.debug("*** infoLine[3]: #{infoLine[3].inspect}")
        Rails.logger.debug("*** infoLine[4]: #{infoLine[4].inspect}")
        Rails.logger.debug("*** infoLine[5]: #{infoLine[5].inspect}")
        if infoLine[1].strip === 'Raspon:' || infoLine[1].strip === 'Grade Band:'
          gradeCol = 2
        elsif infoLine[2].strip === 'Raspon:' || infoLine[2].strip === 'Grade Band:'
          gradeCol = 3
        elsif infoLine[3].strip == 'Raspon:' || infoLine[3].strip == 'Grade Band:'
          gradeCol = 4
        end
        grade_band = 0
        begin
          grade_band = Integer(infoLine[gradeCol])
        rescue ArgumentError, TypeError
          grade_band = 0
        end
        Rails.logger.debug("*** infoLine[gradeCol]: #{infoLine[gradeCol].inspect}")
        raise "Invalid grade band on second header row: #{gradeCol} - #{infoLine[gradeCol].inspect}" if gradeCol == 0 || grade_band == 0
        # Create your CSV object using the remainder of the stream.
        csv = CSV.new file, headers: true
        Rails.logger.debug("*** get csv rows")
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
            if key
              new_key = Upload.get_short(@localeRec.code, key, ix)
            else
              new_key = :skip
            end

            # # ensure required rows have data
            # if new_key.present? && Upload::SHORT_REQ[new_key.to_sym] && val.blank?
            #   @rowErrs << I18n.translate('app.labels.row_num', num: row_num) + I18n.translate('app.errors.missing_req_field', field: new_key)
            #   @abortRow = true
            # end

            # process this column for this row
            Rails.logger.debug("")
            Rails.logger.debug("*** matching procesing column: #{ix.inspect} #{new_key.inspect}")
            if !new_key
              if ix == 8
                Rails.logger.debug("*** fix column 8 header")
                new_key = :currentSubject
              end
            end
            Rails.logger.debug("*** fixed procesing column: #{new_key}")
            case new_key
            when :skip
              # skip this column
            when :row
              if val.to_s != row_num.to_s
                # Rails.logger.error "ERROR: mismatched row num: #{val} != #{row_num}"
                @abortRow = true
                @rowErrs << I18n.translate('app.labels.row_num', num: row_num) + I18n.translate('app.errors.invalid_sheetID', code: val)
              end
            when :area
              # if @phaseOne || @upload.status == BaseRec::UPLOAD_NOT_UPLOADED || @upload.status == BaseRec::UPLOAD_TREE_UPLOADING
              if true
                stacks = process_otc_tree(0, val, row_num, stacks, grade_band)
              end
            when :component
              # if @phaseOne || @upload.status == BaseRec::UPLOAD_NOT_UPLOADED || @upload.status == BaseRec::UPLOAD_TREE_UPLOADING
              if true
                stacks = process_otc_tree(1, val, row_num, stacks, grade_band)
              end
            when :outcome
              # if @phaseOne || @upload.status == BaseRec::UPLOAD_NOT_UPLOADED || @upload.status == BaseRec::UPLOAD_TREE_UPLOADING
              if true
                stacks = process_otc_tree(2, val, row_num, stacks, grade_band)
              end
            when :indicator
              # if @phaseOne || @upload.status == BaseRec::UPLOAD_NOT_UPLOADED || @upload.status == BaseRec::UPLOAD_TREE_UPLOADING
              if true
                stacks = process_otc_tree(3, val, row_num, stacks, grade_band)
              end
            when :gradeBand
              # skip this, already obtained for each element
            when :relevantKbe
              # load relevant KBE if phase 2 or tree has been uploaded
              if true
                Rails.logger.debug("**** when Relevant KBE")
                process_sector(val, row_num, stacks)
              end
            when :sectorRelation
              # load Sector Relations if phase 2 or tree has been uploaded
              if true
                Rails.logger.debug("**** when sectorRelation")
                process_sector_relation(val, row_num, stacks) if val.present?
              end
            when :currentSubject, :chemistry, :mathematics, :geography, :physics, :biology, :computers
              Rails.logger.debug("*** process a subject column for #{new_key} with value: #{val}")
              if @phaseTwo
                Rails.logger.debug("**** when subject: #{new_key} (#{key}), #{@localeRec.code}")
                process_subject_relation(val, row_num, stacks, new_key) if val.present?
              end
            when :originalRow
              # skip this, ignoring this column
            when :bio_geo
              # if empty, skip this and fix or process later.
              if (val.present?)
                Rails.logger.debug("**** Warning: bio_geo has a value of: #{val.inspect}")
                @rowErrs << "Warning, Unable to match subject for biology / geology column in row: #{row_num}"
              end
            else
              if ix > 12
                # ignore teacher input columns
                # note original english files did not have row or originalRow, so for tests to pass we need this to be 12
                # note final bs, hr, sr files do not have originalRow
              else
                Rails.logger.error("ERROR at column #{ix} matching: #{new_key} - '#{key}''")
                throw "invalid column header: #{key}"
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
        Rails.logger.debug("processing area count: #{stacks[IDS_STACK][ROCESSING_AREA].count}")
        @upload.status = BaseRec::UPLOAD_TREE_UPLOADING
        Rails.logger.debug("tree errors: #{@treeErrs.inspect}")
        if !@treeErrs
          Rails.logger.debug("no tree errors")
          @upload.status = BaseRec::UPLOAD_TREE_UPLOADED
          # to do - update this to wait till sector explanation done.
          Rails.logger.debug("processing sector count: #{stacks[IDS_STACK][PROCESSING_SECTOR].count}")
          Rails.logger.debug("processing sector explain count: #{stacks[IDS_STACK][PROCESSING_SECTOR_EXPLAIN].count}")
          Rails.logger.debug("sector errors: #{@sectorErrs.inspect}")
          if stacks[IDS_STACK][PROCESSING_SECTOR].count > 0 &&
            stacks[IDS_STACK][PROCESSING_SECTOR_EXPLAIN] &&
            stacks[IDS_STACK][PROCESSING_SECTOR_EXPLAIN].count > 0 &&
              !@sectorErrs
            @upload.status = BaseRec::UPLOAD_SECTOR_RELATED
          end
        end
        Rails.logger.debug("processing subjects count: #{stacks[IDS_STACK][PROCESSING_SUBJECT_REL].count}")
        Rails.logger.debug("subject errors: #{@subjectErrs.inspect}")
        @upload.status = BaseRec::UPLOAD_SUBJ_RELATING
        if stacks[IDS_STACK][PROCESSING_SUBJECT_REL].count > 0
          @upload.status = BaseRec::UPLOAD_SUBJ_RELATING
          @upload.status = BaseRec::UPLOAD_SUBJ_RELATED if !@subjectErrs
        end
      # save all errors into the upload status detail field for easy review of last run of errors
        if @phaseOne
          @upload.status_detail = @errs.join('$$$')
        elsif @phaseTwo
          @upload.statusPhase2 = @errs.join('$$$')
        end
        @upload.status = BaseRec::UPLOAD_DONE if @upload.status == BaseRec::UPLOAD_SUBJ_RELATED
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
          if Tree::INDICATOR_SEQ_ENG.include?(indicCode)
            Rails.logger.debug("*** western character")
            indicCodeW = indicCode
          else
            Rails.logger.debug("*** not western character: #{"%s %3d %02X" % [ indicCode, indicCode.ord, indicCode.ord ]}")
            indicCodeW = Tree.indicatorLetterByLocale(@localeRec.code, indicCode)
          end
          Rails.logger.debug("**** indicCodeFirst: #{indicCodeFirst}, indicCode: #{indicCode}, indicCodeW: #{indicCodeW}")
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
      Rails.logger.debug("*** Depth == 3")
      if code_str.length < 1
        Rails.logger.debug("*** code_str.length < 1")
        # no indicator is ok for grades 3 and 6
        #   (some indicators are only for higher grades)
        Rails.logger.debug("*** invalid indicator for higher gradeband")
        @abortRow = true
        if !['3', '6'].include?(grade_band)
          @rowErrs << I18n.translate('app.labels.row_num', num: row_num) + I18n.translate('app.errors.invalid_code', code: val)
        end
      elsif indicatorCode != builtCode
        Rails.logger.debug("*** indicatorCode != builtCode")
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
      Rails.logger.debug("*** OK")
    end
    if @abortRow
      # don't process record if to be aborted.
      Rails.logger.debug("*** @abortRow")
      save_status = BaseRec::REC_ERROR
      message = ''
    elsif depth == 3
      Rails.logger.debug("*** depth == 3")
      textArr = JSON.load(text)
      codeArr = JSON.load(indicCodeArr)
      Rails.logger.debug("*** indicCodeArr: #{codeArr.inspect}")
      # check to see if indicator code arrays match
      if !codeArr.kind_of?(Array)
        @abortRow = true
        @rowErrs << "Row: #{row_num} - Invalid code array from parseSubCodeText"
      elsif !textArr.kind_of?(Array)
        @abortRow = true
        @rowErrs << "Row: #{row_num} - Invalid text array from parseSubCodeText"
      elsif codeArr.length != textArr.length
        @abortRow = true
        @rowErrs << "Row: #{row_num} - Invalid length of indicator codes and descriptions."
      end
    else
      codeArr = [code_str]
      textArr = [text]
    end

    if save_status != BaseRec::REC_SKIP
      if !@abortRow
        codeArr.each_with_index do |iCode, ix|
          recCode = (depth < 3) ? builtCode : iCode
          Rails.logger.debug("*** iCode: #{iCode.inspect}, builtCode: #{builtCode.inspect}")
          # insert record into tree
          new_code, @rowTreeRec, save_status, message = Tree.find_or_add_code_in_tree(
            @treeTypeRec,
            @versionRec,
            @subjectRec,
            @gradeBandRec,
            recCode,
            [iCode], # only put in this code (not all for row)
            nil, # to do - set parent record for all records below area
            stacks[RECS_STACK][depth],
            depth
          )

          # update text translation for this locale (if not skipped)
          if save_status == BaseRec::REC_ERROR
            @rowErrs << message if message.present?
            # stacks[NUM_ERRORS_STACK][depth] += 1
            # Note: no update of translation if error
            translation_val = ''
          else # if save_status ...
            # update current node in records stack, and save off id.
            stacks[RECS_STACK][depth] = @rowTreeRec
            stacks[IDS_STACK][depth] << @rowTreeRec.id if !stacks[IDS_STACK][depth].include?(@rowTreeRec.id)
            # update translation if not an error and value changed
            transl, text_status, text_msg = Translation.find_or_update_translation(
              @localeRec.code,
              "#{@treeTypeRec.code}.#{@versionRec.code}.#{@subjectRec.code}.#{@gradeBandRec.code}.#{@rowTreeRec.code}.name",
              textArr[ix]
            )
            Rails.logger.debug("*** process_otc_tree find_or_update_translation")
            Rails.logger.debug("*** arg 1: #{@localeRec.code}")
            Rails.logger.debug("*** arg 2: #{@treeTypeRec.code}.#{@versionRec.code}.#{@subjectRec.code}.#{@gradeBandRec.code}.#{@rowTreeRec.code}.name")
            Rails.logger.debug("*** arg 3: #{text}")
            Rails.logger.debug("*** returns:")
            Rails.logger.debug("*** transl: #{transl.inspect}")
            Rails.logger.debug("*** text_status: #{text_status.inspect}")
            Rails.logger.debug("*** text_msg: #{text_msg.inspect}")
            if text_status == BaseRec::REC_ERROR
              @rowErrs << text_msg
            end
            translation_val = transl.value.present? ? transl.value : ''
          end # if save_status ...

          # statMsg = "#{BaseRec::SAVE_CODE_STATUS[save_status]}"
          statMsg = I18n.translate('uploads.labels.saved_code', code: recCode) if save_status == BaseRec::REC_ADDED || save_status == BaseRec::REC_UPDATED
          statMsg = statMsg.blank? ? "#{@rowErrs.join(', ')}" : statMsg + ", #{@rowErrs.join(', ')}" if @rowErrs.count > 0

          # generate report record if not skipped
          rptRec = [row_num]
          rptRec.concat(stacks[CODES_STACK].clone)  # code stack for first four columns of report
          rptRec << new_code
          rptRec << translation_val
          rptRec << statMsg
          @rptRecs << rptRec if !@phaseTwo

        end # each indicator code array
      end # @abortRow

    end # if not skipped record
    @treeErrs = true if @rowErrs.count > 0
    return stacks
  end # process_otc_tree

  def process_sector(val, row_num, stacks)
    Rails.logger.debug("***")
    Rails.logger.debug("*** process_sector val: #{val}")
    Rails.logger.debug("*** process_sector row: #{row_num}")
    # Rails.logger.debug("*** process_sector(#{stacks}")
    tree_rec = stacks[RECS_STACK][PROCESSING_INDICATOR] # get current indicator record from stacks
    errs = []
    relations = []
    # split by semi-colon and period and others!!!
    # Not split by comma (used in Sector Names)
    sectorNames = val.present? ? val.split(/[:;\.)]+/) : []
    # Rails.logger.debug("*** sectorNames: #{sectorNames.inspect}")
    # get a hash of all sectors translations that return the sector code
    sectorTranslations = get_sectors_translations()
    # Rails.logger.debug("*** sectorTranslations: #{sectorTranslations.inspect}")

    sectorNames.each do |s|
      # matching of descriptions
      # Rails.logger.debug("*** sectorName: #{s.inspect}")
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
    # Rails.logger.debug("*** Sector Relations add")
    relations.each do |r|
      # get the KBE code from the looked up sector description in the translation table
      Rails.logger.debug("*** relation: #{r.inspect}")
      begin
        sectors = Sector.where(code: r)
        throw "Missing sector with code #{r.inspect}" if sectors.count < 1
        sector = sectors.first
        # check the sectors_trees table to see if it is joined already
        matchedTrees = sector.trees.where(id: tree_rec.id)
        # if not, join them
        Rails.logger.debug("*** matchedTrees: #{matchedTrees.inspect}")
        if matchedTrees.count == 0
          sector.trees << tree_rec
          sectorsAdded << r
        end
      rescue ActiveRecord::ActiveRecordError => e
        eMsg = I18n.translate('uploads.errors.exception_relating_sector_to_tree', e: e)
        Rails.logger.error("*** #{eMsg}")
        errs << eMsg
      end
    end
    # get current list of related sector for this tree
    allSectors = []
    tree_rec.sectors.each do |s|
      # join tree and sector
      allSectors << s.code
      stacks[IDS_STACK][PROCESSING_SECTOR] << "#{tree_rec.id}-#{s.id}" if !stacks[IDS_STACK][PROCESSING_SECTOR].include?("#{tree_rec.id}-#{s.id}")
    end
    statMsg = (sectorsAdded.length > 0) ? I18n.translate('app.labels.new_sector_relations', sectors: sectorsAdded.join(', ') ) : ''
    if errs.count > 0
      statMsg += ', ' if statMsg.length > 0
      statMsg += errs.join(', ')
      @rowErrs << I18n.translate('app.labels.row_num', num: row_num) + errs.join(', ') if !@phaseTwo
    end

    # generate report record
    rptRec = [row_num]
    rptRec.concat(Array.new(CODE_DEPTH) {''}) # blank out the first four columns of report
    rptRec << '' # blank out the code column of report
    rptRec << ((allSectors.count > 0) ? I18n.translate('app.labels.related_to_sectors', sectors: allSectors.join(', ')) : 'No related sectors.')
    rptRec << statMsg
    @rptRecs << rptRec if !@phaseTwo

    @sectorErrs = true if @rowErrs.count > 0

  end

  def process_sector_relation(val, row_num, stacks)
    errs = []
    tree_rec = stacks[RECS_STACK][PROCESSING_INDICATOR] # get current indicator record from stacks
    explain, text_status, text_msg = Translation.find_or_update_translation(
      @localeRec.code,
      "#{tree_rec.base_key}.explain",
      val
    )

    stacks[IDS_STACK][PROCESSING_SECTOR_EXPLAIN] << "#{tree_rec.id}" if !stacks[IDS_STACK][PROCESSING_SECTOR_EXPLAIN].include?("#{tree_rec.id}")

    if text_status == BaseRec::REC_ERROR
      err_str = text_msg
      errs << err_str
      @rowErrs << err_str if !@phaseTwo
    end

    # generate report record
    rptRec = [row_num]
    rptRec.concat(Array.new(CODE_DEPTH) {''}) # blank out the first four columns of report
    rptRec << '' # blank out the code column of report
    rptRec << "#{I18n.translate('app.labels.sector_related_explain')}: #{explain.value}"
    rptRec << ((errs.count > 0) ? errs.to_s : '')
    @rptRecs << rptRec if !@phaseTwo

    @sectorErrs = true if errs.count > 0
  end


  def process_subject_relation(val, row_num, stacks, new_key)
    errs = []
    tree_rec = stacks[RECS_STACK][PROCESSING_INDICATOR] # get current indicator record from stacks

    splitVal = val.present? ? val.split(/\.+/) : []
    relations = []
    codeAccum = ''
    textAccum = ''
    lastWas = ''
    codeIx = 0
    splitVal.each_with_index do |str, ix|
      numVal = Integer(str) rescue -1
      stripStr = str.strip
      # get code, noting fourth item in code is usually a letter
      isLastCode = (codeIx == 3 && stripStr.length == 1)
      if numVal > -1 || isLastCode
        if lastWas == 'text'
          relations << [codeAccum, textAccum]
          codeAccum = ''
          textAccum = ''
        end
        codeIx += 1
        codeAccum += '.' if codeAccum.length > 0
        if isLastCode
          codeAccum += stripStr
        else
          codeAccum += numVal.to_s
        end
        lastWas = 'code'
      else
        textAccum += '.' if textAccum.length > 0
        textAccum += str
        lastWas = 'text'
        codeIx = 0
      end
    end
    relations << [codeAccum, textAccum]
    subjectsRelated = []
    subjectsJustRelated = []

    cs = stacks[CODES_STACK]
    outcomeCode = "#{cs[0]}.#{cs[1]}.#{cs[2]}.#{cs[3]}"
    Rails.logger.debug("*** code for row: #{outcomeCode}")

    relations.each_with_index do |relate, ix|
      Rails.logger.debug("*** Related Subject Indicator #{relate[0]}: #{relate[1]}")
      begin
        subjCode = Upload::TO_SUBJECT_CODE[new_key.to_sym]
        subjCode = (subjCode == '') ? @subjectRec.code : subjCode
        Rails.logger.debug("*** subjCode: #{subjCode.inspect}")
        subjId = Upload::TO_SUBJECT_ID[new_key.to_sym]
        subjId = (subjId == 0) ? @subjectRec.id : subjId
        subject = Subject.find(subjId)
        throw "Missing sector with id: #{subjId} (code #{subjCode})" if !subject
        related_tree = Tree.find_code_in_tree(@treeTypeRec, @versionRec, subject, @gradeBandRec, relate[0])
        newCode = relate[0]
        codeArray = newCode.split('.')
        eMsg = ''
        Rails.logger.debug("*** relate[0], newCode, codeArray: #{relate[0].inspect} #{newCode.inspect} #{codeArray.inspect}")
        if !related_tree.present? && codeArray.length == 4
          newCode = codeArray.first(3).join('.')
          related_tree = Tree.find_code_in_tree(@treeTypeRec, @versionRec, subject, @gradeBandRec, newCode)
          if related_tree.present?
            eMsg = "WARNING - #{@subjectRec.code}.#{outcomeCode} is related to #{subjCode}.#{newCode} instead of #{subjCode}.#{relate[0]} for Grade Band: #{@gradeBandRec.code}"
          else
            eMsg = "ERROR - cannot relate #{@subjectRec.code}.#{outcomeCode} to #{subjCode}.#{relate[0]} or #{subjCode}.#{newCode} for Grade Band: #{@gradeBandRec.code}"
          end
        elsif !related_tree.present?
          eMsg = "ERROR - cannot relate #{@subjectRec.code}.#{outcomeCode} to #{subjCode}.#{relate[0]} for Grade Band: #{@gradeBandRec.code}"
        end
        if related_tree.present?
          # check the related_trees join table to see if it is joined already
          Rails.logger.debug("*** @rowTreeRec: #{@rowTreeRec.inspect}")
          Rails.logger.debug("*** related_tree: #{related_tree.inspect}")
          itemAllTrees = @rowTreeRec.related_trees
          Rails.logger.debug("*** itemAllTrees: #{itemAllTrees.inspect}")
          matchedTrees = @rowTreeRec.related_trees.where(id: related_tree.id)
          Rails.logger.debug("*** was related matchedTrees: #{matchedTrees.inspect}")
          # if not, join them
          subjectsRelated << subjCode + '.' + newCode
          if matchedTrees.count == 0
            @rowTreeRec.related_trees << related_tree
            subjectsJustRelated << subjCode + '.' + newCode
          end
          Rails.logger.debug("*** now related @rowTreeRec.trees: #{@rowTreeRec.related_trees.inspect}")
        end
        if eMsg != ''
          Rails.logger.error("*** #{eMsg}")
          errs << eMsg
        end
      rescue ActiveRecord::ActiveRecordError => e
        eMsg = "ERROR - relating subject relation: #{e}"
        Rails.logger.error("*** #{eMsg}")
        errs << eMsg
      end
    end

    stacks[IDS_STACK][PROCESSING_SUBJECT_REL] << "#{tree_rec.id}" if !stacks[IDS_STACK][PROCESSING_SUBJECT_REL].include?("#{tree_rec.id}")

    statMsg = ((subjectsJustRelated.length > 0) ? ("Newly Related to: " + subjectsJustRelated.join(', ')) : '')
    if errs.count > 0
      statMsg += ', ' if statMsg.length > 0
      statMsg += errs.join(', ')
      @rowErrs << I18n.translate('app.labels.row_num', num: row_num) + errs.join(', ') if @phaseTwo
    end

    # generate report record
    rptRec = [row_num]
    rptRec.concat(Array.new(CODE_DEPTH) {''}) # blank out the first four columns of report
    rptRec << outcomeCode
    rptRec << ((subjectsRelated.length > 0) ? ("#{@subjectRec.code}.#{outcomeCode} is related to: " + subjectsRelated.join(', ')) : '')
    rptRec << statMsg + ((errs.count > 0) ? ("Errors: #{errs.to_s}") : '')
    @rptRecs << rptRec if @phaseTwo

    @subjectErrs = true if errs.count > 0
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
