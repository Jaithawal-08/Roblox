"""
ShadowRealm Stage 1 .rbxl Generator
Generates a complete Roblox place file with all Stage 1 scripts and UI pre-built.
Run: python generate_rbxl.py
Output: ShadowRealm_Stage1.rbxl (open in Roblox Studio)
"""

import xml.etree.ElementTree as ET
from xml.dom import minidom
import os
import uuid

# ============================
# HELPER: Generate Roblox ID
# ============================
_id_counter = [0]
def new_ref():
    _id_counter[0] += 1
    return f"RBX{_id_counter[0]:08X}"

def make_item(class_name, referent=None):
    if referent is None:
        referent = new_ref()
    item = ET.Element("Item")
    item.set("class", class_name)
    item.set("referent", referent)
    props = ET.SubElement(item, "Properties")
    return item, props

def add_string(props, name, value):
    el = ET.SubElement(props, "string")
    el.set("name", name)
    el.text = str(value)

def add_bool(props, name, value):
    el = ET.SubElement(props, "bool")
    el.set("name", value if False else name)
    el.text = "true" if value else "false"

def add_int(props, name, value):
    el = ET.SubElement(props, "int")
    el.set("name", name)
    el.text = str(int(value))

def add_float(props, name, value):
    el = ET.SubElement(props, "float")
    el.set("name", name)
    el.text = str(float(value))

def add_token(props, name, value):
    el = ET.SubElement(props, "token")
    el.set("name", name)
    el.text = str(value)

def add_color3(props, name, r, g, b):
    el = ET.SubElement(props, "Color3uint8")
    el.set("name", name)
    val = (int(r) << 16) | (int(g) << 8) | int(b)
    el.text = str(val)

def add_udim2(props, name, xs, xo, ys, yo):
    el = ET.SubElement(props, "UDim2")
    el.set("name", name)
    ET.SubElement(el, "XS").text = str(xs)
    ET.SubElement(el, "XO").text = str(int(xo))
    ET.SubElement(el, "YS").text = str(ys)
    ET.SubElement(el, "YO").text = str(int(yo))

def add_vector2(props, name, x, y):
    el = ET.SubElement(props, "Vector2")
    el.set("name", name)
    ET.SubElement(el, "X").text = str(x)
    ET.SubElement(el, "Y").text = str(y)

def make_script(parent, script_type, name, source, disabled=False):
    """script_type: 'Script', 'LocalScript', 'ModuleScript'"""
    item, props = make_item(script_type)
    add_string(props, "Name", name)
    add_string(props, "Source", source)
    if disabled:
        add_bool(props, "Disabled", True)
    parent.append(item)
    return item

def make_folder(parent, name):
    item, props = make_item("Folder")
    add_string(props, "Name", name)
    parent.append(item)
    return item

def make_screengui(parent, name, reset_on_spawn=False, display_order=0, enabled=True):
    item, props = make_item("ScreenGui")
    add_string(props, "Name", name)
    add_bool(props, "ResetOnSpawn", reset_on_spawn)
    add_int(props, "DisplayOrder", display_order)
    add_bool(props, "Enabled", enabled)
    add_token(props, "ScreenInsets", 0)
    parent.append(item)
    return item

def make_frame(parent, name, size, pos, bg_color=(30,30,40), bg_trans=0.0, clip=False):
    item, props = make_item("Frame")
    add_string(props, "Name", name)
    add_udim2(props, "Size", size[0], size[1], size[2], size[3])
    add_udim2(props, "Position", pos[0], pos[1], pos[2], pos[3])
    add_color3(props, "BackgroundColor3", *bg_color)
    add_float(props, "BackgroundTransparency", bg_trans)
    add_bool(props, "ClipsDescendants", clip)
    parent.append(item)
    return item

def make_label(parent, name, text, size, pos, text_color=(255,255,255), font=3, text_size=14,
               bg_trans=1.0, stroke=False, rich_text=False, scaled=False, x_align=2, y_align=1):
    item, props = make_item("TextLabel")
    add_string(props, "Name", name)
    add_string(props, "Text", text)
    add_udim2(props, "Size", size[0], size[1], size[2], size[3])
    add_udim2(props, "Position", pos[0], pos[1], pos[2], pos[3])
    add_color3(props, "TextColor3", *text_color)
    add_color3(props, "BackgroundColor3", 0, 0, 0)
    add_float(props, "BackgroundTransparency", bg_trans)
    add_int(props, "Font", font)      # 3=GothamBold, 16=GothamSemibold
    add_int(props, "TextSize", text_size)
    add_bool(props, "TextScaled", scaled)
    add_bool(props, "RichText", rich_text)
    add_token(props, "TextXAlignment", x_align)   # 0=Left,1=Right,2=Center
    add_token(props, "TextYAlignment", y_align)   # 0=Top,1=Center,2=Bottom
    if stroke:
        add_color3(props, "TextStrokeColor3", 0, 0, 0)
        add_float(props, "TextStrokeTransparency", 0)
    parent.append(item)
    return item

