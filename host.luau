--!strict
-- AI Workflows: the board block (host half).
-- Problems live in one file, .ai-workflows/problems.json (B3, rev. 5). Each has a short name that
-- becomes .scratch/<name>/ once to-spec, to-tickets or wayfinder writes there; the plugin never creates
-- that folder. Workflows come from workflows.json (B2); checklist with a copy button per step (C1),
-- linked omp session (A2), «Configura repo» (B1), archive and delete. Agents come from tern.kv,
-- published by the window half (A3). Secret scan of .scratch/ and problems.json (B5): secrets.luau.

local ui = tern.ui
local Secrets = require("./secrets")

local VERSION = "0.4.0"
local AGENTS_KEY = "agents"
local SCAN_EVERY_MS = 3000
local SHORT_MAX = 40

type Field = { text: string, caret: number }

type Form = {
	editing: string?, -- id of the problem being edited; nil when new
	focus: string, -- "title" | "short" | "brief"
	title: Field,
	short: Field,
	brief: Field,
	shortTouched: boolean, -- the user typed in «Nome breve»: stop following the title
	errs: { [string]: string },
}

type State = {
	dir: string,
	screen: string, -- "home" | "situation" | "workflow" | "archive"
	current: string?, -- id of the open problem
	changing: boolean, -- situation screen opened by «Cambia workflow»
	layer: string?, -- "form" | "link" | "setup" | "confirm"
	form: Form?,
	confirm: string?, -- id to delete
	tracker: string,
	domain: string,
	flows: any,
	flowsSource: string,
	all: { any },
	err: string?,
	secrets: { Secrets.Finding },
	scannedAt: number,
}

local FORM_ORDER = { "title", "short", "brief" }
local FORM_INPUTS: { [string]: string } = {
	title = "layer.form.f_title.title",
	short = "layer.form.f_short.short",
	brief = "layer.form.f_brief.brief",
}

-- Text fields (caret in code points, sent to Tern in UTF-16 units).

local function cplen(text: string): number
	return utf8.len(text) or #text
end

