module BooleanAttributable
  def boolean_attr(*names)
    names.each do |name|
      name = name.to_s.sub(/\??$/, '')
      module_eval <<-DEFINE
        def #{name}=(value) ; @#{name} = value ; end 
        def #{name}!        ; @#{name} = true  ; end 
        def #{name}?        ; ! ! @#{name}     ; end 
      DEFINE
     end
  end
end