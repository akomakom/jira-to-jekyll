require 'uri'
require 'net/http'
require 'optparse'
require 'netrc'
require 'json'
require 'erb'
require 'fileutils'
require 'date'
require 'logger'

@options = {
  :jql => '',
  :dir => 'jekyll',
  :max_results => 1000,
  :loglevel => 'WARN',
  :debughttp => false,
  :max_overall => 1000000000,
  :attachments => false,
  :sslnoverify => false,
}


parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{__FILE__ } [@options]"

  opts.on("--url URL", "JIRA URL (base), eg https://my.domain.name") do |v|
    @options[:url] = v
  end

  opts.on("--jql EXPRESSION", "Optional JQL for issue search, default is '' (all)") do |v|
    @options[:jql] = v
  end

  opts.on("--dir DIRECTORY", "Output directory, default: #{@options[:dir]}") do |v|
    @options[:dir] = v.to_i
  end

  opts.on("--attachments", "Download attachments that do not exist locally, default: #{@options[:attachments]}") do |v|
    @options[:attachments] = true
  end

  opts.on("--max-results N", "API max results to request (per http request), default: #{@options[:max_results]}") do |v|
    @options[:max_results] = v.to_i
  end

  opts.on("--max-overall N", "Stop after processing this many issues overall, default: #{@options[:max_overall]}") do |v|
    @options[:max_overall] = v.to_i
    # don't request more than max also
    @options[:max_results] = [@options[:max_results], @options[:max_overall]].min
  end

  opts.on("--netrc PATH", "Path to netrc file with credentials (~/.netrc is checked automatically).") do |v|
    @options[:netrc] = v
  end

  opts.on("--sslnoverify", "Accept all server SSL certificates (eg: self-signed).  This is dangerous") do |v|
    @options[:sslnoverify] = true
  end

  opts.on("--loglevel LEVEL", "Change log level, default: #{@options[:loglevel]}") do |v|
    @options[:loglevel] = v
  end

  opts.on("--debug-http", "Turn on debug for network requests") do |v|
    @options[:debughttp] = v
  end

  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end
parser.parse!

mandatory = [:url]
missing = mandatory.select{|param| @options[param].nil?}
unless missing.empty?
  puts parser.help
  raise OptionParser::MissingArgument.new(missing.join(', '))    #
end


def prompt(purpose)
  puts "#{purpose}: "
  gets.chomp
end

def make_http(uri)
  http = Net::HTTP.new(uri.host, uri.port)
  if @options[:debughttp]
    http.set_debug_output $stdout
  end
  if @options[:sslnoverify] 
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
  http.use_ssl = true if uri.instance_of? URI::HTTPS
  http
end

def get_json(url)
  uri = URI(url)
  result = nil

  @logger.info "GET: #{uri}"

  http = make_http uri
  http.start() do |http|
    request = Net::HTTP::Get.new uri
    request['Content-Type'] = 'application/json'
    request.basic_auth @options[:user], @options[:pass]
    response = http.request request # Net::HTTPResponse object
    response.value()
    result = JSON.parse(response.body)
  end
  result
end


def get_attachment(url, filename)
  # hack in case of misconfigured jira, where API calls return localhost:8080 URLs
  # replace the url base in the JSON with what we have in options
  json_uri = URI(url)
  uri = URI(@options[:url])
  uri.path = json_uri.path

  @logger.info "Downloading attachment from #{uri} to #{filename}"

  FileUtils.mkdir_p(File.dirname(filename))

  http = make_http uri
  http.start() do |http|
    request = Net::HTTP::Get.new uri
    request.basic_auth @options[:user], @options[:pass]
    response = http.request request # Net::HTTPResponse object
    open(filename, "wb") do |file|
      file.write(response.body)
    end
  end

end


def init_credentials
  netrc = {}
  if @options[:netrc]
    netrc = Netrc.read @options[:netrc]
  else
    netrc = Netrc.read
  end
  creds = netrc[URI(@options[:url]).host]

  if !creds
    puts "Please supply JIRA login credentials with rights to access API and all the issues you care about (see also --netrc)"
    @options[:user] = prompt "Login"
    @options[:pass] = prompt "Password"
  else
    @options[:user], @options[:pass] = creds
  end
  @logger.warn "Using credentials: #{@options[:user]}"
end

def process_issue(issue)
  @logger.debug "Processing issue with content:\n#{JSON.pretty_generate(issue)}"

  begin
    output = @erb_issue.result_with_hash issue
  rescue
    @logger.fatal "Error processing issue #{issue['key']} with content:\n#{JSON.pretty_generate(issue)}"
    raise
  end

  filename = "#{@options[:dir_issues]}/#{issue['key']}.md"
  @logger.debug "Writing issue file to #{filename}"
  File.write filename, output

  if issue['fields'] && issue['fields']['project']
    process_project issue['fields']['project']
  end

  if issue['fields'] && issue['fields']['attachment'] && issue['fields']['attachment'].length > 0
    issue['fields']['attachment'].each do |attachment|
      process_attachment(issue, attachment)
    end
  end
end

def process_attachment(issue, attachment)
  filename = "#{@options[:dir_attachments]}/#{issue['fields']['project']['key']}/#{issue['key']}/#{attachment['filename']}"
  if File.exist? filename and File.size?(filename)
    @logger.debug "Attachment file exists: #{filename}"
  else
    get_attachment(attachment['content'], filename)
  end
end

def process_project(project)
  project_key = project['key']
  if project_key && !@seen_projects.include?(project_key)
    begin
      output = @erb_project.result_with_hash project
    rescue
      @logger.fatal "Error processing project #{project_key} from:\n#{JSON.pretty_generate(project)}"
      raise
    end
    filename = "#{@options[:dir_projects]}/#{project_key}.md"
    @logger.info "Writing project file to #{filename}"
    File.write filename, output
    @seen_projects << project_key
  end

end

@logger = Logger.new(STDOUT)
@logger.level = @options[:loglevel]
@logger.info "Running with options #{@options}"
@options[:dir_issues] = "#{@options[:dir]}/issues"
@options[:dir_projects] = "#{@options[:dir]}/projects"
@options[:dir_attachments] = "#{@options[:dir]}/attachments"
FileUtils.mkdir_p @options[:dir_issues]
FileUtils.mkdir_p @options[:dir_projects]

init_credentials
@erb_issue = ERB.new File.read('issue.erb')
@erb_project = ERB.new File.read('project.erb')
@seen_projects = []

# Step 1: count the issues
result = get_json("#{@options[:url]}/rest/api/2/search?jql=#{@options[:jql]}&maxResults=1&startAt=0")
total = result['total']
@logger.warn "Total issue count: #{total}"

index = 0
while (index < total and index < @options[:max_overall])
  @logger.warn "Requesting #{@options[:max_results]} issues starting at index #{index}"
  result = get_json("#{@options[:url]}/rest/api/2/search?jql=#{@options[:jql]}&maxResults=#{@options[:max_results]}&startAt=#{index}&fields=*all")

  result['issues'].each do |issue| process_issue(issue) end

  index += result['issues'].length
end

