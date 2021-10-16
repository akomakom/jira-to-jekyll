# Jira to Jekyll converter
----
Useful for those situations where you no longer want to maintain a historical (inactive) Jira installation and worry about patching and vulnerabilities.

## Goal

Convert a Jira installation (issue pages) to Jekyll-generated static content that can be self-hosted or hosted via GitHub Pages,
preserving the URL structure for issue pages.

This project automates many of the migration steps, and they break down as follows:

## Step 1: Jira to Markdown Migration (top-level directory in this project)

This is a one-time migration process prior to shutting down the old Jira server.

### Jira issues

`convert.rb` accesses an existing JIRA server with the API and retrieves all (or some) issues, writing them to markdown
files (in `./jekyll//browse/` by default).  
**Run with no args for all options.**

#### Authenticating to Jira

These methods are tried in order:

* `--netrc /path/to/file` (if supplied)
* `~/.netrc` (if exists)
* Interactive prompting for username/password

See [netrc](https://www.gnu.org/software/inetutils/manual/html_node/The-_002enetrc-file.html) docs.

### Some examples:

(see below for general ruby notes)

* Testing with a subset first: `ruby convert.rb ... --max-overall 20`
* JQL (only export a subset): `ruby convert.rb ... --jql "project = MYPROJECT"`
 
This process will create the following:
1. files like `jekyll/issues/XXXX-1234.md`, one per issue (Jekyll renders them to _site/browse/*.html to preserve Jira URLs)    
2. files like `jekyll/projects/XXXX.md`, one per unique project.  These are per-project index pages that are populated by jekyll.

Most of the metadata goes into the front matter section so that layouts can be customized later.  
The layout of output files is defined by `issue.erb` and `project.erb` (but generally should not need changing)

### Attachments

The markdown pages reference attachments, but this process does not retrieve files.  It is faster to do it manually:
 
* Copy the `attachments` directory from your JIRA server to `jekyll/attachments`

## Step 2: Markdown to Jekyll Static Site Build (jekyll subdirectory in this project)

This can be re-run as needed to change the look and feel of the static site.  The migration does not need to be repeated.

The `jekyll/` subtree is a sample Jekyll project that can be customized to your look and feel preferences.

After a satisfactory conversion to markdown (above), you can run jekyll as normal.  
Some customized css/layouts are included,
feel free to customize or use as a starting point.

### Performance

Jekyll can take a while to build the site given a large set of issues. 6+ hours for 32000 issues:
```
Jekyll Feed: Generating feed for posts
                    ...done in 23880.574032243 seconds.
```

You can investigate performance (preferably a subset of your pages) with `--profile`.  
Individual issue page generation is fairly quick.  
Iteration (such as in minima theme's navigation) can exponentially slow down build times because the 
full list of pages shows up in each generated file. It is disabled in `_config.yml` via `header_pages` parameter.



## General ruby notes

This is how I used it (applies to both top-level directory and `jekyll/`)

* Because I want to (possibly) host on GitHub Pages, I am using versions as per https://pages.github.com/versions/
* Easiest way is to use [rbenv](https://github.com/rbenv/rbenv), then:
```shell
rbenv install 2.7.3 # or whatever ruby version you want to use
rbenv shell 2.7.3  #select for this shell (probably not needed because we have a .ruby-version file)

# for conversion step (Step 1):
bundle install
bundle exec ruby convert.rb # see cmd-line options  

# for jekyll (Step 2):
cd jekyll/
bundle install # install gems
bundle exec jekyll s --watch [--incremental] [--profile] # incremental is fast but does not apply structural changes
```
