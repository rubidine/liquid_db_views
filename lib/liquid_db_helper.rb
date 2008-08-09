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

module LiquidDbHelper
  # Render liquid from the database.
  # works like render(:partial => name)
  # opts are :locals and :ignore_not_found
  def liquid_partial path, opts={}

    unless @context # called from erb
      c_kls = @controller.class
      assigns = @assigns.merge(opts[:locals] || {})
    else
      c_kls = @context.registers[:controller].class
      assigns = @context
    end

    path = path.to_s.split('/')
    path.shift if path.first.empty?
    action = path.pop

    cont = path.empty? ? c_kls.to_s.underscore : path.join('/')
    path = "/#{cont}/_#{action}"

    # prime output
    output = opts[:ignore_not_found] ? '' : "NO PARTIAL: #{path}"

    l_opts = c_kls.read_inheritable_attribute :liquid_options
    model = l_opts[:model].to_s.camelize.constantize
    ll = model.send("find_by_#{l_opts[:path_column]}", path)
    if ll
      templ = Liquid::Template.parse(ll.send(l_opts[:body_column]))
      output = templ.render(
                 assigns,
                 :filters => c_kls.master_helper_module,
                 :registers => {:controller => c_kls}
               )
    end

    output
  end
end
