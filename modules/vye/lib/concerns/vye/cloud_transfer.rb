# frozen_string_literal: true

module Vye
  module CloudTransfer
    module_function

    def credentials
      Vye.settings.s3.to_h.slice(:region, :access_key_id, :secret_access_key)
    end

    def bucket
      Vye.settings.s3.bucket
    end

    def external_bucket
      Vye.settings.s3.external_bucket
    end

    def s3_client
      Aws::S3::Client.new(**credentials)
    end

    def tmp_dir
      result = Rails.root / "tmp/vye/#{SecureRandom.uuid}"
      result.mkpath
      result
    end

    def tmp_path(filename) = tmp_dir / filename

    def download(filename, prefix: 'scanned')
      response_target = tmp_path filename
      key = "#{prefix}/#{filename}"

      s3_client.get_object(response_target:, bucket:, key:)

      yield response_target
    ensure
      response_target.delete
    end

    def upload(file, prefix: 'processed')
      key = "#{prefix}/#{file.basename}"
      body = file.open('rb')
      content_type = 'text/plain'

      s3_client.put_object(bucket:, key:, body:, content_type:)
    ensure
      body.close
    end

    def upload_report(filename, &)
      path = tmp_path filename
      path.open('w', &)
      upload(path)
    ensure
      path.delete
    end

    def clear_from(bucket_sym: :internal, path: 'processed')
      bucket = { internal: self.bucket, external: external_bucket }[bucket_sym]
      prefix = "#{path}/"
      check_s3_location!(bucket:, path:)

      s3_client
        .list_objects_v2(bucket:, prefix:)
        .contents
        .map { |obj| obj.key unless obj.key.ends_with?('/') }
        .compact
        .each { |key| delete_file_from_bucket(bucket, key) }
    end

    def delete_file_from_bucket(bucket, key)
      s3_client.delete_object(bucket:, key:)
    rescue Aws::S3::Errors::NoSuchBucket,
           Aws::S3::Errors::NoSuchKey,
           Aws::S3::Errors::AccessDenied,
           Aws::S3::Errors::ServiceError => e
      Rails.logger.error "SundownSweep: could not delete #{key} from #{bucket}: #{e.message}"

      raise
    end

    def check_s3_location!(bucket:, path:)
      case bucket
      when external_bucket
        raise ArgumentError, 'invalid external path' unless %w[inbound outbound].include?(path)
      when self.bucket
        raise ArgumentError, 'invalid internal path' unless %w[chunks scanned processed].include?(path)
      else
        raise ArgumentError, 'bucket must be either the internal one or the external one'
      end
    end

    def upload_fixtures
      [
        Vye::Engine.root / "spec/fixtures/bdn_sample/#{bdn_feed_filename}",
        Vye::Engine.root / "spec/fixtures/tims_sample/#{tims_feed_filename}"
      ].each do |file|
        key = "scanned/#{file.basename}"
        body = file.read

        s3_client.put_object(bucket:, key:, body:)
      end
    end

    # We need to clear out two buckets, scanned and chunked.
    # in scanned, we are only concerned with removing 2 files,
    # but in chunked, we want to remove everything.
    def remove_aws_files_from_s3_buckets
      # remove from the scanned bucket
      [Vye::BatchTransfer::TimsChunk::FEED_FILENAME, Vye::BatchTransfer::BdnChunk::FEED_FILENAME].each do |filename|
        delete_file_from_bucket(:internal, "scanned/#{filename}")
      end

      # remove everything from the chunked bucket
      clear_from(path: 'chunks')
    end

    # There's a requirement to deleting deactivated bdns.
    # Because of the RI rules and the performance hit that causes, we start from the
    # bottom of the RI treee and work our way up.
    # We do NOT delete the verifications but rather nullify their reference to parent rows
    # UserInfo and Award.
    def delete_inactive_bdns
      bdn_clone_ids = Vye::BdnClone.where(is_active: nil, export_ready: nil).pluck(:id)
      bdn_clone_ids.each do |bdn_clone_id|
        logger.info("Vye::SundownSweep::ClearDeactivatedBdns#delete_inactive_bdns: processing BdnClone(#{bdn_clone_id})")
        logger.info('Vye::SundownSweep::ClearDeactivatedBdns#delete_inactive_bdns: deleting DirectDepositChanges')
        Vye::DirectDepositChange.joins(:user_info).where(vye_user_infos: { bdn_clone_id: }).in_batches.delete_all
        logger.info('Vye::SundownSweep::ClearDeactivatedBdns#delete_inactive_bdns: deleting AddressChanges')
        Vye::AddressChange.joins(:user_info).where(vye_user_infos: { bdn_clone_id: }).in_batches.delete_all
        logger.info('Vye::SundownSweep::ClearDeactivatedBdns#delete_inactive_bdns: deleting Awards')
        Vye::Award.joins(:user_info).where(vye_user_infos: { bdn_clone_id: }).in_batches.delete_all

        # We're not worried about validations here because it wouldn't be in the table if it wasn't valid
        # rubocop:disable Rails/SkipsModelValidations
        logger.info('Vye::SundownSweep::ClearDeactivatedBdns#delete_inactive_bdns: nullifying verification references')
        Vye::Verification
          .joins(:user_info)
          .where(vye_user_infos: { bdn_clone_id: })
          .in_batches
          .update_all(user_info_id: nil, award_id: nil)
        # rubocop:enable Rails/SkipsModelValidations

        # nuke user infos
        logger.info('Vye::SundownSweep::ClearDeactivatedBdns#delete_inactive_bdns: deleting UserInfos')
        Vye::UserInfo.where(bdn_clone_id:).delete_all

        # nuke bdn_clone
        logger.info('Vye::SundownSweep::ClearDeactivatedBdns#delete_inactive_bdns: deleting BdnClone')
        Vye::BdnClone.find(bdn_clone_id).destroy
      end
    end
  end
end
