# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DebtsApi::V0::DigitalDisputes', type: :request do
  let(:user) { build(:user, :loa3) }

  before do
    sign_in_as(user)
  end

  describe '#create' do
    let(:params) do
      get_fixture_absolute('modules/debts_api/spec/fixtures/digital_disputes/standard_submission')
    end

    it 'returns digital_disputes_params' do
      expect(StatsD).to receive(:increment).with('api.rack.request',
                                                 { tags: ['controller:debts_api/v0/digital_disputes', 'action:create',
                                                          'source_app:not_provided', 'status:200'] })
      expect(StatsD).to receive(:increment).with('api.digital_dispute_submission.initiated')
      post(
        '/debts_api/v0/digital_disputes',
        params: params,
        as: :json
      )

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq(params)
    end

    context 'when invalid contact_information' do
      let(:params) do
        get_fixture_absolute('modules/debts_api/spec/fixtures/digital_disputes/standard_submission')
      end

      it 'returns an error when there is no contact information provided' do
        expect(StatsD).to receive(:increment).with('api.digital_dispute_submission.initiated')
        expect(StatsD).to receive(:increment).with('api.rack.request',
                                                   { tags: ['controller:debts_api/v0/digital_disputes',
                                                            'action:create', 'source_app:not_provided', 'status:422'] })
        expect(StatsD).to receive(:increment).with('api.digital_dispute_submission.failure')

        params.delete('contact_information')

        post(
          '/debts_api/v0/digital_disputes',
          params: params,
          as: :json
        )

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to eq(
          'errors' => {
            'contact_information' => [
              'is missing required information: email, phone_number, address_line1, city'
            ]
          }
        )
      end

      it 'returns an error when invalid email is submitted' do
        params = get_fixture_absolute('modules/debts_api/spec/fixtures/digital_disputes/standard_submission')
        params['contact_information']['email'] = 'invalid_email'

        post(
          '/debts_api/v0/digital_disputes',
          params: params,
          as: :json
        )

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to eq(
          'errors' => {
            'contact_information' => [
              'must include a valid email address'
            ]
          }
        )
      end
    end
  end
end
