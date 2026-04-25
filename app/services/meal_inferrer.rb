class MealInferrer
  def self.call(time = Time.current)
    minutes = time.hour * 60 + time.min

    case minutes
    when (4 * 60)...(10 * 60 + 30)       then :breakfast
    when (10 * 60 + 30)...(14 * 60 + 30) then :lunch
    when (14 * 60 + 30)...(17 * 60 + 30) then :snacks
    when (17 * 60 + 30)...(21 * 60 + 30) then :dinner
    else :snacks
    end
  end
end
