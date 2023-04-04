# frozen_string_literal: true

class StatsdMiddleware
  STATUS_KEY   = 'api.rack.request'
  DURATION_KEY = 'api.rack.request.duration'

  MODULES_APP_NAMES = Set.new %w[
    appeals_api
    apps_api
    claims_api
    coronavirus-research
    mobile
    openid_auth
    test_user_dashboard
    veteran_confirmation
    veteran_verification
  ].freeze

  OTHER_APP_NAMES = Set.new %w[
    unknown
    undefined
  ].freeze

  # Allowlist of vets-website app names. List was generated by running
  # `yarn apps` or `npm run apps` from inside the vets-website dir
  FRONT_END_APP_NAMES = Set.new %w[
    0993-edu-benefits
    0994-edu-benefits
    0996-higher-level-review
    1010cg-application-caregiver-assistance
    10182-board-appeal
    10203-edu-benefits
    1990-edu-benefits
    1990e-edu-benefits
    1990ez-edu-benefits
    1990n-edu-benefits
    1990s-edu-benefits
    1995-edu-benefits
    28-1900-chapter-31
    28-8832-planning-and-career-guidance
    526EZ-all-claims
    5490-edu-benefits
    5495-edu-benefits
    686C-674
    ask-a-question
    auth
    beta-enrollment
    burials
    check-in
    claims-status
    coe
    coronavirus-research
    coronavirus-vaccination
    covid-vaccine
    covid19screen
    dashboard
    dependents-view-dependents
    disability-my-rated-disabilities
    discharge-upgrade-instructions
    facilities
    feedback-tool
    gi
    gi-sandbox
    hca
    letters
    login-page
    medical-copays
    messages
    my-documents
    my-health-account-validation
    order-form-2346
    pensions
    post-911-gib-status
    pre-need
    profile
    proxy-rewrite
    public-outreach-materials
    questionnaire
    questionnaire-list
    request-debt-help-form-5655
    resources-and-support
    search
    search-representative
    secure-messaging
    medical-records
    static-pages
    terms-and-conditions
    vaos
    verify
    veteran-id-card
    veteran-representative
    view-payments
    view-representative
    virtual-agent
    yellow-ribbon
    your-debt
  ].freeze

  SOURCE_APP_NAMES = FRONT_END_APP_NAMES + MODULES_APP_NAMES + OTHER_APP_NAMES

  def initialize(app)
    @app = app
  end

  def call(env)
    start_time = Time.current
    status, headers, response = @app.call(env)
    duration = (Time.current - start_time) * 1000.0

    path_parameters = env['action_dispatch.request.path_parameters']

    # When ActionDispatch middleware is not processed, as is the case when middleware
    # such as Rack::Attack halts the call chain while applying a rate limit, path
    # parameters are not parsed. In this case, we don't have a controller or action
    # for the request.
    #
    # We should never use a dynamic path to apply the tag for the instrumentation,
    # since this will permit a rogue actor to increase the number of time series
    # exported from the process and causes instability in the metrics system. Effort
    # should be taken to track known conditions carefully in alternate metrics. For
    # the case of Rack::Attack rate limits, we can track the number of 429s responses
    # based on component at the reverse proxy layer, or with instrumentation provided
    # by the Rack::Attack middleware (which performs some rudimentary path matching)

    if path_parameters
      controller = path_parameters[:controller]
      action = path_parameters[:action]
      source_app = get_source_app(env)

      instrument_statsd(status, duration, controller, action, source_app)
    end

    [status, headers, response]
  end

  private

  def get_source_app(env)
    source_app = env['HTTP_SOURCE_APP_NAME']

    return 'not_provided' if source_app.nil?
    return source_app if SOURCE_APP_NAMES.include?(source_app)

    # TODO: - Use sentry to notify us instead. It must be done in a rate-limited way
    #        so as not to allow for a malicious client to overflow worker queues
    Rails.logger.warn "Unrecognized value for HTTP_SOURCE_APP_NAME request header... [#{source_app}]"

    'not_in_allowlist'
  end

  def instrument_statsd(status, duration, controller, action, source_app)
    duration_tags = ["controller:#{controller}", "action:#{action}", "source_app:#{source_app}"]
    status_tags = duration_tags + ["status:#{status}"]

    # rubocop:disable Style/RescueModifier
    StatsD.increment(STATUS_KEY, tags: status_tags) rescue nil
    StatsD.measure(DURATION_KEY, duration, tags: duration_tags) rescue nil
    # rubocop:enable Style/RescueModifier
  end
end
