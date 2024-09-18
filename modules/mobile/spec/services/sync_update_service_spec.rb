# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::Profile::SyncUpdateService do
  let(:user) { create(:user, :api_auth) }
  let(:service) { Mobile::V0::Profile::SyncUpdateService.new(user) }

  # DO THIS
  describe '#save_and_await_response' do
    before do
      Flipper.disable(:va_v3_contact_information_service)
    end

    let(:params) { build(:va_profile_address, vet360_id: user.vet360_id, validation_key: nil) }

    context 'when it succeeds after one incomplete status check' do
      let(:transaction) do
        VCR.use_cassette('mobile/profile/get_address_status_complete') do
          VCR.use_cassette('mobile/profile/get_address_status_incomplete') do
            VCR.use_cassette('mobile/profile/put_address_initial') do
              service.save_and_await_response(resource_type: :address, params:, update: true)
            end
          end
        end
      end

      it 'has a completed va.gov async status' do
        expect(transaction.status).to eq('completed')
      end

      it 'has a COMPLETED_SUCCESS vet360 transaction status' do
        expect(transaction.transaction_status).to eq('COMPLETED_SUCCESS')
      end
    end

    context 'when it succeeds after two incomplete checks' do
      let(:transaction) do
        VCR.use_cassette('mobile/profile/get_address_status_complete') do
          VCR.use_cassette('mobile/profile/get_address_status_incomplete_2') do
            VCR.use_cassette('mobile/profile/get_address_status_incomplete') do
              VCR.use_cassette('mobile/profile/put_address_initial') do
                service.save_and_await_response(resource_type: :address, params:, update: true)
              end
            end
          end
        end
      end

      it 'has a completed va.gov async status' do
        expect(transaction.status).to eq('completed')
      end

      it 'has a COMPLETED_SUCCESS vet360 transaction status' do
        expect(transaction.transaction_status).to eq('COMPLETED_SUCCESS')
      end
    end

    context 'when it has not completed within the timeout window (< 60s)' do
      before do
        allow_any_instance_of(Mobile::V0::Profile::SyncUpdateService).to receive(:seconds_elapsed_since).and_return(61)
      end

      it 'raises a gateway timeout error' do
        VCR.use_cassette('mobile/profile/get_address_status_complete') do
          VCR.use_cassette('mobile/profile/get_address_status_incomplete_2') do
            VCR.use_cassette('mobile/profile/get_address_status_incomplete') do
              VCR.use_cassette('mobile/profile/put_address_initial') do
                expect { service.save_and_await_response(resource_type: :address, params:, update: true) }
                  .to raise_error(Common::Exceptions::GatewayTimeout)
              end
            end
          end
        end
      end
    end

    context 'when it fails on a status check returning an error' do
      it 'raises a backend service exception' do
        VCR.use_cassette('mobile/profile/get_address_status_error') do
          VCR.use_cassette('mobile/profile/put_address_initial') do
            expect { service.save_and_await_response(resource_type: :address, params:, update: true) }
              .to raise_error(Common::Exceptions::BackendServiceException)
          end
        end
      end
    end
  end

  # Correct in another PR
  describe '#v2_save_and_await_response' do
    before do
      Flipper.enable(:va_v3_contact_information_service)
      frozen_time = Time.zone.parse('2024-09-16T16:09:37.000Z')
      Timecop.freeze(frozen_time)
    end

  after do
      Flipper.disable(:va_v3_contact_information_service)
    end

    let(:user) { create(:user, :api_auth_v2) }

    let(:params) { build(:va_profile_address_v2, :override, validation_key: nil, id: 577127) }

    # TODO
    # context 'when it succeeds' do
    #   let(:transaction) do
    #     VCR.use_cassette('mobile/profile/v2/get_address_status_complete', allow_playback_repeats: true) do
    #       VCR.use_cassette('mobile/profile/v2/put_address_initial') do
    #         VCR.use_cassette('mobile/profile/v2/person') do
    #           service.save_and_await_response(resource_type: :address, params:, update: true)
    #         end
    #       end
    #     end
    #   end

    #   it 'has a completed va.gov async status' do
    #     expect(transaction.status).to eq('completed')
    #     expect(transaction.transaction_id).to eq('7c198f17-a3b8-415f-b0fd-e19ab1edcf3a')
    #   end

    #   it 'has a COMPLETED_SUCCESS vet360 transaction status' do
    #     expect(transaction.transaction_status).to eq('COMPLETED_SUCCESS')
    #   end
    # end
  end
end
