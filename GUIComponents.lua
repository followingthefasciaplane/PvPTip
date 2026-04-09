-- guicomponents.lua
PvPTip = PvPTip or {}
PvPTip.UI = {}
local UI = PvPTip.UI

-------------------------------------------------------------------------------
-- design constants
-------------------------------------------------------------------------------

UI.Colors = {
    bg        = {0, 0, 0, 0.85},
    bgLight   = {0.08, 0.08, 0.10, 0.95},
    border    = {0.20, 0.20, 0.24, 1},
    accent    = {0.4, 0.7, 1.0, 1},
    text      = {0.9, 0.9, 0.9, 1},
    textDim   = {0.5, 0.5, 0.5, 1},
    header    = {1, 0.82, 0, 1},
    tabActive = {0.14, 0.14, 0.18, 1},
    tabHover  = {0.10, 0.10, 0.14, 1},
}

UI.Sizes = {
    windowW = 850,
    windowH = 560,
    sidebarW = 130,
    padding = 12,
    rowH = 24,
    iconSize = 18,
    fontSize = 11,
    fontSizeHeader = 13,
}

local WHITE8X8 = "Interface\\Buttons\\WHITE8X8"

-------------------------------------------------------------------------------
-- backdrop helper
-------------------------------------------------------------------------------

local function SetFlatBackdrop(frame, r, g, b, a, borderR, borderG, borderB, borderA)
    if not frame.SetBackdrop then
        Mixin(frame, BackdropTemplateMixin)
        frame:HookScript("OnSizeChanged", frame.OnBackdropSizeChanged)
    end
    frame:SetBackdrop({
        bgFile = WHITE8X8,
        edgeFile = WHITE8X8,
        edgeSize = 1,
    })
    frame:SetBackdropColor(r or 0, g or 0, b or 0, a or 0.85)
    frame:SetBackdropBorderColor(borderR or 0.20, borderG or 0.20, borderB or 0.24, borderA or 1)
end

UI.SetFlatBackdrop = SetFlatBackdrop

-------------------------------------------------------------------------------
-- main addon window
-------------------------------------------------------------------------------

function UI.CreateWindow(name, title, width, height)
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:SetSize(width or UI.Sizes.windowW, height or UI.Sizes.windowH)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)

    SetFlatBackdrop(f, 0.04, 0.04, 0.06, 0.95, 0.20, 0.20, 0.24, 1)

    -- title bar
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetHeight(32)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

    -- title bar background
    local titleBg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBg:SetAllPoints()
    titleBg:SetColorTexture(0.08, 0.08, 0.10, 1)

    -- title bar bottom border
    local titleBorder = titleBar:CreateTexture(nil, "ARTWORK")
    titleBorder:SetHeight(1)
    titleBorder:SetPoint("BOTTOMLEFT", titleBar, "BOTTOMLEFT")
    titleBorder:SetPoint("BOTTOMRIGHT", titleBar, "BOTTOMRIGHT")
    titleBorder:SetColorTexture(0.20, 0.20, 0.24, 1)

    -- title text
    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 12, 0)
    titleText:SetText(title or "PvPTip")
    titleText:SetTextColor(1, 0.82, 0)
    f.titleText = titleText

    -- close button
    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -8, 0)
    closeBtn:SetNormalFontObject("GameFontNormalSmall")

    local closeTex = closeBtn:CreateTexture(nil, "ARTWORK")
    closeTex:SetAllPoints()
    closeTex:SetColorTexture(0, 0, 0, 0)

    local closeText = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    closeText:SetPoint("CENTER")
    closeText:SetText("X")
    closeText:SetTextColor(0.6, 0.6, 0.6)

    closeBtn:SetScript("OnEnter", function()
        closeText:SetTextColor(1, 0.3, 0.3)
    end)
    closeBtn:SetScript("OnLeave", function()
        closeText:SetTextColor(0.6, 0.6, 0.6)
    end)
    closeBtn:SetScript("OnClick", function()
        f:Hide()
    end)

    -- ESC to close
    tinsert(UISpecialFrames, name)

    -- content area (below title bar)
    f.content = CreateFrame("Frame", nil, f)
    f.content:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    f.content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

    return f
