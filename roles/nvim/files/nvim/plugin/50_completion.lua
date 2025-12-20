local add, later = MiniDeps.add, MiniDeps.later

later(function()
	add({
		source = "hrsh7th/nvim-cmp",
		depends = {
			"neovim/nvim-lspconfig",
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-buffer",
			"hrsh7th/cmp-path",
			"hrsh7th/cmp-cmdline",
			"echasnovski/mini.snippets",
			"abeldekat/cmp-mini-snippets",
			"zbirenbaum/copilot.lua",
			"zbirenbaum/copilot-cmp",
		},
	})

	require("copilot").setup({
		panel = {
			enabled = true,
			auto_refresh = true,
		},
		suggestion = {
			enabled = true,
			auto_trigger = true,
			-- 왜 안되지?
			-- keymap = {
			-- 	accept = "<M-y>",
			-- 	accept_word = false,
			-- 	accept_line = false,
			-- 	next = "<M-]>",
			-- 	prev = "<M-[>",
			-- 	dismiss = "<C-]>",
			-- },
		},
	})

	-- Keymaps for copilot suggestion
	local suggestion = require("copilot.suggestion")
	vim.keymap.set("i", "<M-y>", suggestion.accept)
	vim.keymap.set("i", "<M-]>", suggestion.next)
	vim.keymap.set("i", "<M-[>", suggestion.prev)

	--
	-- require("copilot_cmp").setup()
	--
	-- local has_words_before = function()
	-- 	if vim.api.nvim_buf_get_option(0, "buftype") == "prompt" then
	-- 		return false
	-- 	end
	-- 	local line, col = unpack(vim.api.nvim_win_get_cursor(0))
	-- 	return col ~= 0 and vim.api.nvim_buf_get_text(0, line - 1, 0, line - 1, col, {})[1]:match("^%s*$") == nil
	-- end

	-- Set up nvim-cmp.
	local cmp = require("cmp")

	cmp.setup({
		snippet = {
			-- REQUIRED - you must specify a snippet engine
			expand = function(args)
				-- vim.fn["vsnip#anonymous"](args.body) -- For `vsnip` users.
				-- require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
				-- require('snippy').expand_snippet(args.body) -- For `snippy` users.
				-- vim.fn["UltiSnips#Anon"](args.body) -- For `ultisnips` users.
				-- vim.snippet.expand(args.body) -- For native neovim snippets (Neovim v0.10+)

				-- For `mini.snippets` users:
				local insert = MiniSnippets.config.expand.insert or MiniSnippets.default_insert
				insert({ body = args.body }) -- Insert at cursor
				-- cmp.resubscribe({ "TextChangedI", "TextChangedP" })
				-- require("cmp.config").set_onetime({ sources = {} })
			end,
		},
		window = {
			completion = cmp.config.window.bordered(),
			documentation = cmp.config.window.bordered(),
		},
		mapping = cmp.mapping.preset.insert({
			-- ["<Tab>"] = vim.schedule_wrap(function(fallback)
			-- 	if cmp.visible() and has_words_before() then
			-- 		cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
			-- 	else
			-- 		fallback()
			-- 	end
			-- end),
			["<C-d>"] = cmp.mapping.scroll_docs(-4),
			["<C-f>"] = cmp.mapping.scroll_docs(4),
			["<C-Space>"] = cmp.mapping.complete(),
			["<C-e>"] = cmp.mapping.abort(),
			["<CR>"] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
		}),
		sources = cmp.config.sources({
			-- { name = "copilot" },
			{ name = "nvim_lsp" },
			{ name = "mini_snippets" },
			-- { name = "vsnip" }, -- For vsnip users.
			-- { name = 'luasnip' }, -- For luasnip users.
			-- { name = 'ultisnips' }, -- For ultisnips users.
			-- { name = 'snippy' }, -- For snippy users.
		}, {
			{ name = "buffer" },
		}),
	})

	-- To use git you need to install the plugin petertriho/cmp-git and uncomment lines below
	-- Set configuration for specific filetype.
	--[[ cmp.setup.filetype('gitcommit', {
    sources = cmp.config.sources({
      { name = 'git' },
    }, {
      { name = 'buffer' },
    })
 })
 require("cmp_git").setup() ]]
	--

	-- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
	cmp.setup.cmdline({ "/", "?" }, {
		mapping = cmp.mapping.preset.cmdline(),
		sources = {
			{ name = "buffer" },
		},
	})

	-- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
	cmp.setup.cmdline(":", {
		mapping = cmp.mapping.preset.cmdline(),
		sources = cmp.config.sources({
			{ name = "path" },
		}, {
			{ name = "cmdline" },
		}),
		matching = { disallow_symbol_nonprefix_matching = false },
	})

	cmp.event:on("menu_opened", function()
		vim.b.copilot_suggestion_hidden = true
	end)

	cmp.event:on("menu_closed", function()
		vim.b.copilot_suggestion_hidden = false
	end)

	-- Set up lspconfig.
	-- local capabilities = require("cmp_nvim_lsp").default_capabilities()
	-- Replace <YOUR_LSP_SERVER> with each lsp server you've enabled.
	-- require("lspconfig")["<YOUR_LSP_SERVER>"].setup({
	-- 	capabilities = capabilities,
	-- })
	--
end)
