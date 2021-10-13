# Jira to Jekyll converter
----
Useful for those situations where you no longer want to maintain a Jira installation and worry about patching and vulnerabilities.
This project automates many of the migration steps, and they break down as follows:

## Jira to Markdown

### Jira issues

`convert.rb` accesses an existing JIRA server with the API and retrieves all (or some) issues, writing them to markdown
files (in `./jekyll//browse/` by default).  
**Run with no args for all options.**
Credential entry interactively or via `.netrc` is supported.

This process will create files like `jekyll/browse/XXXX-1234.md`, one per issue.  Most of the metadata goes
into the front matter section so that layouts can be customized later.

### Attachments

The markdown pages reference attachments, but this process does not retrieve files.  It is faster to do it manually:
 
* Copy the `attachments` directory from your JIRA server to `jekyll/attachments`

## Markdown to Jekyll

The `jekyll/` subtree is a sample Jekyll project that can be customized to your look and feel preferences.

After a satisfactory conversion to markdown (above), you can run jekyll as normal.  Some customized css/layouts are included,
feel free to customize or use as a starting point


## General ruby notes

This is how I used it (applies to both top-level directory and `jekyll/`)

* Because I want to (possibly) host on GitHub Pages, so I am using versions as per https://pages.github.com/versions/
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