end

-------------------------------------------------------------------------------
-- left sidebar tab system
-------------------------------------------------------------------------------

function UI.CreateTabs(parent, tabDefs)
    local sidebarW = UI.Sizes.sidebarW
    local tabH = 36
    local controller = {}
    controller.tabs = {}
    controller.panels = {}
    controller.activeKey = nil

    -- sidebar frame
    local sidebar = CreateFrame("Frame", nil, parent)
    sidebar:SetWidth(sidebarW)
    sidebar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    sidebar:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)

    local sidebarBg = sidebar:CreateTexture(nil, "BACKGROUND")
    sidebarBg:SetAllPoints()
    sidebarBg:SetColorTexture(0.06, 0.06, 0.08, 1)

    -- sidebar right border
    local sidebarBorder = sidebar:CreateTexture(nil, "ARTWORK")
    sidebarBorder:SetWidth(1)
    sidebarBorder:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT")
    sidebarBorder:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT")
    sidebarBorder:SetColorTexture(0.20, 0.20, 0.24, 1)

    -- content area (right of sidebar)
    local contentArea = CreateFrame("Frame", nil, parent)
    contentArea:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
    contentArea:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    controller.contentArea = contentArea

    -- create tab buttons and panels
    for idx, def in ipairs(tabDefs) do
        -- tab button
        local tab = CreateFrame("Button", nil, sidebar)
        tab:SetHeight(tabH)
        tab:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, -((idx - 1) * tabH))
        tab:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -1, -((idx - 1) * tabH))

        local tabBg = tab:CreateTexture(nil, "BACKGROUND")
        tabBg:SetAllPoints()
        tabBg:SetColorTexture(0.06, 0.06, 0.08, 1)
        tab.bg = tabBg

        -- accent bar (left edge, hidden by default)
        local accent = tab:CreateTexture(nil, "OVERLAY")
        accent:SetWidth(3)
        accent:SetPoint("TOPLEFT", tab, "TOPLEFT")
        accent:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT")
        accent:SetColorTexture(UI.Colors.accent[1], UI.Colors.accent[2], UI.Colors.accent[3], 1)
        accent:Hide()
        tab.accent = accent

        -- tab text
        local tabText = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tabText:SetPoint("LEFT", tab, "LEFT", 14, 0)
        tabText:SetText(def.Title)
        tabText:SetTextColor(0.6, 0.6, 0.6)
        tab.text = tabText

        -- hover effects
        tab:SetScript("OnEnter", function(self)
            if controller.activeKey ~= def.Key then
                self.bg:SetColorTexture(0.10, 0.10, 0.14, 1)
                self.text:SetTextColor(0.8, 0.8, 0.8)
            end
        end)
        tab:SetScript("OnLeave", function(self)
            if controller.activeKey ~= def.Key then
                self.bg:SetColorTexture(0.06, 0.06, 0.08, 1)
                self.text:SetTextColor(0.6, 0.6, 0.6)
            end
        end)

        tab:SetScript("OnClick", function()
            controller:SetActive(def.Key)
        end)

        controller.tabs[def.Key] = tab

        -- panel (content for this tab)
        local panel = CreateFrame("Frame", nil, contentArea)
        panel:SetAllPoints(contentArea)
        panel:Hide()
        controller.panels[def.Key] = panel

        -- build panel content
        if def.Build then
            def.Build(panel)
        end
    end

    -- tab switching
    function controller:SetActive(key)
        for k, tab in pairs(self.tabs) do
            if k == key then
                tab.bg:SetColorTexture(0.14, 0.14, 0.18, 1)
                tab.text:SetTextColor(1, 1, 1)
                tab.accent:Show()
                self.panels[k]:Show()
            else
                tab.bg:SetColorTexture(0.06, 0.06, 0.08, 1)
                tab.text:SetTextColor(0.6, 0.6, 0.6)
                tab.accent:Hide()
                self.panels[k]:Hide()
            end
        end
        self.activeKey = key
    end

    return controller
