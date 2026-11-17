--!strict
-- Secret scan (B5, T9): looks for known secret shapes in the files that end up in the commit
-- (.scratch/ and .ai-workflows/problems.json). It only reads and reports: it never edits a file
-- and never blocks anything. A secret with no recognisable label or prefix is not found.
-- «Ignora» stores file + kind + a hash of the value in .ai-workflows/secrets-ignore.json, never
-- the value itself, so the ignore list is safe to commit.

local MAX_FILE = 512 * 1024
local MAX_FILES = 400

export type Finding = {
	file: string, -- path relative to the repo, with forward slashes
	line: number,
	kind: string, -- label shown to the user
	masked: string,
	key: string, -- file|kind|hash, used by «Ignora»
}

local function join(...: string): string
	return table.concat({ ... }, "\\")
end

-- FNV-1a, 32 bit: enough to recognise an ignored value without storing it.
local function hash(s: string): string
	local h = 2166136261
	for i = 1, #s do
		h = bit32.bxor(h, string.byte(s, i))
		h = (h * 16777619) % 4294967296
	end
	return string.format("%08x", h)
end

local function mask(value: string, prefix: string?): string
	local tail = if #value > 8 then string.sub(value, -3) else ""
	return (prefix or "****") .. (if prefix then "…" else "") .. tail
end

-- Values that are placeholders, not secrets: <…>, ${…}, {{…}}, ***, xxx, "..." and the like.
local function placeholder(v: string): boolean
	local l = string.lower(v)
	return string.match(v, "^[<%${%[]") ~= nil
		or string.match(l, "^[%*x%.]+$") ~= nil
		or string.match(l, "^%*+") ~= nil
		or l == "null" or l == "none" or l == "true" or l == "false"
		or string.match(l, "^your") ~= nil
		or string.match(l, "^example") ~= nil
end

-- Labelled values: the label is matched on the lowercased line, the value is cut from the original
-- line at the same byte positions (string.lower only touches ASCII, so positions do not move).
local LABELLED = {
	{ kind = "password", pat = "password%s*[=:]%s*", min = 4 },
	{ kind = "password", pat = "passwd%s*[=:]%s*", min = 4 },
	{ kind = "password", pat = "pwd%s*=%s*", min = 4 },
	{ kind = "token", pat = "token%s*[=:]%s*", min = 8 },
	{ kind = "api key", pat = "api[_%-]?key%s*[=:]%s*", min = 8 },
	{ kind = "secret", pat = "secret%s*[=:]%s*", min = 8 },
	{ kind = "Bearer", pat = "authorization%s*:%s*bearer%s+", min = 10 },
	{ kind = "Bearer", pat = "bearer%s+", min = 20 },
}

-- Prefixed tokens: { kind, pattern on the original line, prefix shown in the mask, minimum length }.
local PREFIXED = {
	{ kind = "token GitHub", pat = "ghp_[%w]+", prefix = "ghp_", min = 30 },
	{ kind = "token GitHub", pat = "github_pat_[%w_]+", prefix = "github_pat_", min = 40 },
	{ kind = "chiave API", pat = "sk%-[%w%-_]+", prefix = "sk-", min = 20 },
	{ kind = "chiave AWS", pat = "AKIA[%u%d]+", prefix = "AKIA", min = 20 },
}

