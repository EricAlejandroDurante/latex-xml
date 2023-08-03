class TranslationsController < ApplicationController
  def new; end

  def create
    translation = Translation.new(file_params)
    if translation.translate
      send_file Rails.root.join(translation.translated_file_path), filename: 'archivo.pdf', type: 'application/pdf'
      # send_file translated_file.path, filename: 'archivo.tex', type: 'application/x-tex'
    else
      @code_title, @code = translation.error
      render :new, { code_title: @code_title, code: @code }
    end
  end

  private

  def file_params
    params.permit(:txt_file, :xml_file)
  end
end