module Admin
  class MatchResultsController < BaseController
    before_action :set_match
    before_action :set_result

    def edit
      prepare_form
    end

    def update
      if @result.confirmed?
        redirect_to admin_match_path(@match), alert: "Сначала откатите подтверждённый результат."
        return
      end

      SeasonTransaction.call(@match.season) do
        @result.reload
        raise MatchConfirmationService::Error, "Сначала откатите подтверждённый результат" if @result.confirmed?
        before = @result.attributes.merge("goals" => @result.goals.map(&:attributes))
        @result.update!(result_params.merge(state: :draft))
        save_goals!
        save_temporary_answers!
        AuditLogger.record!(admin: current_user, action: "match_result.update", auditable: @result,
                            details: { before: before, after: @result.attributes.merge("goals" => @result.goals.reload.map(&:attributes)) })
      end
      redirect_to edit_admin_match_result_path(@match), notice: "Черновик результата сохранён."
    rescue ActiveRecord::RecordInvalid => e
      @result.errors.merge!(e.record.errors) unless e.record == @result
      prepare_form
      render :edit, status: :unprocessable_entity
    rescue MatchConfirmationService::Error => e
      redirect_to edit_admin_match_result_path(@match), alert: e.message
    end

    def preview
      prepare_form
      @rows = MatchConfirmationService.new(match_result: @result, admin: current_user).preview
      redirect_to preview_admin_match_result_path(@match), status: :see_other if request.post?
    rescue MatchConfirmationService::Error, ActiveRecord::RecordInvalid => e
      redirect_to edit_admin_match_result_path(@match), alert: e.message
    end

    def confirm
      MatchConfirmationService.new(match_result: @result, admin: current_user).confirm!
      redirect_to admin_match_path(@match), notice: "Результат подтверждён и таблица пересчитана."
    rescue MatchConfirmationService::Error, ActiveRecord::RecordInvalid => e
      redirect_to edit_admin_match_result_path(@match), alert: e.message
    end

    private
      def set_match
        @match = Match.find(params[:match_id])
      end

      def set_result
        @result = @match.match_result || @match.build_match_result
        @result.save! unless @result.persisted?
      end

      def prepare_form
        @players = Player.order(:name)
        question = @match.temporary_question
        @text_answers = if question&.text?
                          answers = @match.forecasts.where.not(temporary_answer_text: [ nil, "" ]).pluck(:temporary_answer_text).map(&:strip).reject(&:blank?)
                          answers.group_by { |answer| TemporaryQuestionAcceptedAnswer.normalize(answer) }.values.map(&:first).sort
        else
                          []
        end
      end

      def result_params
        params.require(:match_result).permit(:halftime_roma, :halftime_opponent, :fulltime_roma, :fulltime_opponent, :first_score)
      end

      def save_goals!
        @result.goals.destroy_all
        rows = params[:goals].respond_to?(:to_unsafe_h) ? params[:goals].to_unsafe_h.values : Array(params[:goals])

        rows.each_with_index do |raw, index|
          row = raw.respond_to?(:to_h) ? raw.to_h : raw
          scorer_value = row["scorer_value"].to_s
          assist_value = row["assist_value"].to_s
          next if scorer_value.blank?

          own_goal = scorer_value == "own_goal"
          @result.goals.create!(
            scorer_id: own_goal ? nil : scorer_value,
            own_goal: own_goal,
            assist_id: own_goal || assist_value.in?([ "", "none" ]) ? nil : assist_value,
            no_assist: !own_goal && assist_value == "none",
            position: index
          )
        end
      end

      def save_temporary_answers!
        question = @match.temporary_question
        return unless question

        question.update!(voided: !!ActiveModel::Type::Boolean.new.cast(params[:question_voided]))
        question.options.update_all(correct: false)
        question.accepted_answers.destroy_all
        return if question.voided?

        if question.choice?
          ids = Array(params[:correct_option_ids]).reject(&:blank?)
          question.options.where(id: ids).update_all(correct: true)
        else
          Array(params[:correct_text_answers]).reject(&:blank?).each do |text|
            question.accepted_answers.create!(answer_text: text)
          end
        end
      end
  end
end