end

-------------------------------------------------------------------------------
-- styled scrollable content area
-------------------------------------------------------------------------------

function UI.CreateScrollFrame(parent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetAllPoints()

    local scrollFrame = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -28, 8)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(1) -- placeholder, updated OnSizeChanged
    scrollFrame:SetScrollChild(scrollChild)

    -- keep scroll child width in sync with scroll frame
    scrollFrame:SetScript("OnSizeChanged", function(_, w)
        scrollChild:SetWidth(w)
    end)

    -- style the scrollbar
    local scrollBar = scrollFrame.ScrollBar
    if scrollBar then
        local track = scrollBar:CreateTexture(nil, "BACKGROUND")
        track:SetAllPoints()
        track:SetColorTexture(0.06, 0.06, 0.08, 0.5)
    end

    container.scrollFrame = scrollFrame
    container.scrollChild = scrollChild

    -- helper to update scroll child height
    function container:SetContentHeight(h)
        scrollChild:SetHeight(h)
    end

    return container
end

-------------------------------------------------------------------------------
-- custom checkbox (no deprecated templates)
-------------------------------------------------------------------------------

function UI.CreateCheckbox(parent, label, getValue, setValue)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(24)

    -- checkbox button
    local btn = CreateFrame("CheckButton", nil, frame)
    btn:SetSize(18, 18)
    btn:SetPoint("LEFT", frame, "LEFT", 0, 0)

    -- checkbox background
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.12, 0.12, 0.15, 1)

    -- checkbox border
    SetFlatBackdrop(btn, 0.12, 0.12, 0.15, 1, 0.30, 0.30, 0.34, 1)

    -- check mark
    local check = btn:CreateTexture(nil, "OVERLAY")
    check:SetSize(12, 12)
    check:SetPoint("CENTER")
    check:SetColorTexture(UI.Colors.accent[1], UI.Colors.accent[2], UI.Colors.accent[3], 1)
    btn.check = check

    local function UpdateVisual()
        if getValue() then
            check:Show()
        else
            check:Hide()
        end
    end

    btn:SetScript("OnClick", function()
        setValue(not getValue())
        UpdateVisual()
    end)

    -- label text
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", btn, "RIGHT", 8, 0)
    text:SetText(label)
    text:SetTextColor(0.9, 0.9, 0.9)
    frame.label = text

    frame.Update = UpdateVisual
    frame.btn = btn

    -- initialize
    UpdateVisual()

    return frame
end

-------------------------------------------------------------------------------
-- custom dropdown (no UIDropDownMenuTemplate)
-------------------------------------------------------------------------------

