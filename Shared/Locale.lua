-- PaTiShared: UI language. Strings live in Locales/<code>.lua (shared and addon files write into
-- the same ns.Locales tables); this file only resolves the language and looks keys up.
local _, ns = ...
local UI = ns.UI or {}
ns.UI = UI
ns.Locales = ns.Locales or {}
local locales = ns.Locales

-- Order = order in the language dropdown. "auto" follows the WoW client.
UI.LANGUAGES = {
    { code = "auto" },
    { code = "enUS", name = "English" },
    { code = "deDE", name = "Deutsch" },
    { code = "zhCN", name = "简体中文" },
    { code = "zhTW", name = "繁體中文" },
    { code = "koKR", name = "한국어" },
}

local SUPPORTED = { enUS = true, deDE = true, zhCN = true, zhTW = true, koKR = true }

local current = "enUS"
local listeners = {}
local bound = setmetatable({}, { __mode = "k" })

-- Lookup: current language, then English, then the key itself (makes gaps visible, never errors).
UI.L = setmetatable({}, { __index = function(_, key)
    local own, english = locales[current], locales.enUS
    return (own and own[key]) or (english and english[key]) or key
end })

-- source: a string key ("SETTINGS"; unknown keys such as "PaTiHeal" show as-is) or a function returning text.
function UI.Text(source)
    if type(source) == "function" then return source() end
    if source == nil then return nil end
    return UI.L[source]
end

local function applyText(object, source)
    object:SetText(UI.Text(source) or "")
    if object.patiAfterText then object.patiAfterText(object) end
end

-- Sets the text now and again after every language change.
function UI.BindText(object, source)
    bound[object] = source
    applyText(object, source)
end

-- enGB and unsupported client locales use English.
function UI.ResolveLanguage(code)
    if code == nil or code == "auto" then code = GetLocale() end
    return SUPPORTED[code] and code or "enUS"
end

-- code: "auto" or a code from UI.LANGUAGES. The addon stores the choice in its own DB.
function UI.SetLanguage(code)
    local resolved = UI.ResolveLanguage(code)
    if resolved == current then return end
    current = resolved
    for object, source in pairs(bound) do applyText(object, source) end
    for _, fn in ipairs(listeners) do fn(current) end
end

function UI.GetLanguage() return current end

-- Called after a language change so already visible texts can be relabelled.
function UI.OnLanguageChanged(fn) listeners[#listeners + 1] = fn end

function UI.LanguageName(code)
    if code == "auto" then return UI.L.LANGUAGE_AUTO end
    for _, language in ipairs(UI.LANGUAGES) do
        if language.code == code then return language.name end
    end
    return code
end

current = UI.ResolveLanguage("auto")