def make_button(parent, name, text, size, pos, bg_color=(60,60,80), text_color=(255,255,255)):
    item, props = make_item("TextButton")
    add_string(props, "Name", name)
    add_string(props, "Text", text)
    add_udim2(props, "Size", size[0], size[1], size[2], size[3])
    add_udim2(props, "Position", pos[0], pos[1], pos[2], pos[3])
    add_color3(props, "BackgroundColor3", *bg_color)
    add_float(props, "BackgroundTransparency", 0)
    add_color3(props, "TextColor3", *text_color)
    add_int(props, "Font", 3)
    add_int(props, "TextSize", 13)
    add_bool(props, "TextScaled", False)
    add_token(props, "TextXAlignment", 2)
    add_token(props, "TextYAlignment", 1)
    parent.append(item)
    return item

def make_corner(parent, radius=8):
    item, props = make_item("UICorner")
    rad_el = ET.SubElement(props, "UDim")
    rad_el.set("name", "CornerRadius")
    ET.SubElement(rad_el, "S").text = "0"
    ET.SubElement(rad_el, "O").text = str(radius)
    parent.append(item)
    return item

def make_bar(parent, name, fill_color, bar_size, bar_pos, fill_name="Fill"):
    """Creates a bar frame with inner fill frame"""
    # Outer bar (background)
    bar_item, bar_props = make_item("Frame")
    add_string(bar_props, "Name", name)
    add_udim2(bar_props, "Size", bar_size[0], bar_size[1], bar_size[2], bar_size[3])
    add_udim2(bar_props, "Position", bar_pos[0], bar_pos[1], bar_pos[2], bar_pos[3])
    add_color3(bar_props, "BackgroundColor3", 20, 20, 30)
    add_float(bar_props, "BackgroundTransparency", 0.3)
    add_bool(bar_props, "ClipsDescendants", True)
    make_corner(bar_item, 6)

    # Inner fill
    fill_item, fill_props = make_item("Frame")
    add_string(fill_props, "Name", fill_name)
    add_udim2(fill_props, "Size", 1, 0, 1, 0)
    add_udim2(fill_props, "Position", 0, 0, 0, 0)
    add_color3(fill_props, "BackgroundColor3", *fill_color)
    add_float(fill_props, "BackgroundTransparency", 0)
    make_corner(fill_item, 6)
    bar_item.append(fill_item)

    parent.append(bar_item)
    return bar_item

# ============================
# READ SCRIPT FILES
# ============================
script_dir = os.path.dirname(os.path.abspath(__file__))

def read_script(filename):
    path = os.path.join(script_dir, filename)
    with open(path, "r", encoding="utf-8") as f:
        return f.read()

RANK_CONFIG_SRC       = read_script("RankConfig.lua")
PLAYER_DATA_SRC       = read_script("PlayerDataService.lua")
MAIN_HUD_LOCAL_SRC    = read_script("MainHUD_LocalScript.lua")
REMOTES_SETUP_SRC     = read_script("RemotesSetup.lua")
TEST_SCRIPT_SRC       = read_script("TestScript.lua")
STATS_PANEL_SRC       = read_script("StatsPanelController.lua")

# ============================
# BUILD THE ROBLOX XML
# ============================
root = ET.Element("roblox")
root.set("xmlns:xmime", "http://www.w3.org/2005/05/xmlmime")
root.set("xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance")
root.set("xsi:noNamespaceSchemaLocation",
         "http://www.roblox.com/roblox.xsd")
root.set("version", "4")

# Meta
meta = ET.SubElement(root, "Meta")
meta.set("name", "ExplicitAutoJoints")
meta.text = "true"

# External
ET.SubElement(root, "External").text = "null"
ET.SubElement(root, "External").text = "nil"

# ============================
# WORKSPACE
# ============================
ws_item, ws_props = make_item("Workspace")
add_string(ws_props, "Name", "Workspace")
add_bool(ws_props, "FilteringEnabled", True)