-- Each value is reported once per line: prefixed rules run first because their kind and mask are more
-- precise («OPENAI_API_KEY=sk-…» is a «chiave API», not also an «api key»).
local function scanLine(text: string, add: (kind: string, value: string, prefix: string?) -> ())
	local seen: { [string]: boolean } = {}
	local function report(kind: string, value: string, prefix: string?)
		if not seen[value] then
			seen[value] = true
			add(kind, value, prefix)
		end
	end
	for _, rule in PREFIXED do
		local from = 1
		while true do
			local s, e = string.find(text, rule.pat, from)
			if not s then
				break
			end
			from = (e :: number) + 1
			local before = if (s :: number) > 1 then string.sub(text, (s :: number) - 1, (s :: number) - 1) else ""
			local value = string.sub(text, s :: number, e :: number)
			if #value >= rule.min and not string.match(before, "[%w_%-]") then
				report(rule.kind, value, rule.prefix)
			end
		end
	end
	local lower = string.lower(text)
	for _, rule in LABELLED do
		local from = 1
		while true do
			local s, e = string.find(lower, rule.pat, from)
			if not s then
				break
			end
			from = (e :: number) + 1
			local rest = string.sub(text, from)
			local quoted = string.match(rest, "^[\"'`]")
			local value = if quoted
				then string.match(rest, "^" .. quoted .. "([^\"'`]+)")
				else string.match(rest, "^([^%s;,\"'`)<>|]+)")
			if value and #value >= rule.min and not placeholder(value) then
				report(rule.kind, value, nil)
			end
		end
	end
	if string.find(text, "%-%-%-%-%-BEGIN [%u ]*PRIVATE KEY%-%-%-%-%-") then
		report("chiave privata", "BEGIN PRIVATE KEY", "-----BEGIN")
	end
end

local function scanFile(root: string, rel: string, out: { Finding })
	local ok, text = pcall(tern.fs.read, join(root, (string.gsub(rel, "/", "\\"))), MAX_FILE)
	if not ok or string.find(text :: string, "\0", 1, true) then
		return
	end
	local n = 0
	for line in string.gmatch((text :: string) .. "\n", "([^\n]*)\n") do
		n += 1
		scanLine(line, function(kind, value, prefix)
			table.insert(out, {
				file = rel,
				line = n,
				kind = kind,
				masked = mask(value, prefix),
				key = rel .. "|" .. kind .. "|" .. hash(value),
			})
		end)
	end
end

local function walk(root: string, rel: string, files: { string })
	if #files >= MAX_FILES then
		return
	end
	local ok, names = pcall(tern.fs.list, join(root, (string.gsub(rel, "/", "\\"))))
	if not ok then
		table.insert(files, rel)
		return
	end
	for _, name in names :: { string } do
		walk(root, rel .. "/" .. name, files)
	end
end

local M = {}

-- Every finding in .scratch/ and problems.json, without the ignored ones.
function M.scan(root: string, ignored: { [string]: boolean }): { Finding }
	local files: { string } = {}
	if tern.fs.exists(join(root, ".scratch")) then
		walk(root, ".scratch", files)
	end
	if tern.fs.exists(join(root, ".ai-workflows", "problems.json")) then
		table.insert(files, ".ai-workflows/problems.json")
	end
	local out: { Finding } = {}
	for _, rel in files do
		scanFile(root, rel, out)
	end
	local kept: { Finding } = {}
	for _, f in out do
		if not ignored[f.key] then
			table.insert(kept, f)
		end
	end
	return kept
end

local function ignorePath(root: string): string
	return join(root, ".ai-workflows", "secrets-ignore.json")
end

function M.loadIgnored(root: string): { [string]: boolean }
	local set: { [string]: boolean } = {}
	local path = ignorePath(root)
	if not tern.fs.exists(path) then
		return set
	end
	local ok, text = pcall(tern.fs.read, path, MAX_FILE)
	if not ok then
		return set
	end
	local ok2, data = pcall(tern.json.decode, text)
	if ok2 and type(data) == "table" and type(data.ignored) == "table" then
		for _, item in data.ignored do
			if type(item) == "table" and type(item.key) == "string" then
				set[item.key] = true
			end
		end
	end
	return set
end

-- Appends one finding to the ignore list (key, file and kind; never the value).
function M.ignore(root: string, f: Finding)
	local path = ignorePath(root)
	local items = {}
	if tern.fs.exists(path) then
		local ok, data = pcall(function()
			return tern.json.decode(tern.fs.read(path, MAX_FILE))
		end)
		if ok and type(data) == "table" and type(data.ignored) == "table" then
			items = data.ignored
		end
	end
	table.insert(items, { key = f.key, file = f.file, kind = f.kind, added = os.date("%Y-%m-%d %H:%M") })
	tern.fs.mkdir(join(root, ".ai-workflows"))
	tern.fs.write(path, tern.json.encode({ version = 1, ignored = tern.json.array(items) }, true) .. "\n")
end

return M
