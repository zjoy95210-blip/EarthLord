-- ============================================================
-- EarthLord Database Schema
-- Supabase project: svxpiosqufxdhwlcpfhm
-- ============================================================

-- ============================================================
-- 1. profiles (用户资料)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all profiles"
    ON public.profiles FOR SELECT
    USING (true);

CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
    ON public.profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, created_at)
    VALUES (NEW.id, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- 2. territories (领地)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.territories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT,
    path JSONB NOT NULL,                -- [{"lat": x, "lon": y}, ...]
    polygon TEXT,                        -- WKT format for spatial queries
    bbox_min_lat DOUBLE PRECISION,
    bbox_max_lat DOUBLE PRECISION,
    bbox_min_lon DOUBLE PRECISION,
    bbox_max_lon DOUBLE PRECISION,
    area DOUBLE PRECISION NOT NULL DEFAULT 0,
    point_count INTEGER,
    is_active BOOLEAN DEFAULT true,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_territories_user_id ON public.territories(user_id);
CREATE INDEX idx_territories_created_at ON public.territories(created_at DESC);

ALTER TABLE public.territories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all territories"
    ON public.territories FOR SELECT
    USING (true);

CREATE POLICY "Users can insert own territories"
    ON public.territories FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own territories"
    ON public.territories FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own territories"
    ON public.territories FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================
-- 3. pois (兴趣点)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.pois (
    id TEXT PRIMARY KEY,
    poi_type TEXT NOT NULL,              -- hospital, supermarket, factory, etc.
    name TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    discovered_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    discovered_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_pois_poi_type ON public.pois(poi_type);
CREATE INDEX idx_pois_discovered_by ON public.pois(discovered_by);
CREATE INDEX idx_pois_location ON public.pois(latitude, longitude);

ALTER TABLE public.pois ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view POIs"
    ON public.pois FOR SELECT
    USING (true);

CREATE POLICY "Authenticated users can create POIs"
    ON public.pois FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);

-- ============================================================
-- 4. item_definitions (物品定义)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.item_definitions (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT NOT NULL,              -- water, food, medical, material, tool, weapon, clothing, misc
    weight DOUBLE PRECISION NOT NULL DEFAULT 0,
    rarity TEXT NOT NULL DEFAULT 'common', -- common, uncommon, rare, epic, legendary
    max_stack INTEGER NOT NULL DEFAULT 99,
    description TEXT,
    has_quality BOOLEAN NOT NULL DEFAULT false
);

ALTER TABLE public.item_definitions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view item definitions"
    ON public.item_definitions FOR SELECT
    USING (true);

-- ============================================================
-- 5. inventory_items (背包物品)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.inventory_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    item_id TEXT NOT NULL REFERENCES public.item_definitions(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL DEFAULT 1,
    quality TEXT,                         -- broken, worn, normal, fine, pristine
    obtained_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_inventory_user_id ON public.inventory_items(user_id);
CREATE INDEX idx_inventory_item_id ON public.inventory_items(item_id);
CREATE INDEX idx_inventory_user_item ON public.inventory_items(user_id, item_id);

ALTER TABLE public.inventory_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own inventory"
    ON public.inventory_items FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own inventory"
    ON public.inventory_items FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own inventory"
    ON public.inventory_items FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own inventory"
    ON public.inventory_items FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================
-- 6. exploration_sessions (探索记录)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.exploration_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    start_time TIMESTAMPTZ NOT NULL DEFAULT now(),
    end_time TIMESTAMPTZ,
    duration INTEGER,                    -- seconds
    start_lat DOUBLE PRECISION,
    start_lng DOUBLE PRECISION,
    end_lat DOUBLE PRECISION,
    end_lng DOUBLE PRECISION,
    total_distance DOUBLE PRECISION NOT NULL DEFAULT 0,
    reward_tier TEXT,                     -- none, bronze, silver, gold, diamond
    items_rewarded JSONB,                -- [{item_id, quantity, quality}, ...]
    status TEXT NOT NULL DEFAULT 'active' -- active, completed, cancelled
);

CREATE INDEX idx_exploration_user_id ON public.exploration_sessions(user_id);
CREATE INDEX idx_exploration_status ON public.exploration_sessions(status);
CREATE INDEX idx_exploration_start_time ON public.exploration_sessions(start_time DESC);

ALTER TABLE public.exploration_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own sessions"
    ON public.exploration_sessions FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own sessions"
    ON public.exploration_sessions FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own sessions"
    ON public.exploration_sessions FOR UPDATE
    USING (auth.uid() = user_id);

-- ============================================================
-- 7. player_buildings (玩家建筑)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.player_buildings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    territory_id UUID NOT NULL REFERENCES public.territories(id) ON DELETE CASCADE,
    template_id TEXT NOT NULL,           -- references building_templates.json id
    level INTEGER NOT NULL DEFAULT 1,
    status TEXT NOT NULL DEFAULT 'constructing', -- constructing, active, upgrading
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    location_lat DOUBLE PRECISION,
    location_lon DOUBLE PRECISION
);

CREATE INDEX idx_buildings_user_id ON public.player_buildings(user_id);
CREATE INDEX idx_buildings_territory_id ON public.player_buildings(territory_id);

ALTER TABLE public.player_buildings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all buildings"
    ON public.player_buildings FOR SELECT
    USING (true);