function UI.CreateDropdown(parent, label, options, getValue, setValue)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(28)

    -- label
    if label then
        local labelText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        labelText:SetPoint("LEFT", frame, "LEFT", 0, 0)
        labelText:SetText(label)
        labelText:SetTextColor(0.7, 0.7, 0.7)
        frame.label = labelText
    end

    -- dropdown button
    local btn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    btn:SetSize(160, 24)
    btn:SetPoint("LEFT", frame, "LEFT", label and 120 or 0, 0)
    SetFlatBackdrop(btn, 0.10, 0.10, 0.13, 1, 0.25, 0.25, 0.30, 1)

    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btnText:SetPoint("LEFT", btn, "LEFT", 8, 0)
    btnText:SetPoint("RIGHT", btn, "RIGHT", -20, 0)
    btnText:SetJustifyH("LEFT")
    btnText:SetTextColor(0.9, 0.9, 0.9)
    btn.text = btnText

    -- arrow
    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arrow:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
    arrow:SetText("v")
    arrow:SetTextColor(0.5, 0.5, 0.5)

    -- dropdown menu
    local menu = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    menu:SetFrameStrata("TOOLTIP")
    menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    menu:SetWidth(btn:GetWidth())
    SetFlatBackdrop(menu, 0.08, 0.08, 0.10, 0.98, 0.25, 0.25, 0.30, 1)
    menu:Hide()

    local menuButtons = {}

    local function UpdateText()
        local current = getValue()
        for _, opt in ipairs(options) do
            if opt.value == current then
                btnText:SetText(opt.label)
                return
            end
        end
        btnText:SetText(current == nil and "Select..." or tostring(current))
    end

    local function BuildMenu()
        -- clear old buttons
        for _, b in ipairs(menuButtons) do b:Hide() end
        menuButtons = {}

        local h = 4
        for i, opt in ipairs(options) do
            local optBtn = CreateFrame("Button", nil, menu)
            optBtn:SetHeight(22)
            optBtn:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -(h))
            optBtn:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -2, -(h))

            local optBg = optBtn:CreateTexture(nil, "BACKGROUND")
            optBg:SetAllPoints()
            optBg:SetColorTexture(0, 0, 0, 0)

            local optText = optBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            optText:SetPoint("LEFT", optBtn, "LEFT", 8, 0)
            optText:SetText(opt.label)
            optText:SetTextColor(0.9, 0.9, 0.9)

            optBtn:SetScript("OnEnter", function()
                optBg:SetColorTexture(0.15, 0.15, 0.20, 1)
            end)
            optBtn:SetScript("OnLeave", function()
                optBg:SetColorTexture(0, 0, 0, 0)
            end)
            optBtn:SetScript("OnClick", function()
                setValue(opt.value)
                UpdateText()
                menu:Hide()
            end)

            table.insert(menuButtons, optBtn)
            h = h + 22
        end
        menu:SetHeight(h + 4)
    end

    btn:SetScript("OnClick", function()
        if menu:IsShown() then
            menu:Hide()
        else
            BuildMenu()
            menu:Show()
        end
    end)

    -- close menu when clicking elsewhere
    menu:SetScript("OnShow", function()
        menu:SetPropagateKeyboardInput(true)
    end)

    frame.Update = UpdateText
    frame.btn = btn
    frame.menu = menu

    UpdateText()
    return frame
end

-------------------------------------------------------------------------------
-- horizontal line with optional label
-------------------------------------------------------------------------------

function UI.CreateDivider(parent, text, yOffset)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(20)

    local line = frame:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetColorTexture(0.20, 0.20, 0.24, 1)

    if text then
        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("CENTER", frame, "CENTER", 0, 0)
        label:SetText(text)
        label:SetTextColor(0.5, 0.5, 0.5)

        line:SetPoint("LEFT", frame, "LEFT", 8, 0)
        line:SetPoint("RIGHT", label, "LEFT", -8, 0)

        local line2 = frame:CreateTexture(nil, "ARTWORK")
        line2:SetHeight(1)
        line2:SetPoint("LEFT", label, "RIGHT", 8, 0)
        line2:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
        line2:SetColorTexture(0.20, 0.20, 0.24, 1)
    else
        line:SetPoint("LEFT", frame, "LEFT", 8, 0)
        line:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
    end

    return frame
end

-------------------------------------------------------------------------------
-- spell icon + name + PvP coefficient text
-------------------------------------------------------------------------------

