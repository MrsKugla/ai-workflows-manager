--!strict
-- AI Workflows: window half.
-- Only this half sees agents (cx.agents); it publishes them in tern.kv so
-- the board block (host half) can list them. Also adds the palette command.

local AGENTS_KEY = "agents"

local function publish(cx: WindowCx)
	local out = {}
	for _, a in cx.agents:list() do
		local info = cx.session:pane(a.pane)
		table.insert(out, {
			pane = a.pane,
			title = if info then info.title else nil,
			command = a.command,
			cwd = a.cwd,
			state = a.state,
		})
	end
	tern.kv.set(AGENTS_KEY, tern.json.array(out))
end

tern.on("window_start", publish)
tern.on("agent_state", function(_ev, cx: WindowCx)
	publish(cx)
end)
tern.on("pane_closed", function(_ev, cx: WindowCx)
	publish(cx)
end)

tern.command({
	id = "open",
	title = "AI Workflows: apri",
	icon = "list-checks",
	run = function(cx)
		publish(cx)
		cx:new_block("ai-workflows-manager.board", nil, "beside")
	end,
})
