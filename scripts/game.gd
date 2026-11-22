extends Node
## Autoload "Game": settings, strings (EN/RU), stats, command-line flags.

const SAVE_PATH := "user://settings.cfg"
const VERSION := "2.0.0"

const SHIP_KINDS := ["battleship", "cruiser", "destroyer", "patrol"]
const SHIP_SIZE := {"battleship": 4, "cruiser": 3, "destroyer": 2, "patrol": 1}
## Russian rules fleet: 1×4, 2×3, 3×2, 4×1
const FLEET := ["battleship", "cruiser", "cruiser", "destroyer", "destroyer", "destroyer", "patrol", "patrol", "patrol", "patrol"]

var lang := "en"
var sfx_volume := 0.8
var music_volume := 0.45
var difficulty := 1          # 0 easy, 1 normal, 2 hard
var mode := "classic"        # classic | arcade
var mood_choice := "random"  # day | sunset | night | random
var quality := "auto"        # auto | low | high
var player_name := ""
var stats := {"wins": 0, "losses": 0, "shots": 0, "hits": 0, "online_wins": 0}

var flags := {}

const STRINGS := {
	"title": ["SEA BATTLE", "МОРСКОЙ БОЙ"],
	"subtitle": ["Fleet vs fleet", "Флот против флота"],
	"play_ai": ["Battle vs AI", "Бой с компьютером"],
	"online": ["Online Duel", "Онлайн-дуэль"],
	"settings": ["Settings", "Настройки"],
	"quit": ["Quit", "Выход"],
	"back": ["Back", "Назад"],
	"start": ["Set Sail!", "В бой!"],
	"opponent": ["Admiral", "Адмирал"],
	"easy": ["Cadet", "Курсант"],
	"normal": ["Captain", "Капитан"],
	"hard": ["Grand Admiral", "Гранд-адмирал"],
	"mode": ["Rules", "Правила"],
	"classic": ["Classic", "Классика"],
	"arcade": ["Arcade (abilities)", "Аркада (способности)"],
	"time": ["Time of day", "Время суток"],
	"day": ["Day", "День"],
	"sunset": ["Sunset", "Закат"],
	"night": ["Night", "Ночь"],
	"random": ["Random", "Случайно"],
	"language": ["Language", "Язык"],
	"sound": ["Sound", "Звук"],
	"music": ["Music", "Музыка"],
	"quality": ["Graphics", "Графика"],
	"auto": ["Auto", "Авто"],
	"low": ["Fast", "Быстро"],
	"high": ["Beautiful", "Красиво"],
	"place_fleet": ["Deploy your fleet", "Расставьте флот"],
	"place_hint": ["Tap a cell to place  •  tap a ship to pick it up", "Нажмите на клетку, чтобы поставить корабль  •  на корабль — чтобы поднять"],
	"rotate": ["Rotate", "Повернуть"],
	"random_place": ["Auto", "Авто"],
	"clear": ["Clear", "Очистить"],
	"ready": ["Ready!", "Готов!"],
	"your_turn": ["YOUR TURN — pick a target", "ВАШ ХОД — выберите цель"],
	"enemy_turn": ["ENEMY IS FIRING", "ПРОТИВНИК СТРЕЛЯЕТ"],
	"waiting_enemy": ["Waiting for the opponent…", "Ждём соперника…"],
	"hit": ["HIT!", "ПОПАЛ!"],
	"miss": ["Miss", "Мимо"],
	"sunk": ["SUNK!", "ПОТОПЛЕН!"],
	"enemy_hit": ["We're hit!", "По нам попали!"],
	"enemy_sunk": ["We lost a ship!", "Мы потеряли корабль!"],
	"victory": ["VICTORY", "ПОБЕДА"],
	"defeat": ["DEFEAT", "ПОРАЖЕНИЕ"],
	"victory_sub": ["The enemy fleet rests on the seabed.", "Вражеский флот пошёл ко дну."],
	"defeat_sub": ["Our fleet has been sunk.", "Наш флот потоплен."],
	"play_again": ["Play again", "Ещё раз"],
	"menu": ["Main menu", "Главное меню"],
	"resume": ["Resume", "Продолжить"],
	"surrender": ["Surrender", "Сдаться"],
	"your_fleet": ["Your fleet", "Ваш флот"],
	"enemy_fleet": ["Enemy fleet", "Флот противника"],
	"shots": ["Shots", "Выстрелы"],
	"accuracy": ["Accuracy", "Точность"],
	"time_s": ["Time", "Время"],
	"radar": ["Radar", "Радар"],
	"torpedo": ["Torpedo", "Торпеда"],
	"airstrike": ["Airstrike", "Авиаудар"],
	"radar_hint": ["Radar: pick the centre of a 3×3 area", "Радар: выберите центр области 3×3"],
	"torpedo_hint": ["Torpedo: pick a row — it runs until it hits", "Торпеда: выберите ряд — она идёт до первого попадания"],
	"airstrike_hint": ["Airstrike: pick the centre of a cross", "Авиаудар: выберите центр креста"],
	"contacts": ["Radar contacts: %d", "Контактов на радаре: %d"],
	"battleship": ["Battleship", "Линкор"],
	"cruiser": ["Cruiser", "Крейсер"],
	"destroyer": ["Destroyer", "Эсминец"],
	"patrol": ["Torpedo boat", "Торпедный катер"],
	"quick_match": ["Quick match", "Быстрая игра"],
	"create_room": ["Create room", "Создать комнату"],
	"join_room": ["Join room", "Войти по коду"],
	"room_code": ["Room code", "Код комнаты"],
	"your_name": ["Your name", "Ваше имя"],
	"searching": ["Searching for an opponent…", "Ищем соперника…"],
	"room_wait": ["Room %s — share the code and wait for a friend", "Комната %s — отправьте код другу и ждите"],
	"connecting": ["Connecting…", "Подключение…"],
	"offline": ["No connection to the server", "Нет связи с сервером"],
	"opponent_found": ["Opponent: %s", "Соперник: %s"],
	"opponent_left": ["Opponent left the battle", "Соперник покинул бой"],
	"room_full": ["That room is full", "Комната заполнена"],
	"waiting_ready": ["Waiting for %s to deploy…", "Ждём, пока %s расставит флот…"],
	"rematch": ["Rematch", "Реванш"],
	"rematch_wait": ["Rematch requested…", "Запрошен реванш…"],
	"cancel": ["Cancel", "Отмена"],
	"vs": ["vs", "против"],
	"you": ["You", "Вы"],
	"ai_name": ["Admiral AI", "Адмирал ИИ"],
	"tap_again": ["Tap the cell again to FIRE", "Нажмите ещё раз — ОГОНЬ"],
	"extra_shot": ["Hit — fire again!", "Попадание — стреляйте ещё!"],
	"stats_line": ["Wins %d  •  Losses %d", "Победы %d  •  Поражения %d"],
	"place_all": ["Place all ships first", "Сначала расставьте все корабли"],
	"cant_place": ["Ships may not touch", "Корабли не должны касаться"],
	"used": ["used", "нет"],
}


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var a := arg.trim_prefix("--")
		if "=" in a:
			flags[a.get_slice("=", 0)] = a.get_slice("=", 1)
		else:
			flags[a] = true
	_load()
	if flags.has("lang"):
		lang = str(flags["lang"])
	if lang == "":
		lang = "ru" if OS.get_locale_language() in ["ru", "uk", "be", "kk"] else "en"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func t(key: String) -> String:
	var row: Array = STRINGS.get(key, [key, key])
	return row[1] if lang == "ru" else row[0]