# Spawn Location
spawn_item, spawn_props = make_item("SpawnLocation")
add_string(spawn_props, "Name", "SpawnLocation")
add_bool(spawn_props, "AllowTeamChangeOnTouch", False)
add_bool(spawn_props, "Neutral", True)
add_bool(spawn_props, "TeamColor", False)
cf = ET.SubElement(spawn_props, "CoordinateFrame")
cf.set("name", "CFrame")
ET.SubElement(cf, "X").text = "0"
ET.SubElement(cf, "Y").text = "0.5"
ET.SubElement(cf, "Z").text = "0"
ET.SubElement(cf, "R00").text = "1"; ET.SubElement(cf, "R01").text = "0"; ET.SubElement(cf, "R02").text = "0"
ET.SubElement(cf, "R10").text = "0"; ET.SubElement(cf, "R11").text = "1"; ET.SubElement(cf, "R12").text = "0"
ET.SubElement(cf, "R20").text = "0"; ET.SubElement(cf, "R21").text = "0"; ET.SubElement(cf, "R22").text = "1"
ws_item.append(spawn_item)

# Lobby folder
lobby_folder = make_folder(ws_item, "Lobby")
dungeon_portals = make_folder(ws_item, "DungeonPortals")
npcs_folder = make_folder(ws_item, "NPCs")

root.append(ws_item)

# ============================
# REPLICATED STORAGE
# ============================
rs_item, rs_props = make_item("ReplicatedStorage")
add_string(rs_props, "Name", "ReplicatedStorage")

# Remotes folder
remotes_folder = make_folder(rs_item, "Remotes")

# Modules folder
modules_folder = make_folder(rs_item, "Modules")

# RankConfig module
make_script(modules_folder, "ModuleScript", "RankConfig", RANK_CONFIG_SRC)

root.append(rs_item)

# ============================
# SERVER SCRIPT SERVICE
# ============================
sss_item, sss_props = make_item("ServerScriptService")
add_string(sss_props, "Name", "ServerScriptService")

# Services folder
services_folder = make_folder(sss_item, "Services")

# RemotesSetup (runs first to create remotes before PlayerDataService)
make_script(sss_item, "Script", "RemotesSetup", REMOTES_SETUP_SRC)

# PlayerDataService
make_script(services_folder, "Script", "PlayerDataService", PLAYER_DATA_SRC)

# TestScript (gives XP for testing)
make_script(sss_item, "Script", "TestScript", TEST_SCRIPT_SRC)

root.append(sss_item)

# ============================
# STARTER GUI
# ============================
sg_item, sg_props = make_item("StarterGui")
add_string(sg_props, "Name", "StarterGui")
add_bool(sg_props, "ShowDevelopmentGui", True)

# ============================
# MainHUD ScreenGui
# ============================
hud_gui = make_screengui(sg_item, "MainHUD", reset_on_spawn=False, display_order=1)

# === HUD Frame (bottom-left anchored panel) ===
hud_frame = make_frame(hud_gui, "HUD",
    size=(0, 320, 0, 160),
    pos=(0, 10, 1, -170),
    bg_color=(15, 15, 25),
    bg_trans=0.2)
make_corner(hud_frame, 12)

# UIStroke for HUD
stroke_item, stroke_props = make_item("UIStroke")
add_string(stroke_props, "Name", "UIStroke")
add_color3(stroke_props, "Color", 80, 60, 120)
add_float(stroke_props, "Thickness", 1.5)
add_float(stroke_props, "Transparency", 0)
hud_frame.append(stroke_item)

# --- Level Label ---
make_label(hud_frame, "LevelLabel", "LVL 1",
    size=(0, 120, 0, 28),
    pos=(0, 10, 0, 8),
    text_color=(255, 220, 0),
    font=3, text_size=18, stroke=True)

# --- Coins Label ---
make_label(hud_frame, "CoinsLabel", "🪙 0",
    size=(0, 100, 0, 22),
    pos=(0, 140, 0, 10),
    text_color=(255, 200, 50),
    font=3, text_size=13)

# --- Gems Label ---
make_label(hud_frame, "GemsLabel", "💎 0",
    size=(0, 80, 0, 22),
    pos=(0, 240, 0, 10),
    text_color=(130, 200, 255),
    font=3, text_size=13)

# --- HP Bar ---
hp_bar = make_bar(hud_frame, "HPBar",
    fill_color=(200, 50, 50),
    bar_size=(0, 296, 0, 18),
    bar_pos=(0, 10, 0, 44))

# HP label overlay
make_label(hp_bar, "HPLabel", "100 / 100",
    size=(1, 0, 1, 0),
    pos=(0, 0, 0, 0),
    text_color=(255, 255, 255),
    font=3, text_size=11, stroke=True)

