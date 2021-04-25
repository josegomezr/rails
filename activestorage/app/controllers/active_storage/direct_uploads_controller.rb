# frozen_string_literal: true

# Creates a new blob on the server side in anticipation of a direct-to-service upload from the client side.
# When the client-side upload is completed, the signed_blob_id can be submitted as part of the form to reference
# the blob that was created up front.
class ActiveStorage::DirectUploadsController < ActiveStorage::BaseController
  def create
    blob = ActiveStorage::Blob.create_before_direct_upload!(**blob_args)
    render json: direct_upload_json(blob)
  end

  def generate_multipart_url
    blob = ActiveStorage::Blob.find(params[:id])
    blob.service_generate_upload_id_for_multipart!
    render json: direct_upload_multipart_part_json(blob, part_number: params[:part_number], **multipart_url_args)
  end

  def complete_multipart
    blob = ActiveStorage::Blob.find(params[:id])
    blob.service_complete_multipart_upload

    render json: direct_upload_json(blob)
  end

  def abort_multipart
    blob = ActiveStorage::Blob.find(params[:id])
    blob.service_abort_multipart_upload
    blob.destroy!

    head :no_content
  end

  private
    def blob_args
      params.require(:blob).permit(:filename, :byte_size, :checksum, :content_type, metadata: {}).to_h.symbolize_keys
    end

    def multipart_url_args
      params.require(:blob).permit(:byte_size, :checksum).to_h.symbolize_keys
    end

    def direct_upload_json(blob)
      blob.as_json(root: false, methods: :signed_id).merge(direct_upload: {
        url: blob.service_url_for_direct_upload,
        headers: blob.service_headers_for_direct_upload
      })
    end

    def direct_upload_multipart_part_json(blob, part_number:, byte_size:, checksum:)
      url, headers = blob.service_url_for_multipart_upload(part_number, byte_size: byte_size, checksum: checksum)
      blob.as_json(root: false, methods: :signed_id).merge(direct_upload: {
        url: url,
        header: headers
      })
    end
end