local function byteat(text: string, cp: number): number
	return utf8.offset(text, cp + 1) or (#text + 1)
end

local function units(text: string, cp: number): number
	local n, i = 0, 0
	for _, code in utf8.codes(text) do
		if i >= cp then
			break
		end
		n += if code > 0xFFFF then 2 else 1
		i += 1
	end
	return n
end

local function field(text: string): Field
	return { text = text, caret = cplen(text) }
end

local function finsert(f: Field, s: string)
	if utf8.len(s) == nil then
		return
	end
	local b = byteat(f.text, f.caret)
	f.text = string.sub(f.text, 1, b - 1) .. s .. string.sub(f.text, b)
	f.caret += cplen(s)
end

local function fedit(f: Field, key: Key): boolean
	local name = key.name
	if name == "backspace" then
		if f.caret > 0 then
			local a, b = byteat(f.text, f.caret - 1), byteat(f.text, f.caret)
			f.text = string.sub(f.text, 1, a - 1) .. string.sub(f.text, b)
			f.caret -= 1
		end
	elseif name == "delete" then
		if f.caret < cplen(f.text) then
			local a, b = byteat(f.text, f.caret), byteat(f.text, f.caret + 1)
			f.text = string.sub(f.text, 1, a - 1) .. string.sub(f.text, b)
		end
	elseif name == "left" then
		f.caret = math.max(0, f.caret - 1)
	elseif name == "right" then
		f.caret = math.min(cplen(f.text), f.caret + 1)
	elseif name == "home" then
		f.caret = 0
	elseif name == "end" then
		f.caret = cplen(f.text)
	elseif name == "paste" then
		finsert(f, (string.gsub(key.text or "", "[\r\n]+", " ")))
	elseif key.text and key.text ~= "" and not key.meta and (key.ctrl == key.alt) then
		-- ctrl+alt together is AltGr on European layouts.
		finsert(f, key.text)
	else
		return false
	end
	return true
end

local function focus(cx: BlockCx, id: string)
	cx:render()
	cx:frame({ { "focus", id } })
end

-- Small helpers.

local function trim(s: string): string
	return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

local function join(...: string): string
	return table.concat({ ... }, "\\")
end

local function now(): string
	return os.date("%Y-%m-%d %H:%M") :: string
end

local function keyed(node: Node, key: string): Node
	local p: { [string]: any } = node.p or {}
	p.key = key
	node.p = p
	return node
end

local function line(key: string, spans: { Span }): Node
	return keyed(ui.text(spans), key)
end

local ACCENTS = {
	["à"] = "a", ["á"] = "a", ["è"] = "e", ["é"] = "e", ["ì"] = "i", ["í"] = "i",
	["ò"] = "o", ["ó"] = "o", ["ù"] = "u", ["ú"] = "u", ["ç"] = "c", ["ñ"] = "n",
}

local function slugify(title: string): string
	local s = string.lower(title)
	for from, to in ACCENTS do
		s = (string.gsub(s, from, to))
	end
	s = (string.gsub(s, "[^a-z0-9]+", "-"))
	s = (string.gsub(s, "^%-+", ""))
	s = string.sub(s, 1, SHORT_MAX)
	s = (string.gsub(s, "%-+$", ""))
	return s
end

local function readjson(path: string): any
	if not tern.fs.exists(path) then
		return nil
	end
	local ok, text = pcall(tern.fs.read, path, 4 * 1024 * 1024)
	if not ok then
		return nil
	end
	local ok2, value = pcall(tern.json.decode, text)
	return if ok2 then value else nil
end

-- Workflows (B2): the repo copy wins over the plugin default.

local function loadFlows(state: State)
	local repo = join(state.dir, ".ai-workflows", "workflows.json")
	local flows = readjson(repo)
	if type(flows) == "table" and type(flows.situations) == "table" then
		state.flows, state.flowsSource = flows, ".ai-workflows/workflows.json"
		return
	end
	state.flows, state.flowsSource = readjson("workflows.json") or { situations = {}, skills = {} }, "predefiniti del plugin"
end

local function situation(state: State, id: string?): any
	for _, s in state.flows.situations do
		if s.id == id then
			return s
		end
	end
	return nil
end

-- Problems: one list in .ai-workflows/problems.json.

local function problemsPath(state: State): string
	return join(state.dir, ".ai-workflows", "problems.json")
end

local function folderPath(state: State, id: string): string
	return join(state.dir, ".scratch", id)
end

local function loadProblems(state: State)
	state.all = {}
	local data = readjson(problemsPath(state))
	if type(data) ~= "table" or type(data.problems) ~= "table" then
		return
	end
	for _, p in data.problems do
		if type(p) == "table" and type(p.id) == "string" and type(p.title) == "string" then
			table.insert(state.all, p)
		end
	end
end

local function saveProblems(state: State)
	local out = {}
	for _, p in state.all do
		table.insert(out, {
			id = p.id,
			title = p.title,
			brief = p.brief or "",
			workflow = p.workflow or tern.json.null,
			status = p.status,
			created = p.created,
			updated = p.updated,
			steps = p.steps or {},
			session = p.session or tern.json.null,
			sessions = tern.json.array(p.sessions or {}),
			history = tern.json.array(p.history or {}),
		})
	end
	tern.fs.mkdir(join(state.dir, ".ai-workflows"))
	tern.fs.write(problemsPath(state), tern.json.encode({ version = 1, problems = tern.json.array(out) }, true) .. "\n")
end

local function touch(state: State, p: any)
	p.updated = now()
	saveProblems(state)
end

local function listBy(state: State, archived: boolean): { any }
	local out = {}
	for _, p in state.all do
		if (p.status == "archived") == archived then
			table.insert(out, p)
		end
	end
	table.sort(out, function(a, b)
		return tostring(a.updated or "") > tostring(b.updated or "")
	end)
	return out
end

local function find(state: State, id: string?): any
	for _, p in state.all do
		if p.id == id then
			return p
		end
	end
	return nil
end

local function steps(p: any): { [string]: any }
	if type(p.steps) ~= "table" then
		p.steps = {}
	end
	return p.steps
end

local function progress(state: State, p: any): (number, number)
	local s = situation(state, p.workflow)
	if not s then
		return 0, 0
	end
	local done, total = 0, 0
	for i, st in s.steps do
		if not st.auto then
			total += 1
			if steps(p)[tostring(i)] then
				done += 1
			end
		end
	end
	return done, total
end

-- The .scratch/<id>/ folder the skills write: what it holds, if it exists.

type Folder = { spec: boolean, map: boolean, tickets: number }

local function folder(state: State, id: string): Folder?
	local dir = folderPath(state, id)
	local ok, names = pcall(tern.fs.list, dir)
	if not ok then
		return nil
	end
	local f: Folder = { spec = false, map = false, tickets = 0 }
	for _, n in names do
		if n == "spec.md" then
			f.spec = true
		elseif n == "map.md" then
			f.map = true
		end
	end
	local ok2, issues = pcall(tern.fs.list, join(dir, "issues"))
	if ok2 then
		for _, n in issues do
			if string.match(n, "%.md$") then
				f.tickets += 1
			end
		end
	end
	return f
end

local function describe(f: Folder?): string
	if not f then
		return "non ancora creata"
	end
	local parts = {}
	if f.spec then
		table.insert(parts, "spec")
	end
	if f.map then
		table.insert(parts, "mappa")
	end
	if f.tickets > 0 then
		table.insert(parts, f.tickets .. (if f.tickets == 1 then " ticket" else " ticket"))
	end
	return if #parts > 0 then table.concat(parts, " + ") else "vuota"
end

-- Agents (A2) and the repo setup state (B1).

local function agents(): { any }
	local list = tern.kv.get(AGENTS_KEY)
	return if type(list) == "table" then list else {}
end

local function agent(pane: any): any
	for _, a in agents() do
		if a.pane == pane then
			return a
		end
	end
	return nil
end

local function trackerStatus(state: State): string?
	local path = join(state.dir, "docs", "agents", "issue-tracker.md")
	if not tern.fs.exists(path) then
		return nil
	end
	local ok, text = pcall(tern.fs.read, path, 64 * 1024)
	if not ok then
		return "configurato"
	end
	return string.match(text, "#%s*Issue tracker:%s*([^\r\n]+)") or "configurato"
end

local function skillsInstalled(): boolean
	local home = tern.getenv("USERPROFILE") or tern.getenv("HOME") or ""
	return tern.fs.exists(join(home, ".agents", "skills", "setup-matt-pocock-skills", "SKILL.md"))
end

local function ternExe(): string
	local local_ = tern.getenv("LOCALAPPDATA")
	if local_ then
		-- tern.com is the CLI; tern.exe is the GUI and treats arguments as files to open.
		local exe = join(local_, "Programs", "Tern", "tern.com")
		if tern.fs.exists(exe) then
			return exe
		end
	end
	return "tern"
end

-- Runs `tern <command> [--window KEY] <args…>` in the window that sent the event, so files and tabs
-- open there and not in whichever window Tern considers first. Returns false when the spawn fails.
local function ternRun(window: string?, command: string, args: { string }): (boolean, string?)
	local argv = { ternExe(), command }
	if window then
		table.insert(argv, "--window")
		table.insert(argv, window)
	end
	for _, a in args do
		table.insert(argv, a)
	end
	local ok, err = pcall(tern.process.run, argv, { timeout_ms = 10000 }, function(_r) end)
	return ok, if ok then nil else tostring(err)
end

-- Copy (C1): the step button copies the invocation and brings the linked omp pane forward (T8).

local function fill(p: any, prompt: string): string
	local brief = trim(string.gsub(p.brief or "", "%s+", " "))
	local out = string.gsub(prompt, "{title}", function()
		return p.title
	end)
	out = string.gsub(out, "{slug}", function()
		return p.id
	end)
	out = string.gsub(out, "{brief}", function()
		return if brief ~= "" then ". " .. brief else ""
	end)
	return out
end

local function copyText(cx: BlockCx, text: string, pane: any, window: string?)
	cx:copy(text)
	if pane and agent(pane) then
		ternRun(window, "focus", { tostring(pane) })
		cx:toast("success", "Copiato negli appunti", "Incolla con Ctrl+V nel pane omp collegato")
	else
		cx:toast("success", "Copiato negli appunti", "Incolla con Ctrl+V nel pane omp")
	end
end

local TRACKERS = {
	{ id = "local", label = "Markdown locale (consigliato)", prompt = "local markdown" },
	{ id = "github", label = "GitHub", prompt = "GitHub" },
	{ id = "gitlab", label = "GitLab", prompt = "GitLab" },
	{ id = "other", label = "Altro…", prompt = "altro: te lo descrivo" },
}
local DOMAINS = {
	{ id = "single", label = "Un contesto (GLOSSARY.md + docs/adr/)", prompt = "single-context" },
	{ id = "multi", label = "Monorepo", prompt = "multi-context" },
}
local LABELS = { "needs-triage", "needs-info", "ready-for-agent", "ready-for-human", "wontfix" }

local function pickById(list: { any }, id: string): any
	for _, x in list do
		if x.id == id then
			return x
		end
	end
	return list[1]
end

local function setupPrompt(state: State): string
	return "/skill:setup-matt-pocock-skills Tracker: "
		.. pickById(TRACKERS, state.tracker).prompt
		.. ". Etichette di triage: quelle predefinite. Documenti di dominio: "
		.. pickById(DOMAINS, state.domain).prompt
		.. "."
end

local function ghLabels(): string
	local lines = {}
	for _, l in LABELS do
		table.insert(lines, "gh label create " .. l)
	end
	return table.concat(lines, "\n")
end

-- The problem form: new or edit.

local function newForm(state: State, p: any?): Form
	return {
		editing = if p then p.id else nil,
		focus = "title",
		title = field(if p then p.title else ""),
		short = field(if p then p.id else ""),
		brief = field(if p then (p.brief or "") else ""),
		shortTouched = p ~= nil,
		errs = {},
	}
end

local function shortLocked(state: State, f: Form): boolean
	return f.editing ~= nil and folder(state, f.editing :: string) ~= nil
end

local function validate(state: State, f: Form): boolean
	f.errs = {}
	if trim(f.title.text) == "" then
		f.errs.title = "Scrivi un titolo"
	end
	local short = f.short.text
	if short == "" then
		f.errs.short = "Scrivi un nome breve"
	elseif #short > SHORT_MAX then
		f.errs.short = "Al massimo " .. SHORT_MAX .. " caratteri"
	elseif not string.match(short, "^[a-z0-9][a-z0-9%-]*$") then
		f.errs.short = "Solo lettere minuscole, numeri e trattini"
	else
		local other = find(state, short)
		if other and other.id ~= f.editing then
			f.errs.short = "Già usato da «" .. other.title .. "»"
		elseif short ~= f.editing and tern.fs.exists(folderPath(state, short)) then
			f.errs.short = "Esiste già la cartella .scratch/" .. short .. "/"
		end
	end
	return next(f.errs) == nil
end

-- Views.

local function choice(prefix: string, list: { any }, selected: string): Node
	local buttons = {}
	for _, x in list do
		table.insert(buttons, ui.button(x.label, {
			key = x.id,
			size = "sm",
			on = x.id == selected,
			icon = if x.id == selected then "check" else nil,
			actions = { click = prefix .. "=" .. x.id },
		}))
	end
	return keyed(ui.row(buttons), prefix)
end

local function setupView(state: State): Node
	local installed = skillsInstalled()
	local status = trackerStatus(state)
	local children: { Node } = {
		line("status", {
			ui.span("Stato: ", "muted"),
			ui.span(if status then "configurato · " .. status else "non configurato", if status then "success" else "warning"),
		}),
		ui.rule("1 · Skill di Matt Pocock"),
		keyed(ui.row({
			ui.text({ ui.span(if installed then "Installate in ~/.agents/skills" else "Non trovate", if installed then "success" else "warning") }),
			ui.button("Copia comando di installazione", {
				key = "install",
				size = "sm",
				icon = "copy",
				actions = { click = "copyinstall" },
			}),
		}), "s1"),
		ui.rule("2 · Tracker"),
		choice("tracker", TRACKERS, state.tracker),
	}
	if state.tracker == "github" then
		table.insert(children, ui.rule("3 · Solo con GitHub"))
		table.insert(children, keyed(ui.row({
			ui.text({ ui.span("Serve gh con gh auth status a posto; il setup non crea le etichette.", "muted") }),
			ui.button("Copia gh label create", { key = "gh", size = "sm", icon = "copy", actions = { click = "copygh" } }),
		}), "s3"))
	end
	table.insert(children, ui.rule((if state.tracker == "github" then "4" else "3") .. " · Documenti di dominio"))
	table.insert(children, choice("domain", DOMAINS, state.domain))
	table.insert(children, ui.rule((if state.tracker == "github" then "5" else "4") .. " · Invocazione"))
	table.insert(children, keyed(ui.code(setupPrompt(state), "text"), "prompt"))
	table.insert(children, line("after", { ui.span("Dopo il setup, «Aggiorna» rilegge docs/agents/ e mostra il tracker configurato.", "muted") }))
	table.insert(children, keyed(ui.row({
		ui.button("Chiudi", { key = "close", variant = "quiet", keys = { "esc" }, actions = { click = "closelayer" } }),
		ui.button("Copia /skill:setup-matt-pocock-skills", { key = "copy", variant = "primary", icon = "copy", actions = { click = "copysetup" } }),
	}), "foot"))
	return ui.node("overlay", { key = "setup", head = "Configura repo", icon = "pen", size = "md", modal = true, foot = "layer.setup.foot" }, children)
end

local function formView(state: State, f: Form): Node
	local locked = shortLocked(state, f)
	local shortHint = if locked
		then "Bloccato: .scratch/" .. (f.editing :: string) .. "/ esiste già e i ticket vi fanno riferimento."
		else "Diventa la cartella .scratch/<nome>/ se una skill scrive spec, ticket o mappa."
	local shortInput: Node = if locked
		then ui.text({ ui.span(f.short.text, "mono") })
		else ui.node("input", {
			key = "short",
			text = f.short.text,
			cursor = if f.focus == "short" then units(f.short.text, f.short.caret) else nil,
			placeholder = "storico-note",
			mono = true,
		})
	return ui.node("overlay", {
		key = "form",
		head = if f.editing then "Modifica problema" else "Nuovo problema",
		icon = if f.editing then "pen" else "plus",
		size = "md",
		modal = true,
		foot = "layer.form.foot",
	}, {
		ui.node("field", { key = "f_title", label = "Titolo", required = true, error = f.errs.title }, {
			ui.node("input", {
				key = "title",
				text = f.title.text,
				cursor = if f.focus == "title" then units(f.title.text, f.title.caret) else nil,
				placeholder = "es. Storico delle note dei ticket",
			}),
		}),
		ui.node("field", { key = "f_short", label = "Nome breve", required = true, error = f.errs.short, hint = shortHint }, { shortInput }),
		ui.node("field", {
			key = "f_brief",
			label = "Descrizione",
			hint = "Cosa va fatto e perché. Entra nelle bozze dei prompt. Maiusc+Invio per andare a capo.",
		}, {
			ui.node("editor", {
				key = "brief",
				text = f.brief.text,
				cursor = if f.focus == "brief" then units(f.brief.text, f.brief.caret) else nil,
				placeholder = "es. Le note dei ticket devono avere uno storico consultabile dal tecnico.",
				maxLines = 6,
			}),
		}),
		keyed(ui.row({
			ui.button("Annulla", { key = "cancel", variant = "quiet", keys = { "esc" }, actions = { click = "closelayer" } }),
			ui.button(if f.editing then "Salva" else "Crea", { key = "save", variant = "primary", keys = { "enter" }, actions = { click = "saveform" } }),
		}), "foot"),
	})
end

local function samePath(a: any, b: string): boolean
	if type(a) ~= "string" then
		return false
	end
	local function norm(s: string): string
		return (string.gsub(string.gsub(string.lower(s), "/", "\\"), "\\+$", ""))
	end
	return norm(a) == norm(b)
end

local function linkView(state: State, p: any): Node
	local rows = {}
	local list = {}
	for _, a in agents() do
		table.insert(list, a)
	end
	table.sort(list, function(a, b)
		local ah, bh = samePath(a.cwd, state.dir), samePath(b.cwd, state.dir)
		if ah ~= bh then
			return ah
		end
		return tostring(a.title or "") < tostring(b.title or "")
	end)
	for _, a in list do
		local linked = p.session == a.pane
		table.insert(rows, {
			id = tostring(a.pane),
			cells = {
				{ text = { ui.span(tostring(a.title or "omp")) }, dot = if a.state == "idle" then "success" else "warning" },
				{ ui.span(tostring(a.cwd or ""), "muted") },
				{ button = { text = if linked then "Collegata" else "Collega", act = "link", variant = if linked then "quiet" else "primary", disabled = linked } },
			},
		})
	end
	return ui.node("overlay", { key = "link", head = "Collega una sessione omp", icon = "sparkle", size = "lg", modal = true, foot = "layer.link.foot" }, {
		ui.table({
			{ id = "t", head = "Sessione", grow = 2 },
			{ id = "c", head = "Cartella", grow = 1, truncate = "start", priority = -1 },
			{ id = "b", head = "", align = "end" },
		}, rows, { empty = { ui.span("Nessun omp aperto in Tern", "muted") } }),
		keyed(ui.row({
			ui.button("Chiudi", { key = "close", variant = "quiet", keys = { "esc" }, actions = { click = "closelayer" } }),
			ui.button("Nuova sessione omp in questa cartella", { key = "newomp", icon = "plus", actions = { click = "newomp" } }),
		}), "foot"),
	})
end

local function confirmView(state: State): Node?
	local p = find(state, state.confirm)
	if not p then
		return nil
	end
	local f = folder(state, p.id)
	local buttons: { Node } = {
		ui.button("Annulla", { key = "cancel", variant = "quiet", keys = { "esc" }, actions = { click = "closelayer" } }),
		ui.button("Solo il problema", { key = "one", variant = "danger", actions = { click = "delete=problem" } }),
	}
	if f then
		table.insert(buttons, ui.button("Problema e cartella", { key = "all", variant = "danger", actions = { click = "delete=folder" } }))
	end
	return ui.node("overlay", { key = "confirm", head = "Eliminare «" .. p.title .. "»?", icon = "trash", size = if f then "md" else "sm", modal = true, foot = "layer.confirm.foot" }, {
		line("t", {
			ui.span(
				if f
					then "La cartella .scratch/" .. p.id .. "/ contiene: " .. describe(f) .. ". «Solo il problema» la lascia dov'è."
					else "Il problema non ha una cartella in .scratch/.",
				"muted"
			),
		}),
		line("g", { ui.span("Senza git la cancellazione non si annulla.", "muted") }),
		keyed(ui.row(buttons), "foot"),
	})
end

-- B5: red band with the possible secrets; nothing is changed or blocked.
local function secretsView(state: State): Node?
	local list = state.secrets
	if #list == 0 then
		return nil
	end
	local rows: { Node } = {}
	for i, f in list do
		if i > 20 then
			table.insert(rows, line("more", { ui.span("… altri " .. (#list - 20) .. ": correggi questi e premi Aggiorna.", "muted") }))
			break
		end
		table.insert(rows, keyed(ui.row({
			ui.node("col", { key = "t", grow = 1, basis = 0 }, {
				ui.text({ ui.span(f.file .. ":" .. f.line, "mono") }),
				ui.text({ ui.span(f.masked, "mono"), ui.span("  " .. f.kind, "muted") }),
			}),
			ui.button("Apri", { key = "o", size = "sm", icon = "folder-open", actions = { click = "secopen=" .. f.key } }),
			ui.button("Ignora", { key = "i", size = "sm", variant = "quiet", title = "Falso allarme: non mostrarlo più", actions = { click = "secignore=" .. f.key } }),
		}), "f" .. i))
	end
	return ui.card("Possibili segreti: " .. #list, rows, {
		key = "secrets",
		icon = "warn",
		tone = "error",
		meta = "controlla prima del commit",
		collapsible = true,
	})
end

local function homeView(state: State): Node
	local status = trackerStatus(state)
	local active = listBy(state, false)
	local archived = listBy(state, true)
	local rows = {}
	for _, p in active do
		local s = situation(state, p.workflow)
		local done, total = progress(state, p)
		local a = p.session and agent(p.session)
		table.insert(rows, {
			id = p.id,
			cells = {
				{ ui.span(p.title) },
				{ ui.span(if s then s.label else "workflow da scegliere", if s then nil else "warning") },
				if total > 0 then ui.meter_cell(done / total) else { ui.span("—", "muted") },
				{ ui.span(if total > 0 then done .. "/" .. total else "", "muted") },
				{ text = { ui.span(if a then "omp · " .. tostring(a.state) else "nessuna", "muted") }, dot = if a then "success" else nil },
				{ button = { text = "Apri", act = "open", variant = "primary" } },
			},
		})
	end
	return ui.col({
		ui.card("AI Workflows", {
			ui.kv({
				{ "Cartella", state.dir },
				{ "Tracker", if status then status else "non configurato" },
				{ "Workflow", state.flowsSource },
				{ "Versione", VERSION },
			}),
		}, { key = "head", icon = "list-checks" }),
		secretsView(state) or line("nosecrets", {}),
		keyed(ui.row({
			ui.button("Nuovo problema", { key = "new", variant = "primary", icon = "plus", actions = { click = "new" } }),
			ui.button("Configura repo", { key = "setup", icon = "pen", actions = { click = "setup" } }),
			ui.button("Archivio (" .. #archived .. ")", { key = "arch", icon = "archive", variant = "quiet", actions = { click = "archive" } }),
			ui.button("Aggiorna", { key = "refresh", icon = "refresh", variant = "quiet", actions = { click = "refresh" } }),
		}), "bar"),
		ui.card("Problemi attivi", {
			ui.table({
				{ id = "t", head = "Problema", grow = 2 },
				{ id = "w", head = "Workflow", grow = 1, priority = -1 },
				{ id = "m", head = "Avanzamento" },
				{ id = "n", head = "", align = "end" },
				{ id = "s", head = "Sessione", priority = -2 },
				{ id = "b", head = "", align = "end" },
			}, rows, { selectable = true, empty = { ui.span("Nessun problema attivo: crea il primo con «Nuovo problema».", "muted") } }),
		}, { key = "list", icon = "stack" }),
	})
end

local function situationView(state: State, p: any): Node
	local rows = {}
	for _, s in state.flows.situations do
		local n = #s.steps
		table.insert(rows, {
			id = s.id,
			cells = {
				{ text = { ui.span(s.label) }, icon = if p and p.workflow == s.id then "check" else nil },
				{ ui.span(s.when or "", "muted") },
				{ ui.span(n .. (if n == 1 then " passo" else " passi"), "muted") },
			},
		})
	end
	return ui.col({
		ui.card("Che situazione è?", {
			line("t", { ui.span(if p then p.title else "", "accent") }),
			line(
				"h",
				{ ui.span(if state.changing then "I passi già fatti restano nello storico del problema." else "Scegli la riga che descrive il lavoro. Si può cambiare dopo.", "muted") }
			),
		}, { key = "head", icon = "list-checks" }),
		ui.table({
			{ id = "l", head = "Situazione", grow = 1 },
			{ id = "w", head = "Quando", grow = 2, priority = -1 },
			{ id = "n", head = "", align = "end" },
		}, rows, { selectable = true, selected = if p then p.workflow else nil }),
		keyed(ui.row({
			ui.button(if state.changing then "Annulla" else "Indietro", { key = "back", icon = "arrow-left", variant = "quiet", actions = { click = if state.changing then "open=" .. (if p then p.id else "") else "home" } }),
		}), "bar"),
	})
end

local function stepRow(p: any, i: number, st: any): Node
	local key = tostring(i)
	local done = steps(p)[key]
	local label = st.label or st.skill
	local action: Node
	if st.auto then
		action = ui.badge("automatica", "info")
	elseif st.skill == "setup-matt-pocock-skills" then
		action = ui.button("Configura repo", { key = "b", size = "sm", icon = "pen", actions = { click = "setup" } })
	elseif st.prompt then
		action = ui.button("", { key = "b", size = "sm", icon = "copy", title = fill(p, st.prompt), actions = { click = "copystep=" .. key } })
	else
		action = ui.text({})
	end
	local check: Node = if st.auto
		then ui.text({ ui.span("·", "muted") })
		else ui.el("input", { key = "c", type = "checkbox", name = "step", value = key, checked = done ~= nil })
	return keyed(ui.row({
		keyed(check, "c"),
		ui.node("col", { key = "t", grow = 1, basis = 0 }, {
			ui.text({ ui.span(i .. ". ", "muted"), ui.span(label, if done then "muted" else "accent"), ui.span(if done then "  fatto " .. tostring(done) else "", "success") }),
			ui.text({ ui.span(st.note or "", "muted") }),
		}),
		keyed(action, "b"),
	}), "s" .. key)
end

local function workflowView(state: State, p: any): Node
	local s = situation(state, p.workflow)
	local a = p.session and agent(p.session)
	local f = folder(state, p.id)
	local body: { Node } = {}
	if s then
		for i, st in s.steps do
			table.insert(body, stepRow(p, i, st))
			if st.sep then
				table.insert(body, keyed(ui.rule(st.sep), "sep" .. i))
			end
		end
	end
	local others = {}
	for _, sk in state.flows.skills or {} do
		table.insert(others, {
			id = sk.name,
			cells = {
				{ ui.span(sk.name, "mono") },
				{ ui.span(sk.desc or "", "muted") },
				if sk.auto then { badge = { text = "dal modello", tone = "info" } } else { button = { text = "Copia", act = "copyskill", icon = "copy" } },
			},
		})
	end
	local history = {}
	for _, h in p.history or {} do
		table.insert(history, { label = tostring(h.label or h.workflow), detail = "fino al " .. tostring(h.until_), value = tostring(h.done or "") .. " passi fatti", icon = "archive" })
	end
	local done, total = progress(state, p)
	local head: { Node } = {}
	if trim(p.brief or "") ~= "" then
		table.insert(head, line("brief", { ui.span(p.brief) }))
	end
	table.insert(head, ui.kv({
		{ "Workflow", if s then s.label else "—" },
		{ "Cartella", { ui.span(".scratch/" .. p.id .. "/", "mono"), ui.span("  " .. describe(f), "muted") } },
		{ "Sessione", if a then tostring(a.title or "omp") .. " · " .. tostring(a.state) else (if p.session then "chiusa" else "nessuna") },
	}))
	if f and (f.spec or f.map) then
		local open: { Node } = {}
		if f.spec then
			table.insert(open, ui.button("Apri spec", { key = "spec", size = "sm", icon = "folder-open", actions = { click = "openfile=spec.md" } }))
		end
		if f.map then
			table.insert(open, ui.button("Apri mappa", { key = "map", size = "sm", icon = "folder-open", actions = { click = "openfile=map.md" } }))
		end
		table.insert(head, keyed(ui.row(open), "open"))
	end
	if total > 0 then
		table.insert(head, ui.meter(done / total, done .. "/" .. total .. " passi"))
	end
	local children: { Node } = {
		ui.card(p.title, head, { key = "head", icon = "list-checks" }),
		secretsView(state) or line("nosecrets", {}),
		keyed(ui.row({
			ui.button("Home", { key = "home", icon = "arrow-left", variant = "quiet", actions = { click = "home" } }),
			ui.button(if p.session then "Cambia sessione" else "Collega", { key = "link", icon = "sparkle", variant = if a then "default" else "primary", actions = { click = "linkopen" } }),
			ui.button("Cambia workflow", { key = "change", icon = "repeat", actions = { click = "change" } }),
			ui.button("", { key = "edit", icon = "pen", variant = "quiet", title = "Modifica titolo, nome breve e descrizione", actions = { click = "edit" } }),
			ui.button("Archivia", { key = "arch", icon = "archive", variant = "quiet", actions = { click = "archiveit" } }),
		}), "bar"),
	}
	if s then
		if s.warn then
			table.insert(children, line("warn", { ui.span("⚠ " .. s.warn, "warning") }))
		end
		table.insert(children, ui.card("Passi", body, { key = "steps", icon = "list-checks", meta = "📋 copia l'invocazione · la casella segna fatto" }))
		local human = {}
		for _, h in s.human or {} do
			table.insert(human, { label = h, icon = "info" })
		end
		table.insert(children, ui.card("Cosa decidi tu", { ui.list(human) }, { key = "human", icon = "info", collapsible = true }))
	end
	table.insert(children, ui.card("Altre skill", {
		ui.table({ { id = "n", head = "Skill" }, { id = "d", head = "", grow = 1 }, { id = "b", head = "", align = "end" } }, others),
	}, { key = "others", icon = "sparkle", collapsible = true, collapsed = true, meta = #others .. "" }))
	if #history > 0 then
		table.insert(children, ui.card("Storico workflow", { ui.list(history) }, { key = "history", icon = "archive", collapsible = true, collapsed = true }))
	end
	return ui.col(children)
end

local function archiveView(state: State): Node
	local items: { Node } = {}
	for _, p in listBy(state, true) do
		local f = folder(state, p.id)
		table.insert(items, keyed(ui.row({
			ui.node("col", { key = "t", grow = 1, basis = 0 }, {
				ui.text({ ui.span(p.title) }),
				ui.text({
					ui.span(if f then ".scratch/" .. p.id .. "/ · " .. describe(f) else "nessuna cartella", "muted"),
					ui.span("  · archiviato " .. tostring(p.updated or ""), "muted"),
				}),
			}),
			ui.button("Ripristina", { key = "r", size = "sm", icon = "refresh", actions = { click = "restore=" .. p.id } }),
			ui.button("Elimina", { key = "e", size = "sm", icon = "trash", variant = "danger", actions = { click = "askdelete=" .. p.id } }),
		}), "p-" .. p.id))
	end
	if #items == 0 then
		table.insert(items, line("empty", { ui.span("Nessun problema archiviato.", "muted") }))
	end
	return ui.col({
		keyed(ui.row({ ui.button("Home", { key = "home", icon = "arrow-left", variant = "quiet", actions = { click = "home" } }) }), "bar"),
		ui.card("Archivio", items, { key = "list", icon = "archive", meta = "le cartelle in .scratch/ restano finché non le elimini" }),
	})
end

-- Mutations.

local function openProblem(state: State, id: string)
	local p = find(state, id)
	if not p then
		return
	end
	state.current = id
	state.changing = false
	state.screen = if p.workflow and situation(state, p.workflow) then "workflow" else "situation"
end

local function openForm(state: State, cx: BlockCx, p: any?)
	state.form = newForm(state, p)
	state.layer = "form"
	focus(cx, FORM_INPUTS.title)
end

local function saveForm(state: State, cx: BlockCx)
	local f = state.form
	if not f then
		return
	end
	if shortLocked(state, f) then
		f.short = field(f.editing :: string)
	end
	if not validate(state, f) then
		return
	end
	local title, short, brief = trim(f.title.text), f.short.text, trim(f.brief.text)
	local p = if f.editing then find(state, f.editing) else nil
	if p then
		p.title, p.id, p.brief = title, short, brief
	else
		p = { id = short, title = title, brief = brief, status = "active", created = now(), steps = {}, sessions = {}, history = {} }
		table.insert(state.all, p)
	end
	local ok, err = pcall(touch, state, p)
	if not ok then
		f.errs.title = "Salvataggio non riuscito: " .. tostring(err)
		return
	end
	state.layer, state.form = nil, nil
	if f.editing then
		state.current = short
		cx:toast("success", "Problema aggiornato", nil)
	else
		openProblem(state, short)
		cx:toast("success", "Problema creato", ".ai-workflows/problems.json")
	end
end

local function formKey(state: State, f: Form, key: Key, cx: BlockCx): boolean
	if key.name == "escape" then
		state.layer, state.form = nil, nil
	elseif key.name == "enter" and key.shift and f.focus == "brief" then
		finsert(f.brief, "\n")
	elseif key.name == "paste" and f.focus == "brief" then
		finsert(f.brief, (string.gsub(key.text or "", "\r\n?", "\n")))
	elseif key.name == "enter" then
		saveForm(state, cx)
	elseif key.name == "tab" then
		local order = if shortLocked(state, f) then { "title", "brief" } else FORM_ORDER
		local at = table.find(order, f.focus) or 1
		local step = if key.shift then -1 else 1
		f.focus = order[((at - 1 + step) % #order) + 1]
		focus(cx, FORM_INPUTS[f.focus])
	else
		if f.focus == "short" and shortLocked(state, f) then
			return false
		end
		local fld = (f :: any)[f.focus] :: Field
		local changed = fedit(fld, key)
		if not changed then
			return false
		end
		if f.focus == "title" and not f.shortTouched then
			f.short = field(slugify(f.title.text))
		elseif f.focus == "short" then
			f.shortTouched = true
			f.short.text = string.lower(f.short.text)
		end
		f.errs = {}
	end
	return true
end

local function chooseSituation(state: State, id: string)
	local p = find(state, state.current)
	if not p or not situation(state, id) then
		return
	end
	if state.changing and p.workflow and p.workflow ~= id then
		local done = 0
		for _ in steps(p) do
			done += 1
		end
		local old = situation(state, p.workflow)
		p.history = p.history or {}
		table.insert(p.history, { workflow = p.workflow, label = if old then old.label else p.workflow, done = done, until_ = now(), steps = p.steps })
		p.steps = {}
	end
	p.workflow = id
	touch(state, p)
	state.changing = false
	state.screen = "workflow"
end

local function link(state: State, pane: number)
	local p = find(state, state.current)
	if not p then
		return
	end
	local a = agent(pane)
	p.session = pane
	p.sessions = p.sessions or {}
	table.insert(p.sessions, { pane = pane, title = if a then a.title else nil, linked = now() })
	touch(state, p)
	state.layer = nil
end

local function scanSecrets(state: State)
	local ok, found = pcall(Secrets.scan, state.dir, Secrets.loadIgnored(state.dir))
	state.secrets = if ok then found else {}
	state.scannedAt = tern.now()
end

local function refresh(state: State)
	loadFlows(state)
	loadProblems(state)
	scanSecrets(state)
end

local function findSecret(state: State, key: string): Secrets.Finding?
	for _, f in state.secrets do
		if f.key == key then
			return f
		end
	end
	return nil
end

local board: BlockDef<State> = {
	init = function(cx, _args, saved)
		local dir = if type(saved) == "table" and type(saved.dir) == "string" then saved.dir else (cx.cwd or "")
		local state: State = {
			dir = dir,
			screen = "home",
			current = nil,
			changing = false,
			layer = nil,
			form = nil,
			confirm = nil,
			tracker = "local",
			domain = "single",
			flows = {},
			flowsSource = "",
			all = {},
			err = nil,
			secrets = {},
			scannedAt = 0,
		}
		refresh(state)
		if type(saved) == "table" and type(saved.current) == "string" and find(state, saved.current) then
			openProblem(state, saved.current)
		end
		return state
	end,
	title = function(state)
		local p = state.screen ~= "home" and find(state, state.current)
		return if p then "AI · " .. p.title else "AI Workflows"
	end,
	font = "sans",
	view = function(state, _cx)
		local p = find(state, state.current)
		local main: Node
		if state.screen == "situation" and p then
			main = situationView(state, p)
		elseif state.screen == "workflow" and p then
			main = workflowView(state, p)
		elseif state.screen == "archive" then
			main = archiveView(state)
		else
			main = homeView(state)
		end
		local layer: Node? = nil
		if state.layer == "form" and state.form then
			layer = formView(state, state.form :: Form)
		elseif state.layer == "setup" then
			layer = setupView(state)
		elseif state.layer == "link" and p then
			layer = linkView(state, p)
		elseif state.layer == "confirm" then
			layer = confirmView(state)
		end
		return { main = main, layer = if layer then ui.col({ layer }) else nil }
	end,
	key = function(state, key, cx)
		local f = state.form
		if state.layer == "form" and f then
			return formKey(state, f, key, cx)
		end
		if state.layer and key.name == "escape" then
			state.layer, state.confirm = nil, nil
			return true
		end
		return false
	end,
	event = function(state, ev, cx)
		-- Files change while the agent works: rescan at most every few seconds, on any interaction.
		if tern.now() - state.scannedAt > SCAN_EVERY_MS then
			scanSecrets(state)
		end
		if ev.ev == "focus" then
			local f = state.form
			if f then
				for k, id in FORM_INPUTS do
					if id == ev.id then
						f.focus = k
						focus(cx, id)
					end
				end
			end
			return
		end
		if ev.ev == "change" and ev.name == "step" then
			local p = find(state, state.current)
			if p then
				steps(p)[tostring(ev.value)] = if ev.checked then now() else nil
				touch(state, p)
			end
			return
		end
		if ev.ev == "select" then
			if state.screen == "situation" then
				chooseSituation(state, tostring(ev.item))
			elseif state.screen == "home" then
				openProblem(state, tostring(ev.item))
			end
			return
		end
		if ev.ev ~= "action" then
			return
		end
		local act, value = ev.act, ev.value
		local p = find(state, state.current)
		if act == "home" then
			state.screen, state.current, state.changing = "home", nil, false
			loadProblems(state)
		elseif act == "refresh" then
			refresh(state)
		elseif act == "secopen" then
			local f = findSecret(state, tostring(value))
			if f then
				local path = join(state.dir, (string.gsub(f.file, "/", "\\"))) .. ":" .. f.line
				local ok, err = ternRun(ev.window, "open", { path })
				if not ok then
					cx:toast("error", "Impossibile aprire il file", tostring(err))
				end
			end
		elseif act == "secignore" then
			local f = findSecret(state, tostring(value))
			if f then
				local ok, err = pcall(Secrets.ignore, state.dir, f)
				scanSecrets(state)
				cx:toast(if ok then "info" else "error", if ok then "Segnato come falso allarme" else "Non riuscito", if ok then ".ai-workflows/secrets-ignore.json" else tostring(err))
			end
		elseif act == "new" then
			openForm(state, cx, nil)
		elseif act == "edit" and p then
			openForm(state, cx, p)
		elseif act == "saveform" then
			saveForm(state, cx)
		elseif act == "open" then
			openProblem(state, tostring(value or ev.item))
		elseif act == "openfile" and p then
			cx:open(join(folderPath(state, p.id), tostring(value)))
		elseif act == "archive" then
			loadProblems(state)
			state.screen = "archive"
		elseif act == "setup" then
			state.layer = "setup"
		elseif act == "closelayer" then
			state.layer, state.confirm, state.form = nil, nil, nil
		elseif act == "tracker" then
			state.tracker = tostring(value)
		elseif act == "domain" then
			state.domain = tostring(value)
		elseif act == "copyinstall" then
			copyText(cx, "npx skills@latest add mattpocock/skills -g -a codex", nil)
		elseif act == "copygh" then
			copyText(cx, ghLabels(), nil)
		elseif act == "copysetup" then
			copyText(cx, setupPrompt(state), p and p.session, ev.window)
		elseif act == "copystep" and p then
			local s = situation(state, p.workflow)
			local st = s and s.steps[tonumber(value) or 0]
			if st and st.prompt then
				copyText(cx, fill(p, st.prompt), p.session, ev.window)
			end
		elseif act == "copyskill" and p then
			copyText(cx, "/skill:" .. tostring(ev.item) .. " ", p.session, ev.window)
		elseif act == "linkopen" then
			state.layer = "link"
		elseif act == "link" then
			link(state, tonumber(ev.item) :: number)
		elseif act == "newomp" then
			local ok, err = ternRun(ev.window, "new", { "tab", "--cwd", state.dir, "--", "omp" })
			cx:toast(if ok then "info" else "error", if ok then "Nuova sessione omp aperta" else "Impossibile avviare tern", if ok then "Poi collegala da questa lista" else tostring(err))
		elseif act == "change" then
			state.changing = true
			state.screen = "situation"
		elseif act == "archiveit" and p then
			p.status = "archived"
			touch(state, p)
			state.screen, state.current = "home", nil
			cx:toast("info", "Problema archiviato", if folder(state, p.id) then "La cartella .scratch/" .. p.id .. "/ resta dov'è" else nil)
		elseif act == "restore" then
			local q = find(state, tostring(value or ev.item))
			if q then
				q.status = "active"
				touch(state, q)
			end
		elseif act == "askdelete" then
			state.confirm, state.layer = tostring(value or ev.item), "confirm"
		elseif act == "delete" and state.confirm then
			local id = state.confirm :: string
			local ok, err = true, nil
			if value == "folder" and folder(state, id) then
				ok, err = pcall(tern.fs.remove, folderPath(state, id))
			end
			if ok then
				for i, q in state.all do
					if q.id == id then
						table.remove(state.all, i)
						break
					end
				end
				ok, err = pcall(saveProblems, state)
			end
			state.layer, state.confirm = nil, nil
			if ok then
				cx:toast("success", "Eliminato", if value == "folder" then "Problema e .scratch/" .. id .. "/" else "Problema; la cartella resta")
			else
				cx:toast("error", "Eliminazione non riuscita", tostring(err))
			end
		end
	end,
	save = function(state)
		return { dir = state.dir, current = if state.screen ~= "home" then state.current else nil }
	end,
}

tern.block.define("board", board)
