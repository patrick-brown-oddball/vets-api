# frozen_string_literal: true

require 'medical_records/client'
require 'medical_records/phr_mgr/client'
require 'medical_records/lighthouse_client'

module MyHealth
  class MrController < ApplicationController
    include ActionController::Serialization
    # include MyHealth::MHVControllerConcerns
    service_tag 'mhv-medical-records'

    # skip_before_action :authenticate
    def use_lighthouse
      true
    end

    protected

    def client
      puts "MrController - use_lighthouse: #{use_lighthouse}"
      puts "MrController - current_user.icn: #{current_user.icn}"
      puts current_user
      

      @client ||= use_lighthouse ? MedicalRecords::LighthouseClient.new(current_user.icn) 
      : MedicalRecords::Client.new(session: { user_id: current_user.mhv_correlation_id,
      icn: current_user.icn })
    end

    def phrmgr_client
      @phrmgr_client ||= PHRMgr::Client.new(current_user.icn)
    end

    def authorize
      # raise_access_denied unless current_user.authorize(:mhv_messaging, :access?)
    end

    # def raise_access_denied
    #   # raise Common::Exceptions::Forbidden, detail: 'You do not have access to messaging'
    # end
  end
end
