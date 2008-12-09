# Copyright (c) 2007 Todd Willey <todd@rubidine.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

module LiquidFromDatabase
  # Class method that is available in all controllers.
  # Options are {
  #   :model => :liquid_view,
  #   :path_column => :path,
  #   :body_column => :body
  # }
  def renders_liquid_from_database options={}
    options = {
      :model => :liquid_view,
      :path_column => :path,
      :body_column => :body,
      :raise_errors => false
    }.merge(options)
    write_inheritable_attribute :liquid_options, options
    include LiquidFromDatabase::InstanceMethods
    helper :liquid_db
  end

  module InstanceMethods
    # Any controller that called 'renders_liquid_from_database' has
    # this method included, which will try and find the liquid view,
    # and super() up to ActionController::Base#render if not found
    def render options={}, local_assigns = {}, &b

      if options[:without_liquid]
        return super
      end

      path = options[:path] || determine_path(options)
      layout = options.keys.include?(:layout) ? options[:layout] : true
      do_liquid_render(path, layout) || super
    end

    private

    def determine_path options
      if options[:action]
        path_from_action_option(options[:action])
      else
        "/#{controller_name}/#{action_name}"
      end
    end

    def path_from_action_option optval
      where = optval.to_s.gsub(/^\//, '').gsub(/\/$/, '').split('/')
      action = where.pop
      controller = where.empty? ? controller_name : where.join('/')
      "/#{controller}/#{action}"
    end

    def liquid_options
      self.class.read_inheritable_attribute(:liquid_options)
    end

    # This method queries the model from the database and pipes it to liquid
    def do_liquid_render path, layout=true
      unless db_entry = find_template_model_for_path(path)
        return false
      end

      templ = prepare_template_from_model(db_entry)
      render_liquid_template(templ, layout)
    end

    def find_template_model_for_path path
      kls = liquid_options[:model].to_s.camelize.constantize
      kls.send("find_by_#{liquid_options[:path_column]}", path)
    end

    def prepare_template_from_model inst
      Liquid::Template.parse(inst.send(liquid_options[:body_column]))
    end

    def render_liquid_template templ, layout
      render_method = liquid_options[:raise_errors] ? :render! : :render
      filters = [master_helper_module]
      if ff = liquid_options[:filters]
        filters += [ff].flatten
      end
      txt = templ.send(
              render_method,
              assigns_from_controller,
              :filters => filters,
              :registers => {
                :controller => self,
                :request => request,
                :params => params
              }
            )
      log_template_errors(templ)

      # We just call the original render to show the text we want,
      # and pass any template required.
      # 
      # This could probably be changed to @response.body = op,
      # but we would have to work in the layout
      render(:text => txt, :layout => layout, :without_liquid => true)

      return true
    end

    def assigns_from_controller
      rv = {}
      variables = instance_variables
      if respond_to?(:protected_instance_variables)
        variables -= protected_instance_variables 
      end
      variables.each do |ivar|
        rv[ivar[1..-1]] = instance_variable_get(ivar)
      end
      rv
    end

    def log_template_errors(templ)
      if templ.errors and !templ.errors.empty?
        logger.error "\nLiquid Error: #{templ.errors.join("\n")}\n\n"
      end
    end

  end
end
