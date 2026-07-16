# frozen_string_literal: true

module AlFolioLocal
  # Site-specific password protection for posts and pages.
  #
  # When a post or page front matter contains a non-empty +password+ field,
  # the rendered HTML output is wrapped so that visitors must enter the
  # password before the page content is revealed.
  #
  # The prompt UI and verification script live in +_includes/password/+,
  # keeping this plugin file focused on the Jekyll hook wiring.
  #
  # Usage (front matter):
  #   ---
  #   layout: post
  #   title: Secret Post
  #   password: your_password
  #   ---
  module PostPassword
    BODY_OPEN_RE  = /<body[^>]*>/i.freeze
    BODY_CLOSE_RE = /<\/body>/i.freeze

    PROMPT_INCLUDE = "password/prompt.liquid"
    SCRIPT_INCLUDE = "password/script.liquid"

    class << self
      # Wrap fully rendered HTML with a password prompt.
      #
      # @param output [String] fully rendered HTML (post + layout)
      # @param password [String] the password from front matter
      # @param site [Jekyll::Site] needed to resolve includes
      # @return [String] HTML with password wrapper injected
      def wrap(output, password, site)
        return output unless output.include?("<body")

        prompt_html = render_include(site, PROMPT_INCLUDE, nil)
        script_html = render_include(site, SCRIPT_INCLUDE, password)

        output.sub(BODY_OPEN_RE)  { "#{Regexp.last_match(0)}\n#{prompt_html}" }
              .sub(BODY_CLOSE_RE) { "#{script_html}\n#{Regexp.last_match(0)}" }
      end

      private

      # Render a Jekyll include file through Liquid.
      #
      # @param site [Jekyll::Site]
      # @param include_path [String] relative path inside _includes/
      # @param password [String, nil] injected as Liquid variable +password+
      # @return [String] rendered HTML (empty string on failure)
      def render_include(site, include_path, password)
        source = read_include(site, include_path)
        return "" if source.nil?

        environments = {}
        environments["password"] = password.to_s if password
        context = Liquid::Context.new(environments, {}, { :site => site })

        Liquid::Template.parse(source).render!(context)
      rescue StandardError => e
        Jekyll.logger.warn "PostPassword:", "Failed to render #{include_path}: #{e.message}"
        ""
      end

      # Read an include file's raw source.
      #
      # @param site [Jekyll::Site]
      # @param include_path [String] relative path inside _includes/
      # @return [String, nil] file contents or nil if not found
      def read_include(site, include_path)
        opts = site.file_read_opts || {}
        site.includes_load_paths.each do |base|
          full = Jekyll.sanitized_path(base, include_path)
          return File.read(full, **opts) if File.exist?(full)
        end
        nil
      end
    end
  end
end

# -- Posts ---------------------------------------------------------------------
Jekyll::Hooks.register :posts, :post_render do |post|
  password = post.data["password"].to_s
  next if password.strip.empty?

  post.output = AlFolioLocal::PostPassword.wrap(post.output, password, post.site)
end

# -- Pages ---------------------------------------------------------------------
Jekyll::Hooks.register :pages, :post_render do |page|
  password = page.data["password"].to_s
  next if password.strip.empty?

  page.output = AlFolioLocal::PostPassword.wrap(page.output, password, page.site)
end