# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'EVSSClaimBaseSerializer' do
  it 'includes :id' do
    expect(data['id']).to eq evss_claim.evss_id.to_s
  end

  it 'includes :date_filed' do
    expect(attributes['date_filed']).to eq Date.strptime(evss_claim.data['date'], '%m/%d/%Y').to_s
  end

  it 'includes :phase_change_date' do
    expect(attributes['phase_change_date']).to eq Date.strptime(
      evss_claim.data['claim_phase_dates']['phase_change_date'], '%m/%d/%Y'
    ).to_s
  end

  it 'includes :min_est_date' do
    expect(attributes['min_est_date']).to eq Date.strptime(evss_claim.data['min_est_claim_date'], '%m/%d/%Y').to_s
  end

  it 'includes :max_est_date' do
    expect(attributes['max_est_date']).to eq Date.strptime(evss_claim.data['max_est_claim_date'], '%m/%d/%Y').to_s
  end

  it 'includes :development_letter_sent' do
    expected_sent = evss_claim.data['development_letter_sent']&.downcase == 'yes'
    expect(attributes['development_letter_sent']).to eq expected_sent
  end

  it 'includes :decision_letter_sent' do
    expected_sent = evss_claim.data['decision_notification_sent']&.downcase == 'yes'
    expect(attributes['decision_letter_sent']).to eq expected_sent
  end

  context 'when yes/no attributes have invalid values' do
    let(:evss_claim) { build(:evss_claim, data: { 'development_letter_sent' => 'Test' }) }

    it 'logs an error message' do
      message = "Expected key EVSS 'development_letter_sent' to be Yes/No. Got 'Test'."
      expect(Rails.logger).to receive(:error).with(message)
      serialize(evss_claim, serializer_class: described_class)
    end
  end

  it 'includes :documents_needed' do
    expect(attributes['documents_needed']).to eq true
  end

  it 'includes :open' do
    expect(attributes['open']).to eq evss_claim.data['claim_complete_date'].blank?
  end

  it 'includes :requested_decision' do
    expect(attributes['requested_decision']).to eq evss_claim.data['waiver5103_submitted']
  end

  it 'includes :claim_type' do
    expect(attributes['claim_type']).to eq evss_claim.data['status_type']
  end

  it 'includes :ever_phase_back' do
    expect(attributes['ever_phase_back']).to eq evss_claim.data['claim_phase_dates']['ever_phase_back']
  end

  it 'includes :current_phase_back' do
    expect(attributes['current_phase_back']).to eq evss_claim.data['claim_phase_dates']['current_phase_back']
  end

  context 'when :updated_at is nil' do
    it 'does not include :updated_at' do
      expect(attributes).not_to have_key('updated_at')
    end
  end

  context 'when :updated_at is present' do
    let(:evss_claim) { build(:evss_claim, updated_at: Time.current) }

    it 'includes :updated_at' do
      expect_time_eq(attributes['updated_at'], evss_claim.updated_at)
    end
  end

  it 'raises NotImplementedError for phase method' do
    expect { EVSSClaimBaseSerializer.new({}).phase }.to raise_error(NotImplementedError)
  end

  it 'raises NotImplementedError for object_data method' do
    expect { EVSSClaimBaseSerializer.new({}).send(:object_data) }.to raise_error(NotImplementedError)
  end
end
