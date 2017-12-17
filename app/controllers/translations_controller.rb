class TranslationsController < ApplicationController
  before_action :find_locale
  before_action :find_translation, only: [:show, :edit, :update]

  # TRANSLATION_PARAMS = 'i18n_backend_active_record_translation'
  TRANSLATION_PARAMS = 'translation'

  def index
    if @locale
      @translations = Translation.where(locale: @locale).order('key')
    else
      @translations = Translation.all.order(:key, :locale)
    end
    respond_to do |format|
      format.html
      format.json { render json: @translations}
    end

  end

  def listing2
    @translations = Translation.all.order(:key, :locale)
  end

  def new
    @translation = Translation.new()
  end

  def create
    @translation = Translation.new(translation_params)
    if @translation.value == I18n.t(@translation.key, locale: @translation.locale)
      flash[:alert] = "Your new translation is the same as the default."
      render :new
    else
      if @translation.save
        flash[:success] = "Translation for #{ @key } updated."
        # I18n.backend.reload!
        redirect_to translations_url(@locale)
      else
        render :new
      end
    end
  end

  def show
  end

  def edit
  end

  def update
    if @translation.update(translation_params)
      flash[:notice] = "Translation for #{ @key } updated."
      # I18n.backend.reload!
      redirect_to translations_url(@locale)
    else
      render :edit
    end
  end

  def reload
    I18n.backend.reload!
  end

  def new_layout
    params[:locale_id] = 'en'
    find_locale
    @translations = Translation.where(locale: @locale).order('key')
    render layout: 'responsive1'
  end

  private

  def find_locale
    @locale = params[:locale_id]
  end

  def find_translation
    @translation = Translation.find(params[:id])
  end

  def translation_params
    params.require(TRANSLATION_PARAMS).permit(:locale,
      :key, :value)
  end

end
