module Off
  FoodResult = Struct.new(
    :barcode, :name, :brand,
    :calories, :protein, :carbs, :fat, :fiber,
    :serving_size, :serving_label,
    keyword_init: true
  )
end
