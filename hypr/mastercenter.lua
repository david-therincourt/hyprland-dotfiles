-- ~/.config/hypr/mastercenter.lua
-- Layout « master au centre » pour écran panoramique (Hyprland 0.55, Lua)
--
--   | gauche |      centre      | droite |
--
-- • Colonnes fixes : la fenêtre centrale ne bouge jamais d'elle-même.
-- • Nouvelle fenêtre : toujours au centre (new_on_center), l'ancienne
--   centrale passe sur le côté selon l'ordre de remplissage.
-- • Chaque bureau a son propre état (colonnes, largeurs, extension).
-- • swapmaster      : échange RÉEL de places avec la fenêtre centrale
--                     (relancé depuis le centre → ramène la fenêtre précédente,
--                     y compris celle repoussée par une nouvelle fenêtre).
-- • move <dir>      : left/right fait passer la fenêtre d'une colonne de côté
--                     à l'autre (sans toucher au centre) ; up/down la déplace
--                     dans sa colonne.
-- • split           : coupure sur demande — réserve une place vide SOUS la
--                     fenêtre active (colonne de côté). Plusieurs réservations
--                     possibles : les fenêtres ouvertes les remplissent dans
--                     l'ordre. Relancé sur la même fenêtre → annule sa réservation.
--                     Lancé depuis le centre → annule toutes les réservations.
-- • extend <dir>    : le centre recouvre la colonne de droite (ou de gauche),
--                     dont les fenêtres passent de l'autre côté. Direction
--                     opposée → retour à la normale, fenêtres remises en place.
-- • flip            : inverse les colonnes gauche et droite, chaque fenêtre
--                     garde sa ligne (relancé → retour à l'état initial).
-- • resize <dir>    : redimensionne la fenêtre active (centre compris) :
--                     largeur des colonnes avec ←/→, hauteur dans une
--                     colonne de côté avec ↑/↓.
-- • Ordre de remplissage : centre, droite (state.opener), puis gauche, droite,
--   gauche… en commençant par state.first à égalité :
--   centre, droite, gauche, gauche bas, droite bas, gauche bas, …
--
-- Activation dans hyprland.lua :
--   require("mastercenter")
--   hl.config({ general = { layout = "lua:mastercenter" } })

-- Un état par bureau : chaque bureau garde ses colonnes, largeurs et extension.
local function new_state()
    return {
        center = nil,        -- identifiant de la fenêtre centrale
        left = {},           -- colonne gauche (de haut en bas)
        right = {},          -- colonne droite (de haut en bas)
        left_w = 0.315,      -- largeur de la colonne gauche (fraction de l'écran)
        right_w = 0.315,     -- largeur de la colonne droite (le centre prend le reste)
        weight = {},         -- hauteur relative de chaque fenêtre de côté (1 par défaut)
        extend = nil,        -- nil | "left" | "right" : colonne recouverte par le centre
        moved = nil,         -- fenêtres déplacées par « extend » (pour les remettre)
        new_on_center = true, -- true : une nouvelle fenêtre prend toujours le centre
        keep_empty = true,   -- true : le centre reste vide quand sa fenêtre se ferme
        opener = "right",    -- côté de la 2ᵉ fenêtre (la première de côté)
        first = "left",      -- ensuite, côté prioritaire à égalité : "left" ou "right"
        single_full = false, -- true : une fenêtre seule occupe tout l'écran
        last_swap = nil,     -- { id } : fenêtre à ramener au centre (Super + Entrée depuis le centre)
        pending = {},        -- liste de { col, after } : places réservées par « split »
        count = 0,
    }
end

local states = {}            -- un état par bureau occupé
local state = new_state()    -- état du bureau en cours de traitement

-- Retrouve l'état du bureau d'après ses fenêtres (celui qui en contient le plus)
local function select_state(ctx)
    local ids = {}
    for _, target in ipairs(ctx.targets) do
        local w = target.window
        ids[w and tostring(w.stable_id) or tostring(target.index)] = true
    end
    local best, score = nil, 0
    for _, st in ipairs(states) do
        local n = (st.center and ids[st.center]) and 1 or 0
        for _, id in ipairs(st.left) do if ids[id] then n = n + 1 end end
        for _, id in ipairs(st.right) do if ids[id] then n = n + 1 end end
        if n > score then best, score = st, n end
    end
    if not best then
        best = new_state()
        table.insert(states, best)
    end
    state = best
end

-- Oublie les états des bureaux devenus vides
local function drop_empty()
    local out = {}
    for _, st in ipairs(states) do
        if st.center or #st.left > 0 or #st.right > 0 then table.insert(out, st) end
    end
    states = out
end

---------------------------------------------------------------- utilitaires

local function target_id(target)
    local window = target.window
    return window and tostring(window.stable_id) or tostring(target.index)
end

local function active_id(ctx)
    for _, target in ipairs(ctx.targets) do
        local window = target.window
        if window and window.active then
            return target_id(target)
        end
    end
end

local function index_of(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then
            return i
        end
    end
end

local function clamp(x, min, max)
    return math.max(min, math.min(max, x))
end

-- Où se trouve une fenêtre ? → "center" | "left" | "right", index
local function locate(id)
    if id == nil then return nil end
    if state.center == id then return "center", 1 end
    local i = index_of(state.left, id)
    if i then return "left", i end
    i = index_of(state.right, id)
    if i then return "right", i end
end

local function column(name)
    return name == "left" and state.left or state.right
end

-- colonne prioritaire (state.first) puis l'autre
local function sides()
    if state.first == "right" then
        return state.right, state.left
    end
    return state.left, state.right
end

---------------------------------------------------------------- synchronisation

local function sync(ctx)
    local present, targets, n = {}, {}, 0
    for _, target in ipairs(ctx.targets) do
        local id = target_id(target)
        present[id] = true
        targets[id] = target
        n = n + 1
    end

    -- retirer les fenêtres fermées
    local function keep(list)
        local out = {}
        for _, id in ipairs(list) do
            if present[id] then table.insert(out, id) end
        end
        return out
    end
    state.left = keep(state.left)
    state.right = keep(state.right)
    if state.center and not present[state.center] then
        state.center = nil
    end

    -- centre vide : on le laisse vide (keep_empty), sinon on promeut la
    -- première fenêtre du côté prioritaire, puis de l'autre
    if not state.center and not state.keep_empty then
        local a, b = sides()
        if #a > 0 then
            state.center = table.remove(a, 1)
        elseif #b > 0 then
            state.center = table.remove(b, 1)
        end
    end

    -- une réservation n'a plus de sens si sa fenêtre de référence a disparu
    local still = {}
    for _, p in ipairs(state.pending) do
        if present[p.after] and locate(p.after) == p.col then
            table.insert(still, p)
        end
    end
    state.pending = still

    -- range une fenêtre dans une colonne de côté, selon l'ordre de remplissage
    local function to_side(id)
        if #state.pending > 0 then
            local p = table.remove(state.pending, 1)   -- première réservée, première remplie
            local col = column(p.col)
            local i = index_of(col, p.after)
            table.insert(col, (i or #col) + 1, id)
            return
        elseif state.extend then
            -- centre étendu : une seule colonne de côté disponible
            table.insert(column(state.extend == "right" and "left" or "right"), id)
        elseif #state.left + #state.right == 0 then
            table.insert(column(state.opener), id)   -- 2ᵉ fenêtre
        else
            local a, b = sides()   -- à égalité, le côté prioritaire l'emporte
            if #a <= #b then
                table.insert(a, id)
            else
                table.insert(b, id)
            end
        end
    end

    -- placer les nouvelles fenêtres
    local pushed = nil   -- ancien centre repoussé par une nouvelle fenêtre
    for _, target in ipairs(ctx.targets) do
        local id = target_id(target)
        if not locate(id) then
            if not state.center then
                state.center = id
            elseif state.new_on_center then
                pushed = state.center
                to_side(state.center)              -- l'ancien centre passe sur le côté
                state.center = id
            else
                to_side(id)
            end
        end
    end

    if n ~= state.count then
        state.last_swap = nil -- ouverture/fermeture : on oublie l'échange
        state.count = n
    end
    -- nouvelle fenêtre au centre : Super + Entrée y ramène l'ancienne
    if pushed then
        state.last_swap = { id = pushed }
    end

    return targets
end

---------------------------------------------------------------- placement

-- Case k (1 = haut) d'une colonne ; w = hauteurs relatives des cases
local function row(ctx, area, k, w)
    if #w == 1 then return area end
    local total, upto = 0, 0
    for j, x in ipairs(w) do
        total = total + x
        if j <= k then upto = upto + x end
    end
    local upper = ctx:split(area, "top", upto / total)   -- les k premières cases
    if k == 1 then return upper end
    return ctx:split(upper, "bottom", w[k] / upto)        -- la dernière d'entre elles
end

-- Place une colonne de côté : fenêtres + places vides réservées sous
-- les fenêtres concernées (une case vide par réservation).
local function place_side(ctx, targets, name, area)
    local col = column(name)
    if #col == 0 then return end

    local reserved = {}
    for _, p in ipairs(state.pending) do
        if p.col == name then
            reserved[p.after] = (reserved[p.after] or 0) + 1
        end
    end

    -- liste d'affichage : identifiant de fenêtre ou false (case vide)
    local slots = {}
    for _, id in ipairs(col) do
        table.insert(slots, id)
        for _ = 1, (reserved[id] or 0) do
            table.insert(slots, false)
        end
    end

    local w = {}
    for k, id in ipairs(slots) do
        w[k] = id and (state.weight[id] or 1) or 1   -- case vide : hauteur 1
    end
    for k, id in ipairs(slots) do
        if id then
            targets[id]:place(row(ctx, area, k, w))
        end
    end
end

hl.layout.register("mastercenter", {
    recalculate = function(ctx)
        select_state(ctx)
        local targets = sync(ctx)
        drop_empty()
        local n = (state.center and 1 or 0) + #state.left + #state.right
        if n == 0 then
            return
        end

        local area = ctx.area

        if state.center and n == 1 and state.single_full and #state.pending == 0 then
            targets[state.center]:place(area)
            return
        end

        local lw, rw = state.left_w, state.right_w
        local left_area, center_area, right_area

        if state.extend == "right" then        -- centre + colonne droite
            left_area = ctx:split(area, "left", lw)
            center_area = ctx:split(area, "right", 1 - lw)
        elseif state.extend == "left" then     -- colonne gauche + centre
            right_area = ctx:split(area, "right", rw)
            center_area = ctx:split(area, "left", 1 - rw)
        else
            left_area = ctx:split(area, "left", lw)
            local rest = ctx:split(area, "right", 1 - lw)
            center_area = ctx:split(rest, "left", (1 - lw - rw) / (1 - lw))
            right_area = ctx:split(rest, "right", rw / (1 - lw))
        end

        if state.center then
            targets[state.center]:place(center_area)   -- sinon : place vide
        end
        if right_area then place_side(ctx, targets, "right", right_area) end
        if left_area then place_side(ctx, targets, "left", left_area) end
    end,

    layout_msg = function(ctx, msg)
        select_state(ctx)
        local command, arg = msg:match("^(%S+)%s*(%S*)")
        local id = active_id(ctx)
        local where, i = locate(id)

        ---------------------------------------------------- swapmaster
        if command == "swapmaster" then
            if not where then return true end
            if where == "center" then
                local s = state.last_swap
                if s then
                    local col_name, k = locate(s.id)
                    if col_name == "left" or col_name == "right" then
                        local col = column(col_name)
                        state.last_swap = { id = state.center }   -- relancer → rééchange
                        state.center, col[k] = col[k], state.center
                    else
                        state.last_swap = nil
                    end
                end
            elseif not state.center then
                -- centre vide : la fenêtre y va simplement
                state.center = table.remove(column(where), i)
                state.last_swap = nil
            else
                local col = column(where)
                state.last_swap = { id = state.center }   -- pour revenir en arrière
                state.center, col[i] = col[i], state.center
            end

        ---------------------------------------------------- move
        elseif command == "move" then
            if not where then return true end
            -- gauche/droite : passe d'une colonne de côté à l'autre, à la même
            -- hauteur ; le centre n'est jamais touché (→ swapmaster pour ça)
            local function cross(from, to)
                local src, dst = column(from), column(to)
                table.remove(src, i)
                table.insert(dst, math.min(i, #dst + 1), id)
            end

            -- pas de passage vers une colonne recouverte par le centre étendu
            if arg == "left" then
                if where == "right" and state.extend ~= "left" then cross("right", "left") end
            elseif arg == "right" then
                if where == "left" and state.extend ~= "right" then cross("left", "right") end
            elseif (arg == "up" or arg == "down") and where ~= "center" then
                local col = column(where)
                local j = arg == "up" and i - 1 or i + 1
                if col[j] then
                    col[i], col[j] = col[j], col[i]
                end
            end
            state.last_swap = nil

        ---------------------------------------------------- split (sur demande)
        elseif command == "split" then
            if where == "left" or where == "right" then
                local found
                for k, p in ipairs(state.pending) do
                    if p.after == id then found = k end
                end
                if found then
                    table.remove(state.pending, found)   -- annuler cette réservation
                else
                    table.insert(state.pending, { col = where, after = id })
                end
            elseif where == "center" then
                state.pending = {}                       -- tout annuler
            end

        ---------------------------------------------------- extension du centre
        -- trois positions : étendu à gauche ← normal → étendu à droite
        elseif command == "extend" then
            local function cover(name)        -- le centre recouvre la colonne « name »
                local src = column(name)
                local dst = column(name == "right" and "left" or "right")
                state.moved = {}
                for _, w in ipairs(src) do
                    table.insert(dst, w)
                    table.insert(state.moved, w)
                end
                if name == "right" then state.right = {} else state.left = {} end
                state.extend = name
            end
            local function restore()          -- les fenêtres déplacées reprennent leur côté
                local name = state.extend
                local back = column(name)
                local other = column(name == "right" and "left" or "right")
                for _, w in ipairs(state.moved or {}) do
                    local k = index_of(other, w)
                    if k then
                        table.remove(other, k)
                        table.insert(back, w)
                    end
                end
                state.moved = nil
                state.extend = nil
            end

            if arg ~= "left" and arg ~= "right" then
                return "mastercenter: extend left ou extend right"
            end
            if state.extend == nil then
                cover(arg)
            elseif state.extend ~= arg then
                restore()                     -- direction opposée : retour au normal
            end
            state.pending = {}
            state.last_swap = nil

        ---------------------------------------------------- flip
        -- inverse les colonnes gauche et droite (ordre vertical conservé)
        elseif command == "flip" then
            local other = { left = "right", right = "left" }
            state.left, state.right = state.right, state.left
            state.left_w, state.right_w = state.right_w, state.left_w
            if state.extend then state.extend = other[state.extend] end
            for _, p in ipairs(state.pending) do p.col = other[p.col] end

        ---------------------------------------------------- largeur
        -- resize <dir> : la flèche déplace la bordure intérieure
        --   centre      : → / ← élargit / rétrécit (des deux côtés)
        --   côté gauche : → / ← élargit / rétrécit la colonne
        --   côté droit  : ← / → élargit / rétrécit la colonne
        --   côtés       : ↓ / ↑ agrandit / réduit la hauteur de la fenêtre
        elseif command == "resize" then
            if not where then return true end
            local STEP, MIN_SIDE, MIN_CENTER = 0.025, 0.1, 0.25
            local function set_widths(lw, rw)
                if lw >= MIN_SIDE and rw >= MIN_SIDE and 1 - lw - rw >= MIN_CENTER then
                    state.left_w, state.right_w = lw, rw
                end
            end
            local lw, rw = state.left_w, state.right_w

            if where == "center" then
                if arg == "right" then set_widths(lw - STEP, rw - STEP)
                elseif arg == "left" then set_widths(lw + STEP, rw + STEP) end
            elseif arg == "left" or arg == "right" then
                local wider = (where == "left") == (arg == "right")
                local d = wider and 2 * STEP or -2 * STEP
                if where == "left" then set_widths(lw + d, rw) else set_widths(lw, rw + d) end
            elseif arg == "up" or arg == "down" then
                local x = (state.weight[id] or 1) + (arg == "down" and 0.25 or -0.25)
                state.weight[id] = clamp(x, 0.25, 4)
            end

        else
            return "mastercenter: attendu swapmaster, move <dir>, split, extend <dir>, resize <dir> ou flip"
        end

        return true
    end,
})
