# frozen_string_literal: true

RSpec.configure do |config|
  config.add_setting :committee_options
  config.committee_options = {
    schema_path: Rails.root.join('modules', 'mobile', 'docs', 'openapi.json').to_s,
    prefix: '/mobile'
  }
end
