class_name GameWorld
extends RefCounted
## Единый источник правды о мире: размеры, высоты, маски (озеро, деревня,
## руины, тропы, плотность леса).

const TERRAIN_SIZE := 520.0
const TERRAIN_SEGMENTS := 192
const WATER_LEVEL := 0.6

const VILLAGE_CENTER := Vector2(0.0, 0.0)
const VILLAGE_RADIUS := 26.0
const VILLAGE_HEIGHT := 3.0

const LAKE_CENTER := Vector2(-150.0, -40.0)
const LAKE_RADIUS := 80.0
const LAKE_DEPTH := 6.0

const HILL_CENTER := Vector2(140.0, -150.0)
const HILL_RADIUS := 60.0
const HILL_HEIGHT := 17.0

## v5.0: скальный массив с пещерой (северо-восток долины)
const CAVE_CENTER := Vector2(115.0, 118.0)
const CAVE_RADIUS := 20.0

## v5.0: плато готического замка (юго-запад, за озером)
const CASTLE_CENTER := Vector2(-152.0, 158.0)
const CASTLE_RADIUS := 38.0
const CASTLE_HEIGHT := 12.0

## v10.0: Готическая башня на западной дороге (холм-курган)
const TOWER_CENTER := Vector2(-62.0, 52.0)
const TOWER_RADIUS := 16.0
const TOWER_HEIGHT := 6.5

## v10.0: деревня № 2 «Каменный Форд» у подножия замкового плато
const HAMLET_CENTER := Vector2(-108.0, 122.0)
const HAMLET_RADIUS := 26.0
const HAMLET_HEIGHT := 8.0

## v10.0: ритуальный круг культистов в северо-восточном лесу
const RITUAL_CENTER := Vector2(72.0, 62.0)
const RITUAL_RADIUS := 15.0

const PLAYER_SPAWN := Vector3(0.0, 3.6, 22.0)

## Направление на луну (v9.1: луна — на куполе неба, направление
## свободное). СЕВЕРО-ЗАПАД, высота ~28°: со спавна игрока (юг деревни,
## взгляд на север к таверне) луна видна слева над крышами — раньше
## стояла на юго-западе ЗА СПИНОЙ игрока.
const MOON_DIR := Vector3(-0.557, 0.476, -0.688)

static var _base_n: FastNoiseLite
static var _detail_n: FastNoiseLite
static var _forest_n: FastNoiseLite


static func base_noise() -> FastNoiseLite:
        if _base_n == null:
                _base_n = FastNoiseLite.new()
                _base_n.seed = 20240
                _base_n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
                _base_n.frequency = 0.012
                _base_n.fractal_octaves = 4
                _base_n.fractal_gain = 0.45
        return _base_n


static func detail_noise() -> FastNoiseLite:
        if _detail_n == null:
                _detail_n = FastNoiseLite.new()
                _detail_n.seed = 9917
                _detail_n.noise_type = FastNoiseLite.TYPE_SIMPLEX
                _detail_n.frequency = 0.06
                _detail_n.fractal_octaves = 2
        return _detail_n


## Маска леса (-1..1): кластеры ельника с полянами.
static func forest_noise() -> FastNoiseLite:
        if _forest_n == null:
                _forest_n = FastNoiseLite.new()
                _forest_n.seed = 77123
                _forest_n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
                _forest_n.frequency = 0.016
                _forest_n.fractal_octaves = 3
                _forest_n.fractal_gain = 0.5
        return _forest_n


## Плотность леса 0..1 в точке (для посадки деревьев и лесной подстилки).
static func forest_density(x: float, z: float) -> float:
        var f := forest_noise().get_noise_2d(x, z)
        f += detail_noise().get_noise_2d(x + 900.0, z - 700.0) * 0.25
        return clampf(0.5 + f * 1.35, 0.0, 1.0)


