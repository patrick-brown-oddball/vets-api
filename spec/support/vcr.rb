# frozen_string_literal: true

VCR.configure do |c|
  c.cassette_library_dir = 'spec/support/vcr_cassettes'
  c.hook_into :webmock
  # experiencing VCR-induced frustation? uncomment this:
  # c.debug_logger = File.open('vcr.log', 'w')

  c.filter_sensitive_data('<APP_TOKEN>') { Settings.mhv.rx.app_token }
  c.filter_sensitive_data('<AV_KEY>') { VAProfile::Configuration::SETTINGS.address_validation.api_key }
  c.filter_sensitive_data('<DMC_TOKEN>') { Settings.dmc.client_secret }
  c.filter_sensitive_data('<BGS_BASE_URL>') { Settings.bgs.url }
  c.filter_sensitive_data('<EE_PASS>') { Settings.hca.ee.pass }
  c.filter_sensitive_data('<EVSS_AWS_BASE_URL>') { Settings.evss.aws.url }
  c.filter_sensitive_data('<EVSS_BASE_URL>') { Settings.evss.url }
  c.filter_sensitive_data('<EVSS_DVP_BASE_URL>') { Settings.evss.dvp.url }
  c.filter_sensitive_data('<FARADAY_VERSION>') { Faraday::Connection::USER_AGENT }
  c.filter_sensitive_data('<GIDS_URL>') { Settings.gids.url }
  c.filter_sensitive_data('<LIGHTHOUSE_API_KEY>') { Settings.decision_review.api_key }
  c.filter_sensitive_data('<LIGHTHOUSE_API_KEY>') { Settings.lighthouse.facilities.api_key }
  c.filter_sensitive_data('<LIGHTHOUSE_DIRECT_DEPOSIT_HOST>') { Settings.lighthouse.direct_deposit.host }
  c.filter_sensitive_data('<LIGHTHOUSE_BRD_API_KEY>') { Settings.brd.api_key }
  c.filter_sensitive_data('<LIGHTHOUSE_TV_API_KEY>') { Settings.claims_api.token_validation.api_key }
  c.filter_sensitive_data('<LIGHTHOUSE_BASE_URL>') { Settings.lighthouse.benefits_documents.host }
  c.filter_sensitive_data('<MDOT_KEY>') { Settings.mdot.api_key }
  c.filter_sensitive_data('<MHV_HOST>') { Settings.mhv.rx.host }
  c.filter_sensitive_data('<MHV_MR_HOST>') { Settings.mhv.medical_records.host }
  c.filter_sensitive_data('<MHV_MR_X_AUTH_KEY>') { Settings.mhv.medical_records.x_auth_key }
  c.filter_sensitive_data('<MHV_MR_APP_TOKEN>') { Settings.mhv.medical_records.app_token }
  c.filter_sensitive_data('<MHV_X_API_KEY>') { Settings.mhv.medical_records.mhv_x_api_key }
  c.filter_sensitive_data('<MHV_SM_APP_TOKEN>') { Settings.mhv.sm.app_token }
  c.filter_sensitive_data('<MHV_SM_HOST>') { Settings.mhv.sm.host }
  c.filter_sensitive_data('<MPI_URL>') { Settings.mocked_authentication.mvi.url }
  c.filter_sensitive_data('<PD_TOKEN>') { Settings.maintenance.pagerduty_api_token }
  c.filter_sensitive_data('<CENTRAL_MAIL_TOKEN>') { Settings.central_mail.upload.token }
  c.filter_sensitive_data('<PPMS_API_KEY>') { Settings.ppms.api_keys }
  c.filter_sensitive_data('<PRENEEDS_HOST>') { Settings.preneeds.host }
  c.filter_sensitive_data('<VAPROFILE_URL>') { Settings.vet360.url }
  c.filter_sensitive_data('<VETS360_URL>') { Settings.vet360.url }
  c.filter_sensitive_data('<MULESOFT_SECRET>') { Settings.form_10_10cg.carma.mulesoft.client_secret }
  c.filter_sensitive_data('<SHAREPOINT_CLIENT_SECRET>') { Settings.vha.sharepoint.client_secret }
  c.filter_sensitive_data('<ADDRESS_VALIDATION>') { VAProfile::Configuration::SETTINGS.address_validation.url }
  c.filter_sensitive_data('<LIGHTHOUSE_BENEFITS_EDUCATION_RSA_KEY_PATH>') do
    Settings.lighthouse.benefits_education.rsa_key
  end
  c.filter_sensitive_data('<LIGHTHOUSE_BENEFITS_EDUCATION_CLIENT_ID>') do
    Settings.lighthouse.benefits_education.client_id
  end
  c.filter_sensitive_data('<VEIS_AUTH_URL>') { Settings.travel_pay.veis.auth_url }

  c.before_record do |i|
    %i[response request].each do |env|
      next unless i.send(env).headers.keys.include?('Token')

      i.send(env).headers.update('Token' => '<SESSION_TOKEN>')
    end
  end

  c.before_record do |i|
    %i[response request].each do |env|
      next unless i.send(env).headers.keys.include?('Authorization')

      i.send(env).headers.update('Authorization' => 'Bearer <TOKEN>')
    end
  end

  c.register_request_matcher :sm_user_ignoring_path_param do |request1, request2|
    # Matches, ignoring the user id and icn after `/isValidSMUser/` to handle any user id and icn
    # E.g. <HOST>mhvapi/v1/usermgmt/usereligibility/isValidSMUser/10000000/1000000000V000000
    path1 = request1.uri.gsub(%r{/isValidSMUser/.*}, '/isValidSMUser')
    path2 = request2.uri.gsub(%r{/isValidSMUser/.*}, '/isValidSMUser')
    path1 == path2
  end
end