hp_icon, hp_icon_props = make_item("TextLabel")
add_string(hp_icon_props, "Name", "HPIcon")
add_string(hp_icon_props, "Text", "❤ HP")
add_udim2(hp_icon_props, "Size", 0, 296, 0, 14)
add_udim2(hp_icon_props, "Position", 0, 10, 0, 30)
add_color3(hp_icon_props, "TextColor3", 255, 120, 120)
add_float(hp_icon_props, "BackgroundTransparency", 1)
add_int(hp_icon_props, "Font", 3)
add_int(hp_icon_props, "TextSize", 11)
add_token(hp_icon_props, "TextXAlignment", 0)
hud_frame.append(hp_icon)

# --- Mana Bar ---
mana_bar = make_bar(hud_frame, "ManaBar",
    fill_color=(50, 100, 230),
    bar_size=(0, 296, 0, 18),
    bar_pos=(0, 10, 0, 80))

make_label(mana_bar, "ManaLabel", "50 / 50",
    size=(1, 0, 1, 0),
    pos=(0, 0, 0, 0),
    text_color=(255, 255, 255),
    font=3, text_size=11, stroke=True)

mana_icon, mana_icon_props = make_item("TextLabel")
add_string(mana_icon_props, "Name", "ManaIcon")
add_string(mana_icon_props, "Text", "💧 MANA")
add_udim2(mana_icon_props, "Size", 0, 296, 0, 14)
add_udim2(mana_icon_props, "Position", 0, 10, 0, 66)
add_color3(mana_icon_props, "TextColor3", 100, 150, 255)
add_float(mana_icon_props, "BackgroundTransparency", 1)
add_int(mana_icon_props, "Font", 3)
add_int(mana_icon_props, "TextSize", 11)
add_token(mana_icon_props, "TextXAlignment", 0)
hud_frame.append(mana_icon)

# --- XP Bar ---
xp_bar = make_bar(hud_frame, "XPBar",
    fill_color=(100, 60, 200),
    bar_size=(0, 296, 0, 14),
    bar_pos=(0, 10, 0, 110))

xp_icon, xp_icon_props = make_item("TextLabel")
add_string(xp_icon_props, "Name", "XPIcon")
add_string(xp_icon_props, "Text", "⚡ XP")
add_udim2(xp_icon_props, "Size", 0, 296, 0, 12)
add_udim2(xp_icon_props, "Position", 0, 10, 0, 98)
add_color3(xp_icon_props, "TextColor3", 160, 100, 255)
add_float(xp_icon_props, "BackgroundTransparency", 1)
add_int(xp_icon_props, "Font", 3)
add_int(xp_icon_props, "TextSize", 10)
add_token(xp_icon_props, "TextXAlignment", 0)
hud_frame.append(xp_icon)

make_label(xp_bar, "XPLabel", "0 / 100 XP",
    size=(1, 0, 1, 0),
    pos=(0, 0, 0, 0),
    text_color=(220, 200, 255),
    font=3, text_size=10, stroke=True)

# --- Stat Points Alert ---
sp_label_item, sp_label_props = make_item("TextLabel")
add_string(sp_label_props, "Name", "StatPointsLabel")
add_string(sp_label_props, "Text", "⬆ 0 STAT POINTS!")
add_udim2(sp_label_props, "Size", 0, 200, 0, 22)
add_udim2(sp_label_props, "Position", 0, 10, 0, 132)
add_color3(sp_label_props, "TextColor3", 100, 255, 100)
add_color3(sp_label_props, "BackgroundColor3", 0, 0, 0)
add_float(sp_label_props, "BackgroundTransparency", 1)
add_int(sp_label_props, "Font", 3)
add_int(sp_label_props, "TextSize", 13)
add_bool(sp_label_props, "Visible", False)
add_token(sp_label_props, "TextXAlignment", 0)
hud_frame.append(sp_label_item)

# --- Stats Button ---
stats_btn = make_button(hud_frame, "StatsButton", "📊 STATS",
    size=(0, 90, 0, 22),
    pos=(0, 216, 0, 132),
    bg_color=(60, 40, 100),
    text_color=(220, 180, 255))
make_corner(stats_btn, 6)

# Add LocalScript to MainHUD
make_script(hud_gui, "LocalScript", "HUDController", MAIN_HUD_LOCAL_SRC)

# ============================
# STATS PANEL ScreenGui (starts hidden)
# ============================
stats_panel_gui = make_screengui(sg_item, "StatsPanel", reset_on_spawn=False, display_order=5)

# Hidden by default via LocalScript control; make the frame
stats_panel_frame = make_frame(stats_panel_gui, "StatsPanel",
    size=(0, 380, 0, 480),
    pos=(0.5, -190, 0.5, -240),
    bg_color=(12, 12, 22),
    bg_trans=0.05)