static func terrain_height(x: float, z: float) -> float:
        var h := base_noise().get_noise_2d(x, z) * 10.0 + 3.5
        h += detail_noise().get_noise_2d(x, z) * 1.2
        # Впадина озера
        var dl := Vector2(x, z).distance_to(LAKE_CENTER)
        var lake_mask := 1.0 - smoothstep(LAKE_RADIUS * 0.45, LAKE_RADIUS, dl)
        h = lerpf(h, -LAKE_DEPTH, lake_mask * 0.9)
        # Холм с руинами
        var dh := Vector2(x, z).distance_to(HILL_CENTER)
        h += HILL_HEIGHT * (1.0 - smoothstep(0.0, HILL_RADIUS, dh))
        # Плато деревни
        var dv := Vector2(x, z).distance_to(VILLAGE_CENTER)
        var v_mask := 1.0 - smoothstep(VILLAGE_RADIUS * 0.55, VILLAGE_RADIUS * 1.6, dv)
        h = lerpf(h, VILLAGE_HEIGHT, v_mask)
        # v10.0: курган готической башни (пологий)
        var dt_ := Vector2(x, z).distance_to(TOWER_CENTER)
        h += TOWER_HEIGHT * (1.0 - smoothstep(0.0, TOWER_RADIUS, dt_))
        # v10.0: плато деревни № 2 «Каменный Форд» (плоско почти до края —
        # дома не должны парить на склоне)
        var dhm := Vector2(x, z).distance_to(HAMLET_CENTER)
        var hm_mask := 1.0 - smoothstep(HAMLET_RADIUS * 0.85, HAMLET_RADIUS * 1.7, dhm)
        h = lerpf(h, HAMLET_HEIGHT, hm_mask)
        # v10.0: прогалина ритуального круга — чуть ниже леса
        var dr := Vector2(x, z).distance_to(RITUAL_CENTER)
        var r_mask := 1.0 - smoothstep(RITUAL_RADIUS * 0.5, RITUAL_RADIUS * 1.3, dr)
        if r_mask > 0.001:
                h = lerpf(h, h - 0.35, r_mask * 0.8)
        # Плато замка (v5.0): плоская площадка, по краям — пологий подъём
        var dc := Vector2(x, z).distance_to(CASTLE_CENTER)
        var c_mask := 1.0 - smoothstep(CASTLE_RADIUS * 0.62, CASTLE_RADIUS * 1.35, dc)
        if c_mask > 0.001:
                var ramp := 1.0 - smoothstep(CASTLE_RADIUS * 0.55, CASTLE_RADIUS * 0.92, dc)
                h = lerpf(h, lerpf(h, CASTLE_HEIGHT, ramp), c_mask)
        # ГОРНОЕ КОЛЬЦО по краю мира. Раньше на горизонте был виден
        # рваный край террейна, сквозь который просвечивало небо
        # («прозрачная земля»). Кольцо всегда выше любой точки внутри
        # долины (максимум долины ~32 м), поэтому край карты не виден
        # ниоткуда: полная высота достигается уже на r=0.96.
        var half := TERRAIN_SIZE * 0.5
        var r := maxf(absf(x), absf(z)) / half
        var mring := smoothstep(0.78, 0.96, r)
        if mring > 0.001:
                var ridge := 0.5 + 0.5 * base_noise().get_noise_2d(x * 0.55 + 333.0, z * 0.55 - 333.0)
                ridge = 0.75 * ridge + 0.25 * (0.5 + 0.5 * base_noise().get_noise_2d(x * 1.4 - 555.0, z * 1.4 + 555.0))
                h += mring * (54.0 + 40.0 * ridge)
                h += mring * detail_noise().get_noise_2d(x * 1.7, z * 1.7) * 2.5
        return h


## Улицы деревни (v9.0, планировка «как в Скайриме»): главная улица
## юг→север от ворот к таверне, боковые проулки вдоль рядов домов,
## северная связка и проходы к угловым дворам.
const VILLAGE_STREETS := [
        Vector2(0.0, 29.0), Vector2(0.0, -11.0),        # главная улица: ворота -> таверна
        Vector2(-9.0, -12.0), Vector2(-9.0, 14.0),      # западный проулок
        Vector2(9.0, -12.0), Vector2(9.0, 14.0),        # восточный проулок
        Vector2(-17.0, -16.0), Vector2(-8.0, -16.0),    # северная связка (запад)
        Vector2(8.0, -16.0), Vector2(16.0, -16.0),      # северная связка (восток)
        Vector2(-9.0, 18.0), Vector2(-16.0, 19.5),      # проход к юго-зап. двору
        Vector2(9.0, 18.0), Vector2(24.0, 19.0),        # проход к кузнице и юго-вост. дворам
]

## v10.0: КАМЕННЫЕ ДОРОГИ (полилинии):
## Западная дорога: деревня → готическая башня → Каменный Форд → замок.
## Тропа культистов: деревня (восток) → ритуальный круг.
const WEST_ROAD := [
        Vector2(0.0, 30.0), Vector2(-18.0, 34.0), Vector2(-38.0, 41.0),
        Vector2(-56.0, 49.0), Vector2(-62.0, 58.0), Vector2(-76.0, 74.0),
        Vector2(-92.0, 92.0), Vector2(-104.0, 110.0), Vector2(-108.0, 122.0),
        Vector2(-118.0, 136.0), Vector2(-132.0, 148.0), Vector2(-142.0, 154.0),
]
const RITUAL_TRAIL := [
        Vector2(14.0, 24.0), Vector2(32.0, 34.0), Vector2(48.0, 44.0),
        Vector2(60.0, 54.0), Vector2(70.0, 60.0),
]

static func dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
        var ab := b - a
        if ab.length_squared() < 0.0001:
                return p.distance_to(a)
        var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
        return p.distance_to(a + ab * t)


## Расстояние до ближайшей грунтовой тропы (деревня -> озеро, деревня -> руины).
## v5.0: расстояние до оси скальной гряды с пещерой (для посадки деревьев).
static func cave_ridge_distance(p: Vector2) -> float:
        var away := (CAVE_CENTER - VILLAGE_CENTER).normalized()
        return dist_to_segment(p, CAVE_CENTER - away * 18.0, CAVE_CENTER + away * 52.0)


static func path_distance(p: Vector2) -> float:
        var d1 := dist_to_segment(p, VILLAGE_CENTER, LAKE_CENTER)
        var d2 := dist_to_segment(p, VILLAGE_CENTER, HILL_CENTER)
        var d3 := dist_to_segment(p, VILLAGE_CENTER, CAVE_CENTER)
        var d4 := dist_to_segment(p, VILLAGE_CENTER, CASTLE_CENTER)
        var best := minf(d1, minf(d2, minf(d3, d4)))
        for i in range(0, VILLAGE_STREETS.size(), 2):
                var ds := dist_to_segment(p, VILLAGE_STREETS[i], VILLAGE_STREETS[i + 1])
                best = minf(best, ds)
        # v10.0: каменные дороги и тропа к ритуальному кругу
        for i in range(WEST_ROAD.size() - 1):
                best = minf(best, dist_to_segment(p, WEST_ROAD[i], WEST_ROAD[i + 1]))
        for i in range(RITUAL_TRAIL.size() - 1):
                best = minf(best, dist_to_segment(p, RITUAL_TRAIL[i], RITUAL_TRAIL[i + 1]))
        return best
