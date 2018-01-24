module ApplicationHelper

  # subject select options built for options_for_select
  def subjectsOptions(selected_id)
    # ret = [['All', '']]
    ret = []
    Subject.all.each do |s|
      # ret << [ @translations["sector.#{s.code}.name"], s.id ]
      ret << [s.code, s.id]
    end
    return ret
  end

  # grade band select options built for options_for_select
  def gradeBandsOptions(selected_id)
    # ret = [['All', '']]
    ret = []
    GradeBand.all.each do |gb|
      # ret << [ @translations["sector.#{s.code}.name"], s.id ]
      ret << [gb.code, gb.id]
    end
    return ret
  end

  # sectors select options built for options_for_select
  def sectorsOptions(selected_id, transl)
    ret = [['All', '']]
    Sector.all.each do |s|
      ret << [ transl["sector.#{s.code}.name"], s.id ]
    end
    return ret
  end


end