CREATE POLICY "Users can insert own buildings"
    ON public.player_buildings FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own buildings"
    ON public.player_buildings FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own buildings"
    ON public.player_buildings FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================
-- 8. Seed data: item_definitions (物品种子数据)
-- ============================================================
INSERT INTO public.item_definitions (id, name, category, weight, rarity, max_stack, description, has_quality) VALUES
    -- Water (水类)
    ('water_bottle',      '瓶装水',     'water',    0.5,  'common',    20, '一瓶干净的饮用水',           false),
    ('water_filter',      '净水器',     'water',    1.0,  'uncommon',  5,  '可以过滤脏水的简易装置',      true),
    ('water_tank',        '水箱',       'water',    5.0,  'rare',      3,  '大容量储水容器',             true),

    -- Food (食物)
    ('canned_food',       '罐头食品',   'food',     0.8,  'common',    20, '保质期很长的罐头',           false),
    ('dried_meat',        '肉干',       'food',     0.3,  'common',    30, '晒干的肉条',               false),
    ('fresh_vegetables',  '新鲜蔬菜',   'food',     0.5,  'uncommon',  15, '新鲜的绿色蔬菜',            false),
    ('mre',               '军用口粮',   'food',     0.6,  'rare',      10, '军用即食口粮',              false),
    ('seeds',             '种子',       'food',     0.1,  'uncommon',  50, '可以种植的作物种子',          false),

    -- Medical (医疗)
    ('bandage',           '绷带',       'medical',  0.1,  'common',    30, '基础医疗绷带',              false),
    ('first_aid_kit',     '急救包',     'medical',  1.0,  'uncommon',  5,  '包含基本医疗用品的急救包',    true),
    ('antibiotics',       '抗生素',     'medical',  0.1,  'rare',      10, '用于治疗感染的药物',          false),
    ('painkillers',       '止痛药',     'medical',  0.1,  'common',    20, '缓解疼痛的药片',             false),

    -- Material (材料)
    ('wood',              '木材',       'material', 2.0,  'common',    50, '基础建筑材料',              false),
    ('stone',             '石头',       'material', 3.0,  'common',    30, '坚硬的石块',               false),
    ('metal_scrap',       '金属废料',   'material', 1.5,  'common',    40, '可回收利用的金属碎片',        false),
    ('rope',              '绳索',       'material', 0.5,  'common',    20, '结实的绳子',               false),
    ('cloth',             '布料',       'material', 0.3,  'common',    30, '可用于制作的布料',           false),
    ('electronics',       '电子元件',   'material', 0.5,  'uncommon',  20, '各种电子零件',              false),
    ('fuel',              '燃料',       'material', 1.0,  'uncommon',  15, '可燃液体燃料',              false),
    ('glass',             '玻璃',       'material', 0.8,  'common',    20, '透明玻璃片',               false),
    ('plastic',           '塑料',       'material', 0.3,  'common',    30, '可回收塑料',               false),
    ('cement',            '水泥',       'material', 5.0,  'uncommon',  10, '建筑用水泥',               false),

    -- Tool (工具)
    ('flashlight',        '手电筒',     'tool',     0.3,  'common',    5,  '便携式照明工具',             true),
    ('compass',           '指南针',     'tool',     0.1,  'uncommon',  3,  '方向指示工具',              true),
    ('multitool',         '多功能工具',  'tool',     0.5,  'uncommon',  3,  '瑞士军刀式多功能工具',       true),
    ('binoculars',        '望远镜',     'tool',     0.8,  'rare',      2,  '远距离观察用望远镜',          true),
    ('lockpick',          '开锁工具',   'tool',     0.1,  'rare',      5,  '可以打开简单锁的工具',        true),
    ('hammer',            '锤子',       'tool',     1.5,  'common',    3,  '基础建造工具',              true),

    -- Weapon (武器)
    ('baseball_bat',      '棒球棍',     'weapon',   1.5,  'common',    1,  '近战武器',                 true),
    ('knife',             '匕首',       'weapon',   0.5,  'uncommon',  1,  '锋利的小刀',               true),
    ('bow',               '弓',        'weapon',   1.0,  'rare',      1,  '远程武器',                 true),
    ('arrow',             '箭矢',      'weapon',   0.1,  'common',    30, '弓箭的弹药',               false),

    -- Clothing (服装)
    ('jacket',            '夹克',       'clothing', 1.0,  'common',    3,  '保暖外套',                 true),
    ('boots',             '靴子',       'clothing', 1.5,  'uncommon',  2,  '耐用的行走靴',              true),
    ('gas_mask',          '防毒面具',   'clothing', 0.8,  'rare',      2,  '过滤有害气体的面具',          true),
    ('backpack_upgrade',  '背包扩展',   'clothing', 0.5,  'rare',      1,  '增加背包容量',              false),

    -- Misc (杂项)
    ('battery',           '电池',       'misc',     0.2,  'common',    20, '通用电池',                 false),
    ('map_fragment',      '地图碎片',   'misc',     0.05, 'uncommon',  10, '旧世界的地图残片',           false),
    ('notebook',          '笔记本',     'misc',     0.2,  'common',    5,  '记录信息的笔记本',           false),
    ('radio',             '收音机',     'misc',     0.8,  'rare',      2,  '可接收信号的收音机',          true),
    ('flare',             '信号弹',     'misc',     0.3,  'uncommon',  10, '发出信号的照明弹',           false)
ON CONFLICT (id) DO NOTHING;
