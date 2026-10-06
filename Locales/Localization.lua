local ADDON_NAME, TMF = ...

TMF.L = setmetatable({}, {
    __index = function(tbl, key)
        -- Fallback to the raw key if translation is missing
        return key
    end
})

local currentLocale = GetLocale and GetLocale() or "enUS"

function TMF:NewLocale(locale)
    if locale == "enUS" or locale == currentLocale then
        return TMF.L
    end
    return nil
end
