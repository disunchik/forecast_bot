module Admin
  class PlayerRosterImportsController < BaseController
    def new
      @saved_date = Time.iso8601(RomaRosterSource.saved.fetch("retrieved_at"))
    end

    def preview
      snapshot = case params[:source]
      when "live" then RomaRosterSource.live
      when "saved" then RomaRosterSource.saved
      else raise RomaRosterSource::Error, "Выберите источник состава."
      end
      @preview, @preview_token = PlayerRosterImport.preview(snapshot: snapshot, admin: current_user)
      @choices = {}
    rescue RomaRosterSource::Error => e
      @error = e.message
      new
      render :new, status: :unprocessable_entity
    end

    def create
      @preview_token = params[:preview_token]
      @choices = params[:rows].respond_to?(:to_unsafe_h) ? params[:rows].to_unsafe_h : params[:rows]
      counts = PlayerRosterImport.apply!(token: @preview_token, choices: @choices, admin: current_user)
      redirect_to admin_players_path, notice: "Добавлено футболистов: #{counts[:created]}. Сопоставлено с существующими: #{counts[:linked]}."
    rescue PlayerRosterImport::StalePreview => e
      @error = e.message
      new
      render :new, status: :unprocessable_entity
    rescue PlayerRosterImport::Error => e
      @error = e.message
      begin
        @preview = PlayerRosterImport.read(token: @preview_token, admin: current_user)
        @choices = @choices.is_a?(Hash) ? @choices.transform_values { |choice| choice.is_a?(Hash) ? choice.slice("action", "name") : {} } : {}
        render :preview, status: :unprocessable_entity
      rescue PlayerRosterImport::Error
        new
        render :new, status: :unprocessable_entity
      end
    end
  end
end