function UI.CreateSpellRow(parent, spellID, name, effectsText, r, g, b)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(UI.Sizes.rowH)
    frame.spellID = spellID

    -- spell icon
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(UI.Sizes.iconSize, UI.Sizes.iconSize)
    icon:SetPoint("LEFT", frame, "LEFT", 4, 0)
    local iconTex = PvPTip.Utils.GetSpellIcon(spellID)
    icon:SetTexture(iconTex)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.icon = icon

    -- name column uses a fixed 200px width from the left edge (icon + gap + text)
    -- this avoids the GetWidth()=0 bug when frame hasn't been laid out yet
    local NAME_RIGHT = 210

    -- spell name
    local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    nameText:SetPoint("RIGHT", frame, "LEFT", NAME_RIGHT, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    nameText:SetText(name or ("Spell #" .. spellID))
    nameText:SetTextColor(0.9, 0.9, 0.9)
    frame.nameText = nameText

    -- effects text (from fixed offset to right edge)
    local effText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    effText:SetPoint("LEFT", frame, "LEFT", NAME_RIGHT + 4, 0)
    effText:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
    effText:SetJustifyH("LEFT")
    effText:SetWordWrap(false)
    effText:SetText(effectsText or "")
    effText:SetTextColor(r or 0.9, g or 0.9, b or 0.9)
    frame.effText = effText

    -- hover highlight
    local highlight = frame:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.03)

    -- interactive: hover tooltip + shift-click spell link
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        if self.spellID and self.spellID > 0 then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.spellID)
            GameTooltip:Show()
        end
    end)
    frame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and IsModifiedClick("CHATLINK") then
            local link = C_Spell and C_Spell.GetSpellLink and C_Spell.GetSpellLink(self.spellID)
            if link then
                ChatEdit_InsertLink(link)
            end
        end
    end)

    return frame
end

-------------------------------------------------------------------------------
-- affected-by sub-row (dimmed modifier aura listing below a spell row)
-------------------------------------------------------------------------------

function UI.CreateAffectedByRow(parent, text)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(UI.Sizes.rowH - 4)

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", frame, "LEFT", 28, 0)
    label:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetText(text)
    label:SetTextColor(0.45, 0.45, 0.45)
    frame.label = label

    return frame
end

-------------------------------------------------------------------------------
-- color swatch that opens ColorPickerFrame
-------------------------------------------------------------------------------

function UI.CreateColorPicker(parent, label, getValue, setValue)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(24)

    -- label
    local labelText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("LEFT", frame, "LEFT", 0, 0)
    labelText:SetText(label)
    labelText:SetTextColor(0.9, 0.9, 0.9)

    -- color swatch
    local swatch = CreateFrame("Button", nil, frame, "BackdropTemplate")
    swatch:SetSize(20, 20)
    swatch:SetPoint("LEFT", frame, "LEFT", 120, 0)
    SetFlatBackdrop(swatch, 0, 0, 0, 1, 0.30, 0.30, 0.34, 1)

    local swatchColor = swatch:CreateTexture(nil, "OVERLAY")
    swatchColor:SetPoint("TOPLEFT", 2, -2)
    swatchColor:SetPoint("BOTTOMRIGHT", -2, 2)
    frame.swatchColor = swatchColor

    local function UpdateSwatch()
        local c = getValue()
        swatchColor:SetColorTexture(c[1], c[2], c[3], 1)
    end

    swatch:SetScript("OnClick", function()
        local c = getValue()
        local info = {}
        info.r, info.g, info.b = c[1], c[2], c[3]
        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            setValue({r, g, b})
            UpdateSwatch()
        end
        info.cancelFunc = function(prev)
            setValue({prev.r, prev.g, prev.b})
            UpdateSwatch()
        end
        info.hasOpacity = false
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow(info)
        else
            ColorPickerFrame:SetColorRGB(info.r, info.g, info.b)
            ColorPickerFrame.func = info.swatchFunc
            ColorPickerFrame.cancelFunc = info.cancelFunc
            ColorPickerFrame:Show()
        end
    end)

    frame.Update = UpdateSwatch
    UpdateSwatch()

    return frame
end

-------------------------------------------------------------------------------
-- section title with optional subtitle
-------------------------------------------------------------------------------

function UI.CreateSectionHeader(parent, title, subtitle)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(subtitle and 36 or 22)

    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, 0)
    titleText:SetText(title)
    titleText:SetTextColor(1, 0.82, 0)
    frame.titleText = titleText

    if subtitle then
        local subText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        subText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -2)
        subText:SetText(subtitle)
        subText:SetTextColor(0.5, 0.5, 0.5)
        frame.subText = subText
    end

    return frame
end
