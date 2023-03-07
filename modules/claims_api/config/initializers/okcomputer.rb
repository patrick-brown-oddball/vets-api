# frozen_string_literal: true

require 'bgs/service'
require 'mpi/service'
require 'evss/service'

OkComputer.mount_at = false
OkComputer.check_in_parallel = true

class BaseCheck < OkComputer::Check
  # def initialize(version = 'v1')
  #   @version = version
  # end

  protected

  def name
    'Unknown'
  end

  def process_success
    mark_message "#{name} is running"
  end

  def process_failure
    mark_failure
    mark_message "#{name} is unavailable"
  end
end

class EvssCheck < BaseCheck
  def check
    Settings.evss.mock_claims || EVSS::Service.service_is_up? ? process_success : process_failure
  rescue
    process_failure
  end

  protected

  def name
    'EVSS'
  end
end

class MpiCheck < BaseCheck
  def check
    Settings.mvi.mock || MPI::Service.service_is_up? ? process_success : process_failure
  rescue
    process_failure
  end

  protected

  def name
    'MPI'
  end
end

class BgsCheck < BaseCheck
  def initialize(service)
    @service = service
  end

  def check
    service = BGS::Services.new(
      external_uid: 'healthcheck_uid',
      external_key: 'healthcheck_key'
    )
    service.send(@service).healthy? ? process_success : process_failure
  rescue
    process_failure
  end

  protected

  def name
    "BGS #{@service}"
  end
end

class VbmsCheck < BaseCheck
  def check
    connection = Faraday::Connection.new
    connection.options.timeout = 10
    response = connection.get("#{Settings.vbms.url}/vbms-efolder-svc/upload-v1/eFolderUploadService?wsdl")
    response.status == 200 ? process_success : process_failure
  rescue
    process_failure
  end

  protected

  def name
    'VBMS'
  end
end
