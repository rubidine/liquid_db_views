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
      :body_column => :body
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

      # We have not rendered yet
      rendered = false
      path = nil

      unless options[:without_liquid]
        unless options[:path]
          controller = controller_name
          action = action_name
          if where = options[:action]
            where = where.to_s.split '/'
            action = where.pop
            unless where.empty?
              controller = where.join('/')
            end
          end
          path = "/#{controller}/#{action}"
        else
          path = options[:path]
        end

        rendered = do_liquid_render(
                     path,
                     options.keys.include?(:layout) ? options[:layout] : true
                   )
      end

      # Bubble Up if we didn't find a template
      if !rendered
        super
      end
    end

    # This method queries the model from the database and pipes it to liquid
    def do_liquid_render path, layout=true
      liquid_options = self.class.read_inheritable_attribute :liquid_options

      kls = liquid_options[:model].to_s.camelize.constantize
      ll = kls.send("find_by_#{liquid_options[:path_column]}", path)
      return false unless ll

      templ = Liquid::Template.parse(ll.send(liquid_options[:body_column]))
      add_variables_to_assigns
      op = templ.render(
             @assigns,
             :filters => master_helper_module,
             :registers => {:controller => self}
           )

      if templ.errors and !templ.errors.empty?
        logger.error "\nLiquid Error: #{templ.errors.join("\n")}\n\n"
        # should we return false here?
        # I think not, since we actually have a template, it just didn't work
        #
        # XXX maybe have a :raise_errors => true option to raise
        # a specific error when this happens, in case the editing functions
        # have a rollback feature.
      end

      # We just call the original render to show the text we want,
      # and pass any template required.
      # 
      # This could probably be changed to @response.body = op,
      # but we would have to work in the layout
      render(:text => op, :layout => layout, :without_liquid => true)

      return true
    end

  end
end