func ship_name(kind: String) -> String:
	return t(kind)


func flag(name: String) -> bool:
	return flags.has(name)


func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") or flags.has("touch")


func is_low_quality() -> bool:
	if quality == "low":
		return true
	if quality == "high":
		return false
	return OS.has_feature("web") or OS.has_feature("mobile") or RenderingServer.get_video_adapter_name().to_lower().contains("intel")


func pick_mood() -> String:
	if flags.has("mood"):
		return str(flags["mood"])
	if mood_choice == "random":
		return ["day", "day", "sunset", "night"].pick_random()
	return mood_choice


func _load() -> void:
	var c := ConfigFile.new()
	lang = ""
	if c.load(SAVE_PATH) != OK:
		return
	lang = str(c.get_value("s", "lang", ""))
	sfx_volume = float(c.get_value("s", "sfx", sfx_volume))
	music_volume = float(c.get_value("s", "music", music_volume))
	difficulty = int(c.get_value("s", "difficulty", difficulty))
	mode = str(c.get_value("s", "mode", mode))
	mood_choice = str(c.get_value("s", "mood", mood_choice))
	quality = str(c.get_value("s", "quality", quality))
	player_name = str(c.get_value("s", "name", ""))
	var st: Variant = c.get_value("s", "stats", stats)
	if st is Dictionary:
		for k in st:
			stats[k] = st[k]


func save() -> void:
	if flags.has("autotest"):
		return  # tests never touch the player's settings and stats
	var c := ConfigFile.new()
	c.set_value("s", "lang", lang)
	c.set_value("s", "sfx", sfx_volume)
	c.set_value("s", "music", music_volume)
	c.set_value("s", "difficulty", difficulty)
	c.set_value("s", "mode", mode)
	c.set_value("s", "mood", mood_choice)
	c.set_value("s", "quality", quality)
	c.set_value("s", "name", player_name)
	c.set_value("s", "stats", stats)
	c.save(SAVE_PATH)
