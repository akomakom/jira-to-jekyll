# Jira to Jekyll converter
----
Useful for those situations where you no longer want to maintain a historical (inactive) Jira installation and worry about patching and vulnerabilities.

## Goal

Convert a Jira installation (issue pages) to Jekyll-generated static content that can be self-hosted or hosted via GitHub Pages.

This project automates many of the migration steps, and they break down as follows:

## Step 1: Jira to Markdown (top-level directory)

### Jira issues

`convert.rb` accesses an existing JIRA server with the API and retrieves all (or some) issues, writing them to markdown
files (in `./jekyll//browse/` by default).  
**Run with no args for all options.**
Credential entry interactively or via `.netrc` is supported.

This process will create files like `jekyll/browse/XXXX-1234.md`, one per issue.  Most of the metadata goes
into the front matter section so that layouts can be customized later.  The layout of output files is defined by `issue.erb`

### Attachments

The markdown pages reference attachments, but this process does not retrieve files.  It is faster to do it manually:
 
* Copy the `attachments` directory from your JIRA server to `jekyll/attachments`

## Step 2: Markdown to Jekyll (jekyll subdirectory)

The `jekyll/` subtree is a sample Jekyll project that can be customized to your look and feel preferences.

After a satisfactory conversion to markdown (above), you can run jekyll as normal.  Some customized css/layouts are included,
feel free to customize or use as a starting point


## General ruby notes

This is how I used it (applies to both top-level directory and `jekyll/`)

* Because I want to (possibly) host on GitHub Pages, I am using versions as per https://pages.github.com/versions/
* Easiest way is to use [rbenv](https://github.com/rbenv/rbenv), then:
```shell
rbenv install 2.7.3 # or whatever you want to use
rbenv shell 2.7.3  #select for this shell

# for conversion step:
bundle install
bundle exec ruby convert.rb  

# for jekyll:
cd jekyll/
bundle install # install gems
bundle exec jekyll s --watch [--incremental] # incremental is fast but does not apply structural changes
```
