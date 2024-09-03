# frozen_string_literal: true

require 'rails_helper'
# require 'committee/schema_validator/open_api_3/response_validator'
require_relative '../../../../support/helpers/rails_helper'

RSpec.describe 'immunizations', :skip_json_api_validation, type: :request do
  include JsonSchemaMatchers
  include Committee::Rails::Test::Methods

  let!(:user) { sis_user(icn: '9000682') }
  let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }

  before do
    Timecop.freeze(Time.zone.parse('2021-10-20T15:59:16Z'))
    allow_any_instance_of(Mobile::V0::LighthouseAssertion).to receive(:rsa_key).and_return(
      OpenSSL::PKey::RSA.new(rsa_key.to_s)
    )
  end

  after { Timecop.return }

  describe 'GET /mobile/v1/health/immunizations' do
    context 'with committee' do
      let(:last_response) { response }
      let(:last_request) { request }

      it 'validates realish schema' do
        RSpec.configure do |config|
          config.add_setting :committee_options
          config.committee_options = {
            schema_path: Rails.root.join('modules', 'mobile', 'docs', 'openapi_committee.yaml').to_s,
            query_hash_key: 'rack.request.query_hash',
            parse_response_by_content_type: true,
            strict_reference_validation: true
          }
        end

        VCR.use_cassette('mobile/lighthouse_health/get_immunizations', match_requests_on: %i[method uri]) do
          get '/mobile/v1/health/immunizations', headers: sis_headers, params: { page: { size: 1 } }
        end

        expect(response.status).to eq(200)
        assert_schema_conform(200)
      end
    end
  end
end