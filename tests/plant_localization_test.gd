extends GdUnitTestSuite

func test_all_plant_and_planter_names_translate_and_refresh_without_reconnecting() -> void:
 var original=AlarmStore.language
 var main=load("res://scenes/main.tscn").instantiate()
 add_child(auto_free(main))
 for i in 5:await get_tree().process_frame
 main._sunflower.apply_style(4,7)
 var flower=main._pot_page.get_node("边框/列表/花")
 var pot=main._pot_page.get_node("边框/列表/盆")
 var connections:int=pot.selected.get_connections().size()
 for language in ["zh","en","zh_TW","ja","ko","de","fr","it","es","ru"]:
  var resource=load("res://locale/ui.%s.translation" % language) as Translation
  AlarmStore.language=language
  AlarmStore._apply_locale()
  for i in 3:await get_tree().process_frame
  for index in main._sunflower.FLOWER_KINDS.size():
   var key:String=main._sunflower.FLOWER_KINDS[index].name
   assert_str(str(resource.get_message(key))).is_not_empty()
   assert_str(flower.get_child(index).text).is_equal(str(resource.get_message(key)))
  for index in main._sunflower.POT_KINDS.size():
   var key:String=main._sunflower.POT_KINDS[index].name
   assert_str(str(resource.get_message(key))).is_not_empty()
   assert_str(pot.get_child(index).text).is_equal(str(resource.get_message(key)))
  assert_int(flower.index).is_equal(4)
  assert_int(pot.index).is_equal(7)
  assert_int(pot.selected.get_connections().size()).is_equal(connections)
 AlarmStore.language=original
 AlarmStore._apply_locale()


func test_missing_locale_message_falls_back_to_english_and_chinese_stays_chinese() -> void:
 var original=AlarmStore.language
 var english=Translation.new()
 english.locale="en"
 english.add_message("仅用于测试的缺失译文","English fallback")
 TranslationServer.add_translation(english)
 AlarmStore.language="de"
 AlarmStore._apply_locale()
 assert_str(str(TranslationServer.translate("仅用于测试的缺失译文"))).is_equal("English fallback")
 assert_str(str(TranslationServer.translate("刺猬小屋"))).is_equal("Igelhäuschen")
 AlarmStore.language="zh"
 AlarmStore._apply_locale()
 assert_str(str(TranslationServer.translate("长寿花"))).is_equal("长寿花")
 assert_str(str(TranslationServer.translate("今天"))).is_equal("今天")
 AlarmStore.language="unsupported"
 AlarmStore._apply_locale()
 assert_str(AlarmStore.language).is_equal("en")
 assert_str(str(TranslationServer.translate("长寿花"))).is_equal("Kalanchoe")
 TranslationServer.remove_translation(english)
 AlarmStore.language=original
 AlarmStore._apply_locale()
