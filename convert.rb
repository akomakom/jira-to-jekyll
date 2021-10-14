require 'uri'
require 'net/http'
require 'optparse'
require 'netrc'
require 'json'
require 'erb'
require 'fileutils'

@options = {:jql => '', :dir => 'jekyll', :max_results => 1000, :debug => false, :max_overall => 1000000000}
parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{__FILE__ } [@options]"

  opts.on("--url URL", "JIRA URL (base)") do |v|
    @options[:url] = v
  end

  opts.on("--jql EXPRESSION", "Optional JQL for issue search (default is '')") do |v|
    @options[:jql] = v
  end

  opts.on("--dir DIRECTORY", "Output directory, default: #{@options[:dir]}") do |v|
    @options[:dir] = v.to_i
  end

  opts.on("--max-results N", "API max results to request (per http request), default: #{@options[:max_results]}") do |v|
    @options[:max_results] = v.to_i
  end

  opts.on("--max-overall N", "Stop after processing this many issues overall, default: #{@options[:max_overall]}") do |v|
    @options[:max_overall] = v.to_i
    @options[:max_results] = [@options[:max_results], @options[:max_overall]].min
  end

  opts.on("--netrc PATH", "Path to netrc file with credentials (HOME is checked automatically).") do |v|
    @options[:netrc] = v
  end

  opts.on("--debug", "Turn on debug") do |v|
    @options[:debug] = v
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

def debug(message)
  if @options[:debug]
    puts "DEBUG: #{message}"
  end
end

def get_json(url)
  uri = URI(url)
  result = nil

  http = Net::HTTP.new(uri.host, uri.port)
  if @options[:debug]
    http.set_debug_output $stdout
  end
  http.use_ssl = true if uri.instance_of? URI::HTTPS
  http.start() do |http|
    debug "GET: #{uri}"
    request = Net::HTTP::Get.new uri
    request['Content-Type'] = 'application/json'
    request.basic_auth @options[:user], @options[:pass]
    response = http.request request # Net::HTTPResponse object
    response.value()
    result = JSON.parse(response.body)
  end
  result
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
  debug "Using credentials: #{@options[:user]}"
end

def process_issue(issue)
  debug "Processing issue with content:\n#{JSON.pretty_generate(issue)}"

  begin
    output = @erb_issue.result_with_hash issue
  rescue
    puts "Error processing issue #{issue['key']} with content:\n#{JSON.pretty_generate(issue)}"
    raise
  end

  filename = "#{@options[:dir_issues]}/#{issue['key']}.md"
  debug "Writing issue file to #{filename}"
  File.write filename, output

  if issue['fields'] && issue['fields']['project']
    process_project issue['fields']['project']
  end
end

def process_project(project)
  debug "Checking for project key in #{project['key']}"
  project_key = project['key']
  if project_key && !@seen_projects.include?(project_key)
    begin
      output = @erb_project.result_with_hash project
    rescue
      puts "Error processing project #{project_key} from:\n#{JSON.pretty_generate(project)}"
      raise
    end
    filename = "#{@options[:dir_projects]}/#{project_key}.md"
    puts "Writing project file to #{filename}"
    File.write filename, output
    @seen_projects << project_key
  end

end

debug "Running with options #{@options}"
@options[:dir_issues] = "#{@options[:dir]}/issues"
@options[:dir_projects] = "#{@options[:dir]}/projects"
FileUtils.mkdir_p @options[:dir_issues]
FileUtils.mkdir_p @options[:dir_projects]

init_credentials
@erb_issue = ERB.new File.read('issue.erb')
@erb_project = ERB.new File.read('project.erb')
@seen_projects = []

# Step 1: count the issues

result = get_json("#{@options[:url]}/rest/api/2/search?jql=#{@options[:jql]}&maxResults=1&startAt=0")
total = result['total']
puts "Total issue count: #{total}"

index = 0
while (index < total and index < @options[:max_overall])
  puts "Requesting #{@options[:max_results]} issues starting at index #{index}"
  result = get_json("#{@options[:url]}/rest/api/2/search?jql=#{@options[:jql]}&maxResults=#{@options[:max_results]}&startAt=#{index}&fields=*all")

  result['issues'].each do |issue| process_issue(issue) end

  index += result['issues'].length
end

