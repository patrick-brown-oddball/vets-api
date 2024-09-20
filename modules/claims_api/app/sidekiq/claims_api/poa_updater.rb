# frozen_string_literal: true

require 'bgs'

module ClaimsApi
  class PoaUpdater < ClaimsApi::ServiceBase
    def perform(power_of_attorney_id) # rubocop:disable Metrics/MethodLength
      poa_form = ClaimsApi::PowerOfAttorney.find(power_of_attorney_id)
      service = BGS::Services.new(
        external_uid: poa_form.external_uid,
        external_key: poa_form.external_key
      )

      ssn = poa_form.auth_headers['va_eauth_pnid']
      file_number = service.people.find_by_ssn(ssn)[:file_nbr] # rubocop:disable Rails/DynamicFindBy
      poa_code = extract_poa_code(poa_form.form_data)

      response = service.vet_record.update_birls_record(
        file_number:,
        ssn:,
        poa_code:
      )

      if response[:return_code] == 'BMOD0001'
        poa_form.status = ClaimsApi::PowerOfAttorney::UPDATED
        # Clear out the error message if there were previous failures
        poa_form.vbms_error_message = nil if poa_form.vbms_error_message.present?

        ClaimsApi::Logger.log('poa', poa_id: poa_form.id, detail: 'BIRLS Success')

        send_notification_email

        ClaimsApi::PoaVBMSUpdater.perform_async(poa_form.id) if enable_vbms_access?(poa_form:)
      else
        poa_form.status = ClaimsApi::PowerOfAttorney::ERRORED
        poa_form.vbms_error_message = "BGS Error: update_birls_record failed with code #{response[:return_code]}"
        ClaimsApi::Logger.log('poa', poa_id: poa_form.id, detail: 'BIRLS Failed', error: response[:return_code])
      end

      poa_form.save
    end

    private

    def enable_vbms_access?(poa_form:)
      poa_form.form_data['recordConsent'] && poa_form.form_data['consentLimits'].blank?
    end

    def send_notification_email
      template_name = "#{appeal_type_name}_received#{appeal.non_veteran_claimant? ? '_claimant' : ''}"
      template_id = Settings.vanotify.services.lighthouse.template_id[template_name]

      if template_id.blank?
        ClaimsApi::Logger.log('poa', poa_id: poa_form.id,
                                     detail: "Could not find VANotify template for #{template_name}")
      end

      vanotify_service.send_email(
        {
          **identifier,
          personalisation: {
            first_name:,
            last_name:,
            representative_type:,
            rep_first_name:,
            rep_last_name:,
            org_name:,
            address1:,
            address2:,
            city:,
            state:,
            zip:,
            email:,
            phone:
          },
          template_id:
        }
      )

      vanotify_service.send_email(
        {
          **identifier,
          personalisation: {
            first_name:,
            last_name:,
            org_name:,
            address1:,
            address2:,
            city:,
            state:,
            zip:,
            phone:
          },
          template_id:
        }
      )
    end

    def vanotify_service
      @vanotify_service ||= VaNotify::Service.new(Settings.vanotify.services.lighthouse.api_key)
    end
  end
end