make_corner(stats_panel_frame, 16)

# Stroke
sp_stroke, sp_stroke_props = make_item("UIStroke")
add_string(sp_stroke_props, "Name", "UIStroke")
add_color3(sp_stroke_props, "Color", 100, 60, 180)
add_float(sp_stroke_props, "Thickness", 2)
stats_panel_frame.append(sp_stroke)

# Title
make_label(stats_panel_frame, "TitleLabel", "⚔  CHARACTER STATS",
    size=(1, -40, 0, 40),
    pos=(0, 20, 0, 10),
    text_color=(255, 220, 60),
    font=3, text_size=20, stroke=True,
    x_align=0)

# Close button
close_btn = make_button(stats_panel_frame, "CloseButton", "✕",
    size=(0, 36, 0, 30),
    pos=(1, -46, 0, 10),
    bg_color=(180, 40, 40),
    text_color=(255, 255, 255))
make_corner(close_btn, 6)

# Stat Points label
make_label(stats_panel_frame, "StatPointsLabel", "Stat Points: 0",
    size=(1, -40, 0, 24),
    pos=(0, 20, 0, 52),
    text_color=(100, 255, 120),
    font=3, text_size=15, x_align=0)

# Stats frame (scrollable list)
stats_frame = make_frame(stats_panel_frame, "StatsFrame",
    size=(1, -40, 1, -100),
    pos=(0, 20, 0, 84),
    bg_trans=1.0)

stat_rows = [
    ("Strength",       "Strength",       "⚔  Strength",      True),
    ("Defense",        "Defense",        "🛡 Defense",        True),
    ("MaxHealth",      "Max HP",         "❤ Max HP",         True),
    ("MaxMana",        "Max Mana",       "💧 Max Mana",       True),
    ("CriticalChance", "Crit Chance",    "🎯 Crit Chance",    True),
    ("CriticalDamage", "Crit Damage",    "💥 Crit Damage",    False),
    ("AttackSpeed",    "Atk Speed",      "⚡ Atk Speed",      False),
    ("MovementSpeed",  "Move Speed",     "💨 Move Speed",     False),
]

for i, (key, label, icon_text, spendable) in enumerate(stat_rows):
    row_y = i * 46

    row_frame = make_frame(stats_frame, key + "Row",
        size=(1, 0, 0, 40),
        pos=(0, 0, 0, row_y),
        bg_color=(25, 25, 40),
        bg_trans=0.3)
    make_corner(row_frame, 6)

    # Icon + Name
    make_label(row_frame, "NameLabel", icon_text,
        size=(0, 180, 1, 0),
        pos=(0, 10, 0, 0),
        text_color=(200, 200, 220),
        font=3, text_size=14,
        x_align=0)

    # Value
    make_label(row_frame, "ValueLabel", "0",
        size=(0, 90, 1, 0),
        pos=(0, 190, 0, 0),
        text_color=(255, 255, 100),
        font=3, text_size=14)

    if spendable:
        spend_btn = make_button(row_frame, "SpendButton", "+ SPEND",
            size=(0, 80, 0, 26),
            pos=(1, -90, 0.5, -13),
            bg_color=(70, 50, 130),
            text_color=(200, 170, 255))
        make_corner(spend_btn, 5)

# Stats Panel LocalScript
make_script(stats_panel_gui, "LocalScript", "StatsPanelController", STATS_PANEL_SRC)

root.append(sg_item)

# ============================
# STARTER PLAYER
# ============================
sp_item, sp_props = make_item("StarterPlayer")
add_string(sp_props, "Name", "StarterPlayer")

sps_folder_item, sps_folder_props = make_item("StarterPlayerScripts")
add_string(sps_folder_props, "Name", "StarterPlayerScripts")
sp_item.append(sps_folder_item)

root.append(sp_item)

# ============================
# PRETTY PRINT XML → .rbxl
# ============================
xml_str = ET.tostring(root, encoding="unicode")
dom = minidom.parseString(xml_str)
pretty_xml = dom.toprettyxml(indent="  ")

# Remove extra XML declaration added by minidom
lines = pretty_xml.split("\n")
if lines[0].startswith("<?xml"):
    lines = lines[1:]
final_xml = '<?xml version="1.0" encoding="utf-8"?>\n' + "\n".join(lines)

output_path = os.path.join(script_dir, "ShadowRealm_Stage1.rbxl")
with open(output_path, "w", encoding="utf-8") as f:
    f.write(final_xml)

print(f"[SUCCESS] Generated: {output_path}")
print("Open ShadowRealm_Stage1.rbxl in Roblox Studio!")
