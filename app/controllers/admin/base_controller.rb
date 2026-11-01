module Admin
  class BaseController < ApplicationController
    before_action :require_admin
    around_action :audit_admin_mutation

    private
      def audit_admin_mutation
        if action_name.in?(%w[create update destroy archive restore activate]) && controller_name.in?(%w[players achievements seasons competitions])
          ActiveRecord::Base.transaction do
            target = instance_variable_get("@#{controller_name.singularize}")
            if target.nil? && params[:id].present?
              model = { "players" => Player, "achievements" => Achievement, "seasons" => Season, "competitions" => Competition }.fetch(controller_name)
              target = model.find(params[:id])
            end
            before = target&.attributes&.dup
            yield
            target = instance_variable_get("@#{controller_name.singularize}")
            if response.status < 400 && target&.errors&.empty?
              AuditLogger.record!(admin: current_user, action: "#{controller_name.singularize}.#{action_name}", auditable: target,
                                  details: { before: before, after: target.attributes })
            end
          end
        else
          yield
        end
      end

      def require_admin
        redirect_to root_path, alert: "Доступ только для администраторов." unless current_user&.admin?
      end
  end
end
