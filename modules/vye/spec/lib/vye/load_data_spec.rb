# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

RSpec.describe Vye::LoadData do
  let(:source) { :bdn_feed }
  let(:locator) { 'test' }
  let(:bdn_clone) { FactoryBot.create(:vye_bdn_clone_base) }
  let(:records) do
    {
      profile: {
        ssn: '123456789',
        file_number: ''
      },
      info: {
        file_number: '',
        dob: '19800101',
        mr_status: 'E',
        rem_ent: '3600000',
        cert_issue_date: '19860328',
        del_date: '19960205',
        date_last_certified: '19860328',
        stub_nm: 'JAPPLES',
        rpo_code: '316',
        fac_code: '11907111',
        payment_amt: '0011550',
        indicator: 'A'
      },
      address: {
        veteran_name: 'JOHN APPLESEED',
        address1: '1 Mockingbird Ln',
        address2: 'APT 1',
        address3: 'Houston TX',
        address4: '',
        address5: '',
        zip_code: '77401',
        origin: 'backend'
      },
      awards: [
        {
          award_begin_date: '00000000',
          award_end_date: '19860328',
          training_time: '1',
          payment_date: '19860328',
          monthly_rate: 35.0,
          begin_rsn: '',
          end_rsn: '66',
          type_training: '',
          number_hours: '00',
          type_hours: '',
          cur_award_ind: 'C'
        }
      ]
    }
  end

  describe '::new' do
    it 'can be instantiated' do
      r = described_class.new(source:, locator:, bdn_clone:, records:)

      expect(r).to be_a described_class
      expect(r.valid?).to be(true)
    end

    it 'reports the exception if source is invalid' do
      expect(Rails.logger).to receive(:error).with(/Loading data failed:/)

      r = described_class.new(source: :something_else, locator:, bdn_clone:, records:)

      expect(r.valid?).to be(false)
    end

    it 'reports the exception if locator is blank' do
      expect(Rails.logger).to receive(:error).with(/Loading data failed:/)

      r = described_class.new(source:, locator: nil, bdn_clone:, records:)

      expect(r.valid?).to be(false)
    end

    it 'reports the exception if bdn_clone is blank' do
      expect(Rails.logger).to receive(:error).with(/Loading data failed:/)

      r = described_class.new(source:, locator:, bdn_clone: nil, records:)

      expect(r.valid?).to be(false)
    end

    it 'reports the exception if profile attributes hash is incorrect' do
      expect(Rails.logger).to receive(:error).with(/Loading data failed:/)

      r = described_class.new(source:, locator:, bdn_clone:, records: records.merge(profile: { invalid: 'data' }))

      expect(r.valid?).to be(false)
    end
  end
end
