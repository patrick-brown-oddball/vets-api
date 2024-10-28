# frozen_string_literal: true

require_relative '../../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::Appointments::Facilities::Clinics', type: :request do
  include JsonSchemaMatchers

  let!(:user) { sis_user(icn: '24811694708759028') }

  before do
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
    Flipper.enable(:va_online_scheduling_use_vpg)
    Flipper.enable(:va_online_scheduling_enable_OH_slots_search)
    Flipper.disable(:va_online_scheduling_vaos_alternate_route)
  end

  describe 'GET /mobile/v0/appointments/facilities/:facility_id/clinics', :aggregate_failures do
    context 'using VPG' do
      context 'when both facility id and service type is found' do
        let(:facility_id) { '983' }
        let(:params) { { service_type: 'audiology' } }

        it 'returns 200' do
          VCR.use_cassette('mobile/appointments/get_facility_clinics_200_vpg', match_requests_on: %i[method uri]) do
            get "/mobile/v0/appointments/facilities/#{facility_id}/clinics", params:, headers: sis_headers

            expect(response).to have_http_status(:ok)
            expect(response.body).to match_json_schema('clinic')
          end
        end
      end

      context 'when facility id is not found' do
        let(:facility_id) { '999AA' }
        let(:params) { { service_type: 'audiology' } }

        it 'returns 200 with empty response' do
          VCR.use_cassette('mobile/appointments/get_facility_clinics_bad_facility_id_200_vpg',
                           match_requests_on: %i[method uri]) do
            get "/mobile/v0/appointments/facilities/#{facility_id}/clinics", params:, headers: sis_headers

            expect(response).to have_http_status(:ok)
            expect(response.parsed_body['data']).to eq([])
          end
        end
      end

      context 'when service type is not found' do
        let(:facility_id) { '983' }
        let(:params) { { service_type: 'badservice' } }

        it 'returns bad request' do
          VCR.use_cassette('mobile/appointments/get_facility_clinics_bad_service_400_vpg',
                           match_requests_on: %i[method uri]) do
            get "/mobile/v0/appointments/facilities/#{facility_id}/clinics", params:, headers: sis_headers

            expect(response).to have_http_status(:bad_request)
            expect(JSON.parse(response.parsed_body.dig('errors', 0, 'source',
                                                       'vamfBody'))['message'])
              .to eq('clinicalService: param is invalid')
          end
        end
      end
    end
  end

  describe 'GET /mobile/v0/appointments/facilities/{facililty_id}/slots', :aggregate_failures do
    context 'when both facility id and clinic id is found' do
      let(:facility_id) { '983' }
      let(:params) do
        {
          start_date: '2021-10-26T00:00:00Z',
          end_date: '2021-12-30T23:59:59Z',
          clinic_id: '1081'
        }
      end

      it 'returns 200' do
        VCR.use_cassette('mobile/appointments/get_available_slots_vpg_200', match_requests_on: %i[method uri]) do
          get "/mobile/v0/appointments/facilities/#{facility_id}/slots", params:,
                                                                         headers: sis_headers
          expect(response).to have_http_status(:ok)
          expect(response.body).to match_json_schema('clinic_slot')
          slot = JSON.parse(response.body)['data'][1]
          expect(slot['id']).to eq('3230323131303236323133303A323032313130323632323030')
          expect(slot['type']).to eq('clinic_slot')
          expect(slot['attributes']['locationId']).not_to be_nil
          expect(slot['attributes']['practitionerName']).not_to be_nil
          expect(slot['attributes']['clinicIen']).not_to be_nil
        end
      end
    end

    context 'when clinic_id and clinical_service are not given' do
      let(:facility_id) { '983' }

      it 'returns 400 error' do
        get "/mobile/v0/appointments/facilities/#{facility_id}/slots", params: {},
                                                                       headers: sis_headers

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['errors'][0]['detail'])
          .to eq('clinic_id or clinical_service is required.')
      end
    end

    context 'with a upstream service 500 response' do
      let(:facility_id) { '983' }
      let(:clinic_id) { '1081' }
      let(:params) { { start_date: '2021-10-01T00:00:00Z', end_date: '2021-12-31T23:59:59Z' } }

      context 'using VPG' do
        it 'returns a 502 error' do
          VCR.use_cassette('mobile/appointments/get_available_slots_vpg_500', match_requests_on: %i[method uri]) do
            get "/mobile/v0/appointments/facilities/#{facility_id}/clinics/#{clinic_id}/slots", params:,
                                                                                                headers: sis_headers
            expect(response).to have_http_status(:bad_gateway)
            expect(response.body).to match_json_schema('errors')
          end
        end
      end
    end
  end

  describe 'GET /mobile/v0/appointments/facilities/{facililty_id}/clinics/{clinic_id}/slots', :aggregate_failures do
    context 'when both facility id and clinic id is found' do
      let(:facility_id) { '983' }
      let(:clinic_id) { '1081' }
      let(:params) { { start_date: '2021-10-26T00:00:00Z', end_date: '2021-12-30T23:59:59Z' } }

      context 'using VPG' do
        it 'returns 200' do
          VCR.use_cassette('mobile/appointments/get_available_slots_vpg_200', match_requests_on: %i[method uri]) do
            get "/mobile/v0/appointments/facilities/#{facility_id}/clinics/#{clinic_id}/slots", params:,
                                                                                                headers: sis_headers
            expect(response).to have_http_status(:ok)
            expect(response.body).to match_json_schema('clinic_slot')

            slot = JSON.parse(response.body)['data'][1]
            expect(slot['id']).to eq('3230323131303236323133303A323032313130323632323030')
            expect(slot['type']).to eq('clinic_slot')
            expect(slot['attributes']['locationId']).not_to be_nil
            expect(slot['attributes']['practitionerName']).not_to be_nil
            expect(slot['attributes']['clinicIen']).not_to be_nil
          end
        end
      end
    end

    context 'with a upstream service 500 response' do
      let(:facility_id) { '983' }
      let(:clinic_id) { '1081' }
      let(:params) { { start_date: '2021-10-01T00:00:00Z', end_date: '2021-12-31T23:59:59Z' } }

      context 'using VPG' do
        it 'returns a 502 error' do
          VCR.use_cassette('mobile/appointments/get_available_slots_vpg_500', match_requests_on: %i[method uri]) do
            get "/mobile/v0/appointments/facilities/#{facility_id}/clinics/#{clinic_id}/slots", params:,
                                                                                                headers: sis_headers
            expect(response).to have_http_status(:bad_gateway)
            expect(response.body).to match_json_schema('errors')
          end
        end
      end
    end
  end
end
