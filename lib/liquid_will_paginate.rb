module LiquidWillPaginate
  def request
    @context.registers[:request]
  end

  def params
    @context.registers[:params]
  end

  def url_for opts
    rv = @context.registers[:controller].url_for(opts)
    rv.gsub('page=1', '').gsub(/\?$/, '')
  end
end
