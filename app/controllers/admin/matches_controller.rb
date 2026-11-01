module Admin
  class MatchesController < BaseController
    before_action :set_match, only: %i[show edit update destroy]

    def index
      @filter = params[:filter].presence || "all"
      @season = params[:season_id].present? ? Season.find(params[:season_id]) : active_season
      matches = @season ? @season.matches.includes(:competition, :temporary_question, :match_result).order(forecast_number: :desc).to_a : []
      @matches = case @filter
      when "upcoming" then matches.select { |match| match.scheduled? && match.kickoff_at > Time.current }
      when "open" then matches.select(&:forecast_open?)
      when "closed" then matches.select { |match| match.forecast_closed? && !match.finished? && !match.cancelled? }
      when "finished" then matches.select(&:finished?)
      when "cancelled" then matches.select(&:cancelled?)
      else matches
      end
    end

    def show
    end

    def new
      @match = Match.new(season: active_season, status: :scheduled)
    end

    def create
      @match = Match.new(match_params)
      @match.season ||= active_season

      ActiveRecord::Base.transaction do
        @match.save!
        save_question!(@match)
        AuditLogger.record!(admin: current_user, action: "match.create", auditable: @match, details: { forecast_number: @match.forecast_number })
      end
      redirect_to admin_match_path(@match), notice: "Матч создан."
    rescue ActiveRecord::RecordInvalid => e
      @match.errors.add(:base, e.record.errors.full_messages.to_sentence) if e.record != @match
      render :new, status: :unprocessable_entity
    end

    def edit
    end

    def update
      if @match.match_result&.confirmed?
        redirect_to admin_match_path(@match), alert: "Сначала откатите подтверждённый результат."
        return
      end

      SeasonTransaction.call(@match.season) do
        @match.reload
        raise MatchConfirmationService::Error, "Сначала откатите подтверждённый результат" if @match.match_result&.confirmed?
        old_signature = prediction_signature(@match)
        old_status = @match.status
        before = @match.attributes
        @match.update!(match_params)
        save_question!(@match)
        invalidate = !@match.cancelled? && (old_signature != prediction_signature(@match) || @match.postponed? || old_status == "cancelled")
        if invalidate && @match.forecasts.exists?
          count = @match.forecasts.count
          @match.forecasts.destroy_all
          AuditLogger.record!(admin: current_user, action: "match.forecasts_reset", auditable: @match, details: { count: count, reason: "match_prediction_data_changed" })
        end
        AuditLogger.record!(admin: current_user, action: "match.update", auditable: @match, details: { before: before, after: @match.attributes })
      end
      redirect_to admin_match_path(@match), notice: "Матч обновлён."
    rescue MatchConfirmationService::Error => e
      redirect_to admin_match_path(@match), alert: e.message
    rescue ActiveRecord::RecordInvalid => e
      @match.errors.add(:base, e.record.errors.full_messages.to_sentence) if e.record != @match
      render :edit, status: :unprocessable_entity
    end

    def destroy
      SeasonTransaction.call(@match.season) do
        @match.reload
        if @match.forecasts.exists?
          redirect_to admin_match_path(@match), alert: "Матч с прогнозами нельзя удалить. Используйте статус «Отменён»."
        elsif @match.match_result&.confirmed?
          redirect_to admin_match_path(@match), alert: "Подтверждённый матч нельзя удалить."
        else
          AuditLogger.record!(admin: current_user, action: "match.destroy", auditable: @match, details: { forecast_number: @match.forecast_number })
          @match.destroy!
          redirect_to admin_matches_path, notice: "Матч удалён."
        end
      end
    end

    private
      def set_match
        @match = Match.find(params[:id])
      end

      def match_params
        params.require(:match).permit(:season_id, :competition_id, :forecast_number, :opponent, :venue, :kickoff_at, :status)
      end

      def save_question!(match)
        return unless params.key?(:question_enabled)

        enabled = ActiveModel::Type::Boolean.new.cast(params[:question_enabled])
        unless enabled
          match.temporary_question&.destroy!
          match.association(:temporary_question).reset
          return
        end

        question = match.temporary_question || match.build_temporary_question
        question.assign_attributes(
          text: params[:question_text].to_s.strip,
          question_type: params[:question_type].presence || "choice",
          points: params[:question_points].to_i
        )
        question.save!

        if question.choice?
          options = params[:question_options].to_s.lines.map(&:strip).reject(&:blank?).uniq
          if options.empty?
            question.errors.add(:base, "Добавьте хотя бы один вариант ответа")
            raise ActiveRecord::RecordInvalid.new(question)
          end

          existing = question.options.index_by(&:text)
          question.options.where.not(text: options).destroy_all
          options.each { |text| question.options.create!(text: text) unless existing.key?(text) }
        else
          question.options.destroy_all
        end
      end

      def prediction_signature(match)
        question = match.temporary_question
        [
          match.season_id, match.competition_id, match.forecast_number, match.opponent, match.venue, match.kickoff_at&.to_i,
          question&.text, question&.question_type, question&.points, question&.options&.order(:id)&.pluck(:text)
        ]
      end
  end
end
