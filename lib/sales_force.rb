module SalesForce

  require 'zip'

  class DocumentSearch

    attr_accessor :base_path, :source
    attr_reader :results

    def initialize(base_path, source, options = {:limit => nil})

      @base_path = base_path
      @source = source
      @options = options
      @results = nil

    end

    def run

      sql = %!select ld."Id" as document_id, ld."Name" as document_name, ld."CreatedDate" as document_created_date, lr."Id" as record_id,
            lr.* from legacy."#{@source[:documents_table]}" ld join legacy."#{@source[:records_table]}" lr on
            ld."ParentId" = lr."Id" order by ld."CreatedDate" desc!
      sql += " limit #{@options[:limit]}" if @options[:limit]

      @results = ActiveRecord::Base.connection.select_all(sql).to_hash

      @results.each do |result|
        archive = locate_archive(result['document_id'])
        result['archive'] = archive if archive
      end

    end

    def results
      @results.collect { |result| result if result.key?('archive') }
    end

    private

    def locate_archive(document_id)
      Dir.glob("#{self.base_path}/*.zip", File::FNM_CASEFOLD) do |path|
        Zip::File.open(path) do |file|
          file.each do |entry|
            if entry.name =~ /Attachments\/#{document_id}/
              return {'file' => file.name, 'entry' => entry.name}
            end
          end
        end
      end
    end

  end

  class DocumentImport

    def initialize(records)
      @records = records
    end

    def run
      @records.each do |record|
        archive = open(record)
        create(record, archive)
      end
    end

    private

    def open(record)
      tempfile, filename = nil, nil
      Zip::File.open(record['archive']['file']) do |archive|
        entry = archive.glob(record['archive']['entry']).first
        filename = entry.name
        basename = File.basename(filename)
        extension = File.extname(record['document_name'])
        tempfile = Tempfile.new([basename, extension])
        tempfile.binmode
        tempfile.write entry.get_input_stream.read
      end
      {:tempfile => tempfile, :filename => filename}
    end

  end

end