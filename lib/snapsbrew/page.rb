module Snapsbrew
  # One page of a list. Enumerate it, or walk to the next page.
  #
  #   page = Snapsbrew.templates.list
  #   page.each { |template| puts template.title }
  #   page = page.next_page while page.next_page?
  class Page
    include Enumerable

    attr_reader :records, :meta

    def initialize(records, meta, &next_page)
      @records = Record.wrap(records || [])
      @meta = Record.wrap(meta || {})
      @next_page = next_page
    end

    def each(&) = records.each(&)

    def next_page?
      !@next_page.nil?
    end

    def next_page
      @next_page&.call
    end

    # Enumerates the records of this page and of each page after it.
    def each_record(&block)
      return enum_for(:each_record) unless block

      page = self
      while page
        page.each(&block)
        page = page.next_page
      end
    end
  end
end
