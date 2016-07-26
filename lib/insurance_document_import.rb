require "#{Rails.root}/lib/sales_force/sales_force"

module SalesForce

  class InsuranceDocumentImport < DocumentImport

    def create(record, archive)

      insurance_policy = InsurancePolicy.find_by_legacy_id(record['record_id'])
      document = "#{insurance_policy.class}Document".constantize.new
      document.attachment = File.open(archive[:tempfile])
      document.received_date = record['document_created_date'] || Time.current
      document.import_date = Time.current
      document.size = File.size(archive[:tempfile])
      document.is_original = true
      document.active = true
      document.visible = true
      document.actual_file_name = record['document_name']
      document.original_filename = record['document_name']
      document.extension = File.extname(record['document_name'])
      document.description = record['document_name']
      document.insurance_policy_id = insurance_policy.id
      document.organization_id = insurance_policy.organization.id

      username = if (record['CreatedById'])
                   (User.find_by_legacy_id(record['CreatedById']) || User.find_by_id(300000)).username
                 end
      document.uploaded_by = username

      document.build_inbound_document_workflow(:state => "completed")
      ActiveRecord::Base.observers.disable :workflow_observer do
        document.save
      end

    end

  end

end