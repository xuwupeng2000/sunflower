extends GdUnitTestSuite

func test_new_flowers_and_cat_pot_are_reachable_in_style_tab() -> void:
	var page = load("res://scenes/pot_page.tscn").instantiate()
	add_child(auto_free(page))
	var flower = page.get_node("边框/列表/花")
	var pot = page.get_node("边框/列表/盆")
	flower.set_labels(PackedStringArray(["向日葵", "蝴蝶兰", "君子兰", "仙客来", "长寿花"]), 0)
	pot.set_labels(PackedStringArray(["陶盆", "白瓷", "彩釉盆", "高筒盆", "方盆", "三花猫", "兔子", "刺猬小屋"]), 0)
	assert_int(flower._count()).is_equal(5)
	assert_int(pot._count()).is_equal(8)
	assert_str(flower.get_child(2).text).is_equal("君子兰")
	assert_str(pot.get_child(5).text).is_equal("三花猫")
	for index in 5:
		pot._drag = -pot._card()
		pot._absorb()
	assert_int(pot.index).is_equal(5)
	flower.set_index(3)
	assert_int(flower.index).is_equal(3)
	assert_str(flower.get_child(3).text).is_equal("仙客来")

	flower.set_index(4)
	assert_int(flower.index).is_equal(4)
	assert_str(flower.get_child(4).text).is_equal("长寿花")

	for index in [6,7]:
		pot.set_index(index)
		assert_int(pot.index).is_equal(index)
	assert_str(pot.get_child(6).text).is_equal("兔子")
	assert_str(pot.get_child(7).text).is_equal("刺猬小屋")
