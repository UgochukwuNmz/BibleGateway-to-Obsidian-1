#!/usr/bin/env ruby

require 'uri'
require 'net/http'
require 'optparse'
require 'colorize'
require 'clipboard'
require 'nokogiri'

# Constants
VERSION = '1.5.0'.freeze
DEFAULT_VERSION = 'NKJV'.freeze
FETCH_READ_TIMEOUT = 10
FETCH_OPEN_TIMEOUT = 30

# Parses command-line options
def parse_options
  opts = {
    boldwords: false,
    copyright: false,
    headers: true,
    footnotes: false,
    verbose: false,
    newline: true,
    numbering: true,
    crossrefs: false,
    filename: '',
    version: DEFAULT_VERSION
  }

  OptionParser.new do |o|
    o.banner = 'Usage: bg2md.rb [options] reference'
    o.on('-b', '--boldwords', 'Render words of Jesus in bold') { opts[:boldwords] = true }
    o.on('-c', '--copyright', 'Include copyright notice') { opts[:copyright] = true }
    o.on('-e', '--headers', 'Include headers in the output') { opts[:headers] = false }
    o.on('-f', '--footnotes', 'Include footnotes') { opts[:footnotes] = true }
    o.on('-i', '--info', 'Display verbose output') { opts[:verbose] = true }
    o.on('-l', '--newline', 'Use new lines for chapters and verses') { opts[:newline] = false }
    o.on('-n', '--numbering', 'Include verse and chapter numbers') { opts[:numbering] = false }
    o.on('-r', '--crossrefs', 'Include cross-references') { opts[:crossrefs] = true }
    o.on('-t', '--test FILENAME', 'Use local file for input instead of fetching online') { |f| opts[:filename] = f }
    o.on('-v', '--version VERSION', "Bible version (default: #{DEFAULT_VERSION})") { |v| opts[:version] = v }
    o.on_tail('-h', '--help', 'Display this help screen') { puts o; exit }
  end.parse!

  opts
end

def exit_on_error(response)
  unless response.is_a?(Net::HTTPSuccess)
    puts "Error: Received HTTP response code #{response.code}"
    exit(1) # Exits the script with a status code indicating an error.
  end
end

def fetch_data(opts)
  if opts[:filename].empty?
    uri = URI('https://www.biblegateway.com/passage/')
    uri.query = URI.encode_www_form(search: ARGV[0], version: opts[:version], interface: 'print')
    puts "Fetching: #{uri}" if opts[:verbose]

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https', read_timeout: FETCH_READ_TIMEOUT, open_timeout: FETCH_OPEN_TIMEOUT) do |http|
      http.get(uri)
    end

    exit_on_error(response) unless response.is_a?(Net::HTTPSuccess)
    response.body.force_encoding('utf-8')
  else
    puts "Using local file: #{opts[:filename]}" if opts[:verbose]
    File.read(opts[:filename], encoding: 'utf-8')
  end
end

def process_data(data, opts)
  doc = Nokogiri::HTML(data)
  formatted_passage = ""
  first_verse_detected = false  # Flag to track if the first verse is detected

  elements = doc.css('.passage-content .text, h3 .text').map do |element|
    type = element.name == 'span' && element.parent.name == 'h3' ? :header : :text
    inner_html = element.inner_html
    { type: type, content: element, text: clean_text(inner_html) }
  end

  elements.each do |element|
    if element[:type] == :header
      formatted_passage += "\n## #{element[:text]}\n"
      first_verse_detected = false  # Reset flag at each new chapter heading
    else
      verse_number = element[:content].at_css('.versenum')&.text&.strip
      text = element[:text]

      # Manually assign '1' to the first verse if no verse number is detected and it's the first text element
      if verse_number.nil? && !first_verse_detected
        verse_number = '1'
        first_verse_detected = true
      elsif verse_number
        first_verse_detected = true  # Set flag when first verse number is detected
      end

      if verse_number
        formatted_passage += "\n###### v#{verse_number}\n"
        text = text.sub(/^#{Regexp.quote(verse_number)}/, '')
      end

      formatted_passage += "#{text}\n"
    end
  end

  puts "Formatted passage:\n#{formatted_passage}" if opts[:verbose]

  title = doc.css("h3 .text").first.text.strip rescue "No title found"
  version = doc.at_css(".version-NKJV").content.strip.match(/version-(\w+)/)[1] rescue "Unknown version"

  { title: title, version: version, passage: formatted_passage.strip }
end



# Helper method to clean text by removing cross-references and footnotes
def clean_text(html)
  # Remove <sup> tags used for cross-references and other unwanted tags
  doc = Nokogiri::HTML.fragment(html)
  doc.css('sup, span.chapternum').remove

  # Convert italics
  doc.search('i, em').each { |tag| tag.replace("*#{tag.text}*") }

  # Remove any remaining HTML tags and return text
  doc.text.gsub(/\s{2,}/, ' ').strip
end


def remove_ansi_codes(text)
  text.gsub(/\e\[([;\d]+)?m/, '')
end


def format_output(extracted_info, opts)
  output_text = "#{extracted_info[:passage]}"
  puts remove_ansi_codes(output_text)  # Ensuring no ANSI codes if you still want to clean them
end

def main
  opts = parse_options

  if ARGV.empty?
    puts "Error: Reference must be provided.".colorize(:red)
    exit
  end

  data = fetch_data(opts)
  extracted_info = process_data(data, opts)
  format_output(extracted_info, opts)
end

main if __FILE__ == $PROGRAM_NAME
