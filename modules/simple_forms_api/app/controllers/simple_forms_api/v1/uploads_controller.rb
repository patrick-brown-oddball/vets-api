# frozen_string_literal: true

require 'ddtrace'
require 'simple_forms_api_submission/metadata_validator'
require 'lighthouse/benefits_intake/service'
require 'simple_forms_api/form_remediation/configuration/vff_config'
require 'benefits_intake_service/service'

module SimpleFormsApi
  module V1
    class UploadsController < ApplicationController
      skip_before_action :authenticate, if: :skip_authentication?
      before_action :load_user, if: :skip_authentication?
      skip_after_action :set_csrf_header

      FORM_NUMBER_MAP = {
        '20-10206' => 'vba_20_10206',
        '20-10207' => 'vba_20_10207',
        '21-0845' => 'vba_21_0845',
        '21-0966' => 'vba_21_0966',
        '21-0972' => 'vba_21_0972',
        '21-10210' => 'vba_21_10210',
        '21-4138' => 'vba_21_4138',
        '21-4142' => 'vba_21_4142',
        '21P-0847' => 'vba_21p_0847',
        '26-4555' => 'vba_26_4555',
        '40-0247' => 'vba_40_0247',
        '40-10007' => 'vba_40_10007'
      }.freeze

      UNAUTHENTICATED_FORMS = %w[40-0247 21-10210 21P-0847 40-10007].freeze

      def submit
        Datadog::Tracing.active_trace&.set_tag('form_id', params[:form_number])

        response = submission.submit
        clear_saved_form(params[:form_number])

        render response
      rescue Prawn::Errors::IncompatibleStringEncoding
        raise
      rescue => e
        raise Exceptions::ScrubbedUploadsSubmitError.new(params), e
      end

      def submit_supporting_documents
        return unless SupportingDocuments::Submission::FORMS_WITH_SUPPORTING_DOCUMENTS.include?(params[:form_id])

        submission = SupportingDocuments::Submission.new(@current_user, params)
        submission.submit
      end

      def get_intents_to_file
        existing_intents = intent_service.existing_intents
        render json: {
          compensation_intent: existing_intents['compensation'],
          pension_intent: existing_intents['pension'],
          survivor_intent: existing_intents['survivor']
        }
      end

      private

      def lighthouse_service
        @lighthouse_service ||= BenefitsIntake::Service.new
      end

      def intent_service
        @intent_service ||= SupportingForms::IntentToFile.new(@current_user, params)
      end

      def skip_authentication?
        UNAUTHENTICATED_FORMS.include?(params[:form_number]) || UNAUTHENTICATED_FORMS.include?(params[:form_id])
      end

      def submission
        if intent_service.use_intent_api?
          IntentToFile::Submission.new(@current_user, params)
        elsif LGY::Submission::LGY_API_FORMS.include?(params[:form_number])
          LGY::Submission.new(@current_user, params)
        else
          BenefitsIntake::Submission.new(@current_user, params)
        end
      end
    end
  end
end